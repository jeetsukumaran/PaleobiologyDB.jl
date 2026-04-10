# PaleobiologyDB


[![CI](https://github.com/jeetsukumaran/PaleobiologyDB.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/jeetsukumaran/PaleobiologyDB.jl/actions/workflows/CI.yml)
[![Documentation (stable)](https://img.shields.io/badge/docs-stable-blue.svg)](https://jeetsukumaran.github.io/PaleobiologyDB.jl/stable)
[![Documentation (dev)](https://img.shields.io/badge/docs-dev-blue.svg)](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev)



A Julia interface to the [Paleobiology Database](https://paleobiodb.org/) (PBDB) Web API.
Every PBDB API endpoint has a corresponding Julia function; keyword arguments map directly to API parameters, and results are returned as `DataFrame`s.

## Installation

```
pkg> add PaleobiologyDB
```

## Quick start

```julia
using PaleobiologyDB

# Fossil occurrences
canids = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# Taxonomic data
canis = pbdb_taxon(name = "Canis", show = ["attr", "app", "size"])

# A specific collection
coll = pbdb_collection("col:1003", show = ["loc", "stratext"], extids = true)
```

## The Taxonomy data curation and exploration submodule

The `Taxonomy` submodule provides tools for validating, cleaning, and
exploring occurrence DataFrames against the PBDB taxonomic authority.

```julia
using PaleobiologyDB
using PaleobiologyDB.Taxonomy

df = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")

# ── Quality filters ────────────────────────────────────────────────────────

# Drop rows not resolved AND recognized at genus level
df_genus = drop_unqualified_taxa(df, "genus")

# Same for species (uses accepted_name column — PBDB stores the binomial there)
df_species = drop_unqualified_taxa(df, "species")

# Run the two checks independently
df_resolved   = drop_unresolved_taxa(df, :genus)    # resolution only
df_recognized = drop_unrecognized_taxa(df, :genus)  # name validity only

# Single-name lookup
istaxon("Pliosauridae")         # → true
istaxon("NO_FAMILY_SPECIFIED")  # → false

# ── Taxonomy augmentation ──────────────────────────────────────────────────

# Add taxonomy_genus, taxonomy_family, …, taxonomy_kingdom, taxonomy_clades columns
df2 = augment_taxonomy(df)
df2.taxonomy_clades[1]
# → "Animalia > Chordata > Mammalia > Carnivora > Canidae > Borophaginae > Epicyon"

# ── Taxonomy queries ───────────────────────────────────────────────────────

# Valid rank names
taxonomic_ranks()
# → ["subspecies", "species", "genus", …, "kingdom"]

# Search accepted PBDB taxon names
registered_taxa(r"^Canis\b")            # → ["Canis", "Canis aureus", "Canis lupus", …]
registered_taxa([r"^Canis\b", r"^Vulpes\b"])  # union of patterns

# Navigate the hierarchy
child_taxa("Carnivora", "family")       # → ["Ailuridae", "Canidae", "Felidae", …]
parent_taxa("Canis lupus", "family")    # → ["Canidae"]

# ── Row filtering ──────────────────────────────────────────────────────────

# 2-arg: boolean mask across all taxonomy columns (auto-augments if needed)
# Pattern-first syntax (functional style)using PaleobiologyDB.Taxonomy: taxon_occursin, contains_taxon
df2[taxon_occursin("Canis", df2), :]
df2[taxon_occursin(r"^Canis\b", df2), :]

# DataFrame-first syntax (method chaining style)
df2[contains_taxon(df2, "Canis"), :]
df2[contains_taxon(df2, r"^Canis\b"), :]

# Both syntaxes are equivalent — choose based on your style preference

# Vector inputs: combine=all (AND, default) / combine=any (OR)
df2[taxon_occursin(["Canis", "Mammalia"], df2), :]          # AND: both must appear
df2[contains_taxon(df2, ["Canis", "Mammalia"]), :]          # Same, DataFrame-first

df2[taxon_occursin(["Canis", "Vulpes"], df2; combine=any), :]  # OR: either matches
df2[contains_taxon(df2, ["Canis", "Vulpes"]; combine=any), :]  # Same, DataFrame-first

# 1-arg: ByRow predicate for use with subset
subset(df2, :taxonomy_genus    => taxon_occursin("Canis"))
subset(df2, :taxonomy_clades   => taxon_occursin(r"Borophaginae"))
subset(df2, :taxonomy_clades   => taxon_occursin([r"Canidae", r"lupus"]))  # AND on composite column
subset(df2, :taxonomy_genus    => taxon_occursin(["Canis", "Vulpes"]; combine=any))  # OR
```

### PhyloPic silhouette images

The `acquire_phylopic` and `augment_phylopic` functions map PBDB taxon names to
[PhyloPic](https://www.phylopic.org/) silhouette images via the PhyloPic
`/resolve/paleobiodb.org/txn` API endpoint.

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

# ── Single taxon ───────────────────────────────────────────────────────────

rec = acquire_phylopic("Tyrannosaurus")
rec.phylopic_thumbnail   # → "https://images.phylopic.org/images/.../thumbnail/…"
rec.phylopic_vector      # → SVG URL
rec.phylopic_license     # → "CC BY 4.0"
rec.phylopic_attribution # → "Matt Martyniuk"

# ── DataFrame: phylopic columns only (same row count) ─────────────────────

df   = pbdb_occurrences(base_name = "Ceratopsia", interval = "Cretaceous", show = "full")
pics = acquire_phylopic(df)                # 14 phylopic columns, nrow(df) rows
pics.phylopic_thumbnail                    # vector of URLs / missings

# ── Convenience: original df + phylopic columns ───────────────────────────

enriched = augment_phylopic(df)            # all original columns + 14 phylopic columns

# ── Multi-level enrichment with custom prefixes ────────────────────────────

# Different images at genus vs. species level
genus_pics = acquire_phylopic(df, :genus,         "genus_phylopic_")
sp_pics    = acquire_phylopic(df, :accepted_name, "sp_phylopic_")
full       = hcat(df, genus_pics, sp_pics)
full.genus_phylopic_thumbnail
full.sp_phylopic_thumbnail
```

Each unique taxon name triggers one set of API calls; repeated names reuse the
in-call result.  Unresolvable names return `missing` in every field rather than
raising an error.  Enable `set_autocaching!` to persist results to disk across
sessions — the cache is keyed per taxon name, so two DataFrames sharing the same
taxa produce zero redundant network requests:

```julia
PaleobiologyDB.set_autocaching!(true, acquire_phylopic)

pics1 = acquire_phylopic(df1)   # fetches Tyrannosaurus, Triceratops → cached
pics2 = acquire_phylopic(df2)   # same taxa → instant cache hits, no new requests

PaleobiologyDB.set_autocaching!(false, acquire_phylopic)
```

`augment_phylopic` also benefits automatically since it calls `acquire_phylopic`
internally.

```julia
# ── Downloading images to disk (only needs Downloads, a stdlib) ───────────

using Downloads

rec = acquire_phylopic("Tyrannosaurus")
Downloads.download(rec.phylopic_raster,    "tyrannosaurus.png")
Downloads.download(rec.phylopic_vector,    "tyrannosaurus.svg")
Downloads.download(rec.phylopic_thumbnail, "tyrannosaurus_thumb.png")

# To load an image as a Julia matrix for Makie / Pluto / Jupyter, use a
# separate image-loading package (not a PaleobiologyDB.jl dependency):
#   pkg> add FileIO PNGFiles    (or ImageMagick, Images, etc.)
# then:
#   using FileIO
#   img = load(Downloads.download(rec.phylopic_thumbnail))
```

## PhyloPicMakie — Makie plot integration

`PaleobiologyDB.PhyloPicMakie` is an optional extension that adds PhyloPic
silhouette overlays to existing Makie axes.  It activates automatically when a
Makie backend (e.g. `CairoMakie`) and `FileIO` are loaded.

```
pkg> add CairoMakie FileIO PNGFiles
```

```julia
using PaleobiologyDB
using CairoMakie, FileIO
using PaleobiologyDB.PhyloPicMakie

taxa      = ["Tyrannosaurus", "Triceratops", "Ankylosaurus",
             "Pachycephalosaurus", "Edmontosaurus"]
first_app = [68.0, 68.0, 70.0, 74.0, 76.0]
last_app  = [66.0, 66.0, 66.0, 66.0, 66.0]

fig = Figure(size = (800, 420))
ax  = Axis(
    fig[1, 1];
    xlabel = "Age (Ma)", xreversed = true,
    yticks = (1:length(taxa), taxa), yticklabelsize = 13,
)

for (i, (fa, la)) in enumerate(zip(first_app, last_app))
    lines!(ax, [fa, la], [i, i]; linewidth = 6, color = :gray30)
end

# Anchor PhyloPic glyphs at each taxon's first appearance
augment_phylopic_ranges!(
    ax, first_app, last_app, collect(1.0:length(taxa));
    taxon      = taxa,
    at         = :start,
    glyph_size = 0.38,
    placement  = :center,
)

xlims!(ax, 78, 64)
display(fig)
```

A table-oriented variant accepts a `DataFrame` and column-selector keywords
(`xstart`, `xstop`, `y`, `taxon`) — see the
[PhyloPicMakie guide](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/phylopic_makie/)
for full documentation.

## Key features

- **DataFrame results** — all queries return a `DataFrame` for immediate use with the Julia data ecosystem.

- **Caching** — persistent file cache (`@filecache`), in-memory session cache (`@memcache`), and transparent autocaching (`set_autocaching!`) keep repeated or expensive queries off the network.  All 29 PBDB API functions and the PhyloPic enrichment functions (`acquire_phylopic`, `augment_phylopic`) are autocache-enabled.  See the [Caching guide](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/caching/).

- **Rich field names and extra blocks** — `vocab = "pbdb"` (default) for full column names, `vocab = "com"` for compact codes; `show = ["coords", "classext", "stratext"]` for additional data blocks.

- **Count without downloading** — `pbdb_count(:occurrences; base_name = "Canidae")` returns the record count without fetching data.

- **PhyloPic silhouette images** — `acquire_phylopic` and `augment_phylopic` resolve PBDB taxon names to [PhyloPic](https://www.phylopic.org/) silhouette image URLs, licences, and attribution metadata.  The `fieldname_prefix` argument supports multi-level enrichment (genus-level images alongside species-level images) in a single DataFrame.

- **Built-in API help** — `pbdb_parameters("occurrences")` lists all selection, geographic, temporal, taxonomic, and output parameters directly in the REPL. See the [Interactive Help docs](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/apihelp/).

## Function reference

* Occurrences: `pbdb_occurrence`, `pbdb_occurrences`, `pbdb_ref_occurrences`
* Collections: `pbdb_collection`, `pbdb_collections`, `pbdb_collections_geo`, `pbdb_ref_collections`
* Taxa: `pbdb_taxon`, `pbdb_taxa`, `pbdb_taxa_auto`, `pbdb_ref_taxa`, `pbdb_opinions_taxa`
* Intervals/scales: `pbdb_interval`, `pbdb_intervals`, `pbdb_scale`, `pbdb_scales`
* Strata: `pbdb_strata`, `pbdb_strata_auto`
* References: `pbdb_reference`, `pbdb_references`
* Specimens: `pbdb_specimen`, `pbdb_specimens`, `pbdb_ref_specimens`, `pbdb_measurements`
* Opinions: `pbdb_opinion`, `pbdb_opinions`
* Counts: `pbdb_count`
* Taxonomy (submodule): `drop_unqualified_taxa`, `drop_unresolved_taxa`, `drop_unrecognized_taxa`, `augment_taxonomy`, `child_taxa`, `parent_taxa`, `registered_taxa`, `taxon_occursin`, `contains_taxon`
* PhyloPic (submodule): `acquire_phylopic`, `augment_phylopic`
* PhyloPicMakie (extension): `augment_phylopic!`, `augment_phylopic`, `augment_phylopic_ranges!`, `augment_phylopic_ranges`

## Documentation

Full documentation: <https://jeetsukumaran.github.io/PaleobiologyDB.jl/>

- [Quick Start](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/quickstart/) — examples for all endpoint types, advanced query options
- [Caching](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/caching/) — file, memory, and auto-caching
- [PhyloPicMakie](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/phylopic_makie/) — PhyloPic silhouette overlays on Makie plots
- [API Reference](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/occurrences/) — per-function docstrings
- [Interactive Help](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/apihelp/) — REPL-based parameter and field discovery
- [Contributing](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/contributing/) — testing, development, and external resources

## Testing

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

Enable live API tests:

```bash
PBDB_LIVE=1 julia --project -e 'using Pkg; Pkg.test()'
```

## Contributing

Contributions are welcome. Please fork the repository, add tests for new functionality, and submit a pull request.

## Citation

[![](https://zenodo.org/badge/1046851014.svg)](https://doi.org/10.5281/zenodo.16994488)

If you use PaleobiologyDB.jl in your research, please cite both this package and the Paleobiology Database:

```bibtex
@misc{PaleobiologyDB.jl,
  author = {Jeet Sukumaran},
  title = {PaleobiologyDB.jl: A Julia interface to the Paleobiology Database},
  url = {https://github.com/jeetsukumaran/PaleobiologyDB.jl},
  year = {2025},
  doi = {10.5281/zenodo.17043157}
}

@article{Peters2016,
  author = {Shanan E. Peters and Michael McClennen},
  title = {The Paleobiology Database application programming interface},
  journal = {Paleobiology},
  volume = {42},
  number = {1},
  pages = {1--7},
  year = {2016},
  doi = {10.1017/pab.2015.39}
}
```

## Acknowledgments

- The [Paleobiology Database](https://paleobiodb.org/) for providing the data and API.
- API endpoint naming convention based on the [paleobioDB](https://github.com/ropensci/paleobioDB) R package.
- Julia community packages: JSON3.jl, HTTP.jl, DataFrames.jl, CSV.jl, URIs.jl.
- The [Julia Community](https://julialang.org/community/).
