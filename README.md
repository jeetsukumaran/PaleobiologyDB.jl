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

# Add taxonomy_subgenus, taxonomy_genus, taxonomy_family, …, taxonomy_kingdom, taxonomy_clades columns
df2 = augment_taxonomy(df)
df2.taxonomy_clades[1]
# → "Animalia > Chordata > Mammalia > Carnivora > Canidae > Borophaginae > Epicyon"

# ── Taxonomy queries ───────────────────────────────────────────────────────

# Valid rank names
taxonomic_ranks()
# → ["subspecies", "species", "subgenus", "genus", …, "kingdom"]

# Search accepted PBDB taxon names
registered_taxa(r"^Canis\b")            # → ["Canis", "Canis aureus", "Canis lupus", …]
registered_taxa([r"^Canis\b", r"^Vulpes\b"])  # union of patterns

# Navigate the hierarchy
child_taxa("Carnivora", "family")       # → ["Ailuridae", "Canidae", "Felidae", …]
parent_taxa("Canis lupus", "family")    # → ["Canidae"]

# ── Taxonomy tree graphs ───────────────────────────────────────────────────

import Graphs

# Build an explicit subtree of Carnivora, with families as leaves
tree = taxon_subtree("Carnivora"; leaf_rank = "family")
root_taxon(tree).name    # → "Carnivora"
root_taxon(tree).rank    # → "order"

# The leaf nodes are exactly the family-level taxa
leaf_taxa(tree) .|> (n -> n.name)
# → ["Ailuridae", "Amphicyonidae", "Canidae", "Felidae", …]

# Pick all genera from a full genus-level Canidae subtree
t2 = taxon_subtree("Canidae"; leaf_rank = "genus")
taxa_at_rank(t2, "genus") .|> (n -> n.name)
# → ["Borophagus", "Canis", "Urocyon", "Vulpes", …]

# TaxonTree wraps a Graphs.jl SimpleDiGraph — full graph algorithm suite available
Graphs.nv(tree.graph)    # → number of taxa in the subtree
Graphs.ne(tree.graph)    # → number of parent → child edges

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

Three functions map PBDB taxon names to [PhyloPic](https://www.phylopic.org/)
silhouette images.

| Function | Returns | Use when |
|----------|---------|---------|
| `acquire_phylopic` | `NamedTuple` or `DataFrame` | One representative image per taxon |
| `augment_phylopic` | `DataFrame` | Enrich an occurrences DataFrame in one call |
| `phylopic_images_dataframe` | `DataFrame` | All available images for a taxon (or clade) |

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy

# ── Single taxon — one representative image ────────────────────────────────

rec = acquire_phylopic("Tyrannosaurus")
rec.phylopic_thumbnail   # → "https://images.phylopic.org/images/.../thumbnail/…"
rec.phylopic_vector      # → SVG URL
rec.phylopic_license     # → "CC BY 4.0"
rec.phylopic_attribution # → "Matt Martyniuk"

# ── DataFrame: one phylopic row per occurrence row ─────────────────────────

df   = pbdb_occurrences(base_name = "Ceratopsia", interval = "Cretaceous", show = "full")
pics = acquire_phylopic(df)                # 14 phylopic columns, nrow(df) rows
pics.phylopic_thumbnail                    # vector of URLs / missings

# ── Convenience: original df + phylopic columns ───────────────────────────

enriched = augment_phylopic(df)            # all original columns + 14 phylopic columns

# ── Multi-level enrichment with custom prefixes ────────────────────────────

genus_pics = acquire_phylopic(df, :genus,         "genus_phylopic_")
sp_pics    = acquire_phylopic(df, :accepted_name, "sp_phylopic_")
full       = hcat(df, genus_pics, sp_pics)
full.genus_phylopic_thumbnail
full.sp_phylopic_thumbnail

# ── All available images for a taxon ──────────────────────────────────────

# phylopic_images_dataframe returns every image for the taxon's clade (one row per image)
imgs = phylopic_images_dataframe("Carnivora")
nrow(imgs)                    # → hundreds (all images within Carnivora)
imgs.phylopic_uuid[1:5]       # image UUIDs
imgs.phylopic_raster[1:5]     # raster PNG URLs
imgs.phylopic_thumbnail[1:5]  # thumbnail PNG URLs

# Restrict to images tagged to exactly the Carnivora node (far fewer)
imgs_node = phylopic_images_dataframe("Carnivora"; filter = :node)

# Page limit — first ~30 images only
imgs_quick = phylopic_images_dataframe("Carnivora"; max_pages = 1)
```

Each unique taxon name triggers one set of API calls; repeated names reuse the
in-call result.  Unresolvable names return `missing` in every field (`acquire_phylopic`)
or an empty DataFrame (`phylopic_images_dataframe`) rather than raising an error.
Enable `set_autocaching!` to persist results to disk across sessions:

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

## TaxonTreeMakie — Makie tree visualization

`PaleobiologyDB.TaxonTreeMakie` is an optional extension that renders
[`TaxonTree`](@ref) objects as interactive dendrograms in Makie figures.
It activates automatically when any Makie backend is loaded — no extra
packages beyond a backend are required.

```
pkg> add CairoMakie
```

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

# Build a taxonomic subtree (Carnivora down to family level)
tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Standalone figure — returns (Figure, Axis, TaxonTreePlot)
fig, ax, p = taxontreeplot(tree; showtips = true)
save("carnivora_families.png", fig)

# Color branches and nodes by taxonomic rank
fig2, ax2, p2 = taxontreeplot(tree; color_by_rank = true, showtips = true)

# Ladderized layout (denser subtrees at bottom)
fig3, ax3, p3 = taxontreeplot(tree; ladderize = true, showtips = true)

# Add to an existing Makie axis (compose with other plots)
fig4 = Figure(size = (1000, 700))
ax4  = Axis(fig4[1, 1]; title = "Canidae genera")
tree4 = taxon_subtree("Canidae"; leaf_rank = "genus")
taxontreeplot!(ax4, tree4; showtips = true, ladderize = true)
set_rank_axis_ticks!(ax4, tree4)
display(fig4)
```

Key attributes for `taxontreeplot` / `taxontreeplot!`:

| Attribute | Default | Description |
|---|---|---|
| `showtips` | `true` | Show leaf taxon-name labels |
| `tip_fontsize` | `9` | Leaf label font size (pts) |
| `tip_xoffset` | `0.2` | Rightward offset for leaf labels in data units |
| `color_by_rank` | `false` | Color branches and nodes by taxonomic rank |
| `rank_palette` | `nothing` | `Dict{String,Any}` mapping rank → color; `nothing` uses built-in cycle |
| `ladderize` | `false` | Sort children by subtree size (denser subtrees at bottom) |
| `showinternal` | `false` | Show internal node labels |
| `branch_color` | `:black` | Branch line color (when `color_by_rank = false`) |
| `branch_linewidth` | `1.5` | Branch line width (pts) |
| `node_size` | `5` | Node marker size (pts) |
| `show_nodes` | `true` | Draw a marker at every vertex |
| `show_unifurcation_nodes` | `true` | When `false`, suppress markers at single-child nodes |
| `show_phylopic` | `false` | Draw a PhyloPic silhouette at each leaf tip (requires `FileIO`) |
| `phylopic_glyph_size` | `0.4` | Half-height of each silhouette glyph in data units |
| `phylopic_align` | `false` | `true` → single right-hand column for all glyphs |
| `phylopic_xoffset` | `0.3` | Extra rightward gap beyond the tip-label start (data units) |
| `phylopic_on_missing` | `:skip` | `:skip` (omit) / `:placeholder` (grey box) / `:error` |
| `phylopic_aspect` | `:preserve` | `:preserve` keeps original aspect ratio; `:stretch` renders square |
| `phylopic_image_rendering` | `:thumbnail` | Image URL type: `:thumbnail` / `:raster` / `:og_image` / `:vector` / `:source_file` |

### PhyloPic silhouettes on a tree

PhyloPic silhouettes at leaf tips require `FileIO` and a PNG plugin in addition
to a Makie backend:

```
pkg> add FileIO PNGFiles
```

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie, FileIO
using PaleobiologyDB.TaxonTreeMakie

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Default: one thumbnail per leaf, placed immediately right of each label
fig, ax, p = taxontreeplot(tree;
    showtips      = true,
    show_phylopic = true,
)
save("carnivora_phylopic.png", fig)

# Aligned column: all silhouettes share one right-hand x position;
# use :placeholder so a grey box appears when no image exists for a taxon
fig2, ax2, p2 = taxontreeplot(tree;
    showtips             = true,
    show_phylopic        = true,
    phylopic_align       = true,
    phylopic_glyph_size  = 0.35,
    phylopic_xoffset     = 0.5,
    phylopic_on_missing  = :placeholder,
)

# Full-resolution PNG instead of thumbnail
fig3, ax3, p3 = taxontreeplot(tree;
    showtips                 = true,
    show_phylopic            = true,
    phylopic_image_rendering = :raster,
)
```

See the [TaxonTreeMakie guide](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/taxontree_makie/) for the full attribute reference and worked examples.

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


### PhyloPic thumbnail gallery

#### Exploring a single taxon

Pass a single taxon name to browse all PhyloPic images available for that taxon
and its descendants.  Each image in the clade gets its own cell:

```julia
using PaleobiologyDB
using CairoMakie, FileIO
using PaleobiologyDB.PhyloPicMakie

# All clade images for Felis (one cell per image, auto-sized figure)
fig = phylopic_thumbnail_grid("Felis")

# Limit to the first page (≈ 30 images) to keep it fast
fig2 = phylopic_thumbnail_grid("Felis";
    image_max_pages = 1,
    ncols           = 4,
    title           = "Felis — first page of clade images",
)

# Primary image only — the single designated representative silhouette
fig3 = phylopic_thumbnail_grid("Felis";
    image_filter = :primary,
    title        = "Felis — primary image",
)

# Images tagged to this node exactly (not descendants)
fig4 = phylopic_thumbnail_grid("Felis";
    image_filter = :node,
    title        = "Felis — node-level images only",
)
```

#### Comparing multiple taxa

Pass a vector of names — each taxon occupies its own block of cells:

```julia
# Side-by-side comparison of two genera
fig = phylopic_thumbnail_grid(["Felis", "Canis"];
    image_filter = :clade,
    image_layout = :blocks,     # :blocks (default) | :flat | :rows
    ncols        = 4,
)

# Primary image per taxon — compact one-image-per-name layout
fig2 = phylopic_thumbnail_grid(["Felis", "Canis", "Panthera", "Lynx"];
    image_filter   = :primary,
    ncols          = 2,
    image_label    = :BASICFIELDS,   # shows index + node name + taxon name
    label_fontsize = 11,
)

# All images laid out flat (no per-taxon grouping) with license labels
fig3 = phylopic_thumbnail_grid(["Felis", "Canis"];
    image_filter = :clade,
    image_layout = :flat,
    image_label  = [:node_name, :license],   # custom field selection
    labeljoin    = "\n",
    ncols        = 5,
)
```

#### Exploring a clade with `child_taxa`

`child_taxa` returns a `Vector{String}` and feeds directly into
`phylopic_thumbnail_grid`:

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie, FileIO
using PaleobiologyDB.PhyloPicMakie

# Primary image for every family in Pterosauria
pterosaur_families = child_taxa("Pterosauria", "family")
fig = phylopic_thumbnail_grid(pterosaur_families;
    image_filter = :primary,
    ncols        = 4,
    title        = "Pterosauria families",
)

# All clade images for each family — :blocks layout keeps each family together
fig2 = phylopic_thumbnail_grid(pterosaur_families;
    image_filter    = :clade,
    image_layout    = :blocks,
    image_max_pages = 1,
    ncols           = 5,
    title           = "Pterosauria families — clade images",
)

# Same, with full metadata labels
fig3 = phylopic_thumbnail_grid(pterosaur_families;
    image_filter = :primary,
    image_label  = :ALLFIELDS,
    ncols        = 3,
    label_fontsize = 8,
)

# Canidae genera — raster (high-res) rendering
canid_genera = child_taxa("Canidae", "genus")
fig4 = phylopic_thumbnail_grid(canid_genera;
    image_filter    = :primary,
    image_rendering = :raster,    # :thumbnail (default) | :raster | :og_image | :vector | :source_file
    ncols           = 4,
    title           = "Canidae genera",
)
```

> **Note on SVG renderings:** `image_rendering = :vector` and `:source_file` may
> return SVG URLs.  `FileIO.load` requires an SVG-capable plugin
> (e.g. [Rsvg.jl](https://github.com/lobingera/Rsvg.jl)) to decode them; without
> one the download step will fail with a `FileIO` error.

#### Layout and display options

```julia
taxa = ["Tyrannosaurus", "Triceratops", "Ankylosaurus",
        "Pachycephalosaurus", "Edmontosaurus", "Maiasaura",
        "Spinosaurus", "Brachiosaurus", "Stegosaurus"]

# Custom cell proportions and title
fig = phylopic_thumbnail_grid(taxa;
    image_filter   = :primary,
    ncols          = 3,
    cell_width     = 1.2,
    cell_height    = 1.8,
    glyph_fraction = 0.65,
    label_fontsize = 12,
    title          = "Late Cretaceous taxa",
)
```

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
* Taxonomy (submodule): `drop_unqualified_taxa`, `drop_unresolved_taxa`, `drop_unrecognized_taxa`, `augment_taxonomy`, `child_taxa`, `parent_taxa`, `registered_taxa`, `taxon_occursin`, `contains_taxon`, `taxon_subtree`, `root_taxon`, `leaf_taxa`, `taxa_at_rank`
* PhyloPic (submodule): `acquire_phylopic`, `augment_phylopic`, `phylopic_images_dataframe`
* PhyloPicMakie (extension): `augment_phylopic!`, `augment_phylopic`, `augment_phylopic_ranges!`, `augment_phylopic_ranges`, `phylopic_thumbnail_grid!`, `phylopic_thumbnail_grid`
* TaxonTreeMakie (extension): `taxontreeplot`, `taxontreeplot!`, `TaxonTreePlot`, `set_rank_axis_ticks!`

## Documentation

Full documentation: <https://jeetsukumaran.github.io/PaleobiologyDB.jl/>

- [Quick Start](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/quickstart/) — examples for all endpoint types, advanced query options
- [Caching](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/caching/) — file, memory, and auto-caching
- [TaxonTreeMakie](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/taxontree_makie/) — dendrogram visualization of taxonomic trees
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
