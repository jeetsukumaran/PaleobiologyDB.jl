# PaleobiologyDB


[![CI](https://github.com/jeetsukumaran/PaleobiologyDB.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/jeetsukumaran/PaleobiologyDB.jl/actions/workflows/CI.yml)
[![Documentation (stable)](https://img.shields.io/badge/docs-stable-blue.svg)](https://jeetsukumaran.github.io/PaleobiologyDB.jl/stable)
[![Documentation (dev)](https://img.shields.io/badge/docs-dev-blue.svg)](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev)


PaleobiologyDB.jl is a Julia interface to the [Paleobiology Database](https://paleobiodb.org/) (PBDB) Web API: every endpoint has a corresponding function, keyword arguments map directly to API parameters, and all results are returned as `DataFrame`s ready for the Julia data ecosystem.
Beyond the API wrapper, the package includes a `Taxonomy` submodule for both data curation (resolving synonyms, filtering by quality) and biodiversity exploration and instruction (navigating hierarchies, building subtrees, classroom-ready querying); integrated caching designed for bandwidth-limited settings such as workshops and shared classroom networks; a PhyloPic integration layer for enriching DataFrames and plots with silhouette images; and Makie-based extensions for interactive dendrogram visualisation and range-chart overlays.

## Installation

```julia
using Pkg
Pkg.add("PaleobiologyDB")
```

Development version:

```julia
using Pkg
Pkg.add(url = "https://github.com/jeetsukumaran/PaleobiologyDB.jl")
```

## Quick Start

```julia
using PaleobiologyDB: pbdb_occurrences

# Fossil occurrences — returns a DataFrame
canids = pbdb_occurrences(base_name = "Canidae", interval = "Miocene", show = "full")
```

```julia
using PaleobiologyDB: pbdb_taxon

# Taxonomic record for a name
canis = pbdb_taxon(name = "Canis", show = ["attr", "app", "size"])
```

```julia
using PaleobiologyDB: pbdb_collection

# A single collection with location and stratigraphic detail
coll = pbdb_collection("col:1003", show = ["loc", "stratext"], extids = true)
```

## Taxonomy module

`PaleobiologyDB.Taxonomy` serves two audiences.
For researchers, it provides data quality and curation tools: filtering occurrences to well-resolved and authority-validated names, augmenting DataFrames with full taxonomic lineages, and querying the PBDB taxonomic hierarchy.
For educators and students, it offers a programmatic environment for biodiversity exploration and instruction: navigating taxonomic trees, building subtrees from any node, and filtering datasets by clade membership.

```julia
# Quality filtering — keep only genus-resolved, authority-recognised occurrences
using PaleobiologyDB: pbdb_occurrences
using PaleobiologyDB.Taxonomy: drop_unresolved_taxa, drop_unrecognized_taxa

df = pbdb_occurrences(base_name = "Carnivora", interval = "Miocene", show = "full")
df = drop_unresolved_taxa(df, :genus)      # drop rows not resolved to genus level
df = drop_unrecognized_taxa(df, :genus)    # drop rows with names not in PBDB authority
```

```julia
# Augment occurrences with full lineage columns, then filter by clade
using PaleobiologyDB: pbdb_occurrences
using PaleobiologyDB.Taxonomy: augment_taxonomy, contains_taxon

df  = pbdb_occurrences(base_name = "Canidae", interval = "Neogene", show = "full")
df2 = augment_taxonomy(df)   # adds taxonomy_genus, taxonomy_family, …, taxonomy_clades

# DataFrame-first row filtering: keep only Canis occurrences
df2[contains_taxon(df2, "Canis"), :]

# taxon_occursin provides a parallel pattern-first syntax for the same operation
```

```julia
# Build and navigate a taxonomic subtree
using PaleobiologyDB.Taxonomy: taxon_subtree, root_taxon, leaf_taxa

tree = taxon_subtree("Carnivora"; leaf_rank = "family")
root_taxon(tree).name    # → "Carnivora"
root_taxon(tree).rank    # → "order"

# Names of all family-level leaves
leaf_taxa(tree) .|> (n -> n.name)
# → ["Ailuridae", "Amphicyonidae", "Canidae", "Felidae", …]

# The underlying Graphs.jl SimpleDiGraph is accessible for further algorithms
```

## PhyloPic integration

Three functions map PBDB taxon names to [PhyloPic](https://www.phylopic.org/) silhouette images:

| Function | Returns | Use when |
|---|---|---|
| `acquire_phylopic` | `NamedTuple` or `DataFrame` | One representative image record per taxon |
| `augment_phylopic` | `DataFrame` | Enrich an occurrences DataFrame in one call |
| `phylopic_images_dataframe` | `DataFrame` | All available images for a taxon or clade |

```julia
# Enrich an occurrences DataFrame with PhyloPic image columns
using PaleobiologyDB: pbdb_occurrences
using PaleobiologyDB.PhyloPicPBDB: acquire_phylopic, augment_phylopic

df      = pbdb_occurrences(base_name = "Ceratopsia", interval = "Cretaceous", show = "full")
pics    = acquire_phylopic(df)              # DataFrame: one row per occurrence row
pics.phylopic_thumbnail                    # → Vector of thumbnail URLs / missings
pics.phylopic_license                      # → Vector of licence strings

enriched = augment_phylopic(df)            # original columns + 14 phylopic_ columns
```

```julia
# Browse all available images for a taxon or clade
using PaleobiologyDB.PhyloPicPBDB: phylopic_images_dataframe

imgs = phylopic_images_dataframe("Carnivora")
nrow(imgs)                    # → hundreds (all images within Carnivora clade)
imgs.phylopic_thumbnail[1:5]  # thumbnail URLs
imgs.phylopic_raster[1:5]     # full-resolution PNG URLs

# Restrict to images tagged to exactly the Carnivora node (far fewer)
imgs_node = phylopic_images_dataframe("Carnivora"; filter = :node)
```



## PhyloPicPBDB — Taxon visualization

```julia
# Anchor a PhyloPic glyph at each taxon's first appearance on a range chart
using CairoMakie: Figure, Axis, lines!, xlims!, display
using PaleobiologyDB.PhyloPicPBDB: augment_phylopic_ranges!

taxa      = ["Tyrannosaurus", "Triceratops", "Ankylosaurus",
             "Pachycephalosaurus", "Edmontosaurus"]
first_app = [68.0, 68.0, 70.0, 74.0, 76.0]
last_app  = [66.0, 66.0, 66.0, 66.0, 66.0]

fig = Figure(size = (800, 420))
ax  = Axis(fig[1, 1]; xlabel = "Age (Ma)", xreversed = true,
           yticks = (1:length(taxa), taxa))

for (i, (fa, la)) in enumerate(zip(first_app, last_app))
    lines!(ax, [fa, la], [i, i]; linewidth = 6, color = :gray30)
end

augment_phylopic_ranges!(
    ax, first_app, last_app, collect(1.0:length(taxa));
    taxon      = taxa,
    at         = :start,
    glyph_size = 0.38,
)
xlims!(ax, 78, 64)
display(fig)
```

```julia
# PhyloPic thumbnail gallery
using PaleobiologyDB.PhyloPicPBDB: phylopic_thumbnail_grid
using CairoMakie: display

# Single taxon — all clade images
fig = phylopic_thumbnail_grid("Felis"; image_filter = :clade, ncols = 4)
display(fig)

# Multiple taxa — primary image per taxon
fig2 = phylopic_thumbnail_grid(
    ["Felis", "Canis", "Panthera", "Lynx"];
    image_filter = :primary,
    ncols        = 2,
)
display(fig2)
```

See the [PhyloPicPBDB guide](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/phylopic_makie/) for the full API and layout options.


## TaxonomyTreeMakie — dendrogram visualisation

```julia
using PaleobiologyDB.Taxonomy: taxon_subtree
using PaleobiologyDB.TaxonomyTreeMakie: taxonomytreeplot, taxonomytreeplot!, set_rank_axis_ticks!
using CairoMakie: Figure, Axis, save, display

# Build a subtree and render it — branches and nodes coloured by taxonomic rank
tree = taxon_subtree("Carnivora"; leaf_rank = "family")
fig, ax, p = taxonomytreeplot(tree; showtips = true, color_by_rank = true, ladderize = true)
save("carnivora_families.png", fig)

# Compose into an existing axis
fig2 = Figure(size = (1000, 700))
ax2  = Axis(fig2[1, 1]; title = "Canidae genera")
tree2 = taxon_subtree("Canidae"; leaf_rank = "genus")
taxonomytreeplot!(ax2, tree2; showtips = true, ladderize = true)
set_rank_axis_ticks!(ax2, tree2)
display(fig2)
```

```julia
using PaleobiologyDB.Taxonomy: taxon_subtree
using PaleobiologyDB.TaxonomyTreeMakie: taxonomytreeplot, augment_tip_phylopic!
using CairoMakie: Figure, Axis, save
using FileIO: load

tree = taxon_subtree("Carnivora"; leaf_rank = "family")
fig, ax, p = taxonomytreeplot(tree; showtips = true, color_by_rank = true, ladderize = true)

# Overlay PhyloPic silhouettes at each leaf tip
augment_tip_phylopic!(ax, p; xoffset = 0.5)
save("carnivora_phylopic.png", fig)
```

See the [TaxonomyTreeMakie guide](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/taxonomytree_makie/) for the full attribute reference and worked examples.

## Caching

Teaching workshops and classroom sessions often place dozens of students on a shared network, all querying the same PBDB endpoints simultaneously.
Research workflows repeatedly re-run the same queries during analysis.
PaleobiologyDB.jl integrates [DataCaches.jl](https://github.com/jeetsukumaran/DataCaches.jl) to address both scenarios: pre-fetch all data once, then serve every subsequent identical call from a local cache with no network round-trip.

```julia
# Enable transparent autocaching for all API functions
using PaleobiologyDB: pbdb_occurrences
using DataCaches: set_autocaching!

set_autocaching!(true)

canids = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # fetched + cached
canids = pbdb_occurrences(base_name = "Canidae", interval = "Miocene")  # instant cache hit

set_autocaching!(false)   # disable when no longer needed

# Cache a specific function only
set_autocaching!(true, pbdb_occurrences)
```

```julia
# Explicit per-call caching
using PaleobiologyDB: pbdb_occurrences, pbdb_taxa
using DataCaches: @memcache, @filecache

# In-session memoisation (lost on Julia exit)
canids = @memcache pbdb_occurrences(base_name = "Canidae", interval = "Miocene")
taxa   = @memcache pbdb_taxa(name = "Dinosauria")

# Persistent file cache (survives across sessions)
canids = @filecache pbdb_occurrences(base_name = "Canidae", interval = "Miocene")
```

See the [Caching guide](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/caching/) for file cache configuration, per-function control, and classroom pre-fetch patterns.

## Function reference

### PBDB API

| Category | Functions |
|---|---|
| Occurrences | `pbdb_occurrence`, `pbdb_occurrences`, `pbdb_ref_occurrences` |
| Collections | `pbdb_collection`, `pbdb_collections`, `pbdb_collections_geo`, `pbdb_ref_collections` |
| Taxa | `pbdb_taxon`, `pbdb_taxa`, `pbdb_taxa_auto`, `pbdb_ref_taxa`, `pbdb_opinions_taxa` |
| Intervals / Scales | `pbdb_interval`, `pbdb_intervals`, `pbdb_scale`, `pbdb_scales` |
| Strata | `pbdb_strata`, `pbdb_strata_auto` |
| References | `pbdb_reference`, `pbdb_references` |
| Specimens | `pbdb_specimen`, `pbdb_specimens`, `pbdb_ref_specimens`, `pbdb_measurements` |
| Opinions | `pbdb_opinion`, `pbdb_opinions` |
| Counts | `pbdb_count` |

All functions accept keyword arguments that map directly to PBDB API parameters.
Use `pbdb_count` to count records without downloading them.

### Taxonomy submodule (`PaleobiologyDB.Taxonomy`)

| Category | Functions |
|---|---|
| Quality filtering | `drop_unresolved_taxa`, `drop_unresolved_taxa!`, `drop_unrecognized_taxa`, `drop_unrecognized_taxa!` |
| Augmentation | `augment_taxonomy` |
| Row filtering | `taxon_occursin`, `contains_taxon` |
| Hierarchy queries | `child_taxa`, `parent_taxa`, `registered_taxa`, `taxonomic_ranks` |
| Name validation | `istaxon`, `audit_taxonomy` |
| Tree graphs | `taxon_subtree`, `root_taxon`, `leaf_taxa`, `taxa_at_rank` |
| Types | `TaxonNode`, `TaxonomyTree` |

### PhyloPic (`PaleobiologyDB.PhyloPicPBDB`)

| Category | Functions |
|---|---|
| Data acquisition | `acquire_phylopic`, `augment_phylopic`, `phylopic_images_dataframe`, `phylopic_images`, `phylopic_node` |
| Makie overlays | `augment_phylopic!`, `augment_phylopic_ranges!`, `augment_phylopic_ranges` |
| Gallery | `phylopic_thumbnail_grid`, `phylopic_thumbnail_grid!` |

### TaxonomyTreeMakie extension (`PaleobiologyDB.TaxonomyTreeMakie`)

| Symbol | Description |
|---|---|
| `taxonomytreeplot` | Standalone figure; returns `(Figure, Axis, TaxonomyTreePlot)` |
| `taxonomytreeplot!` | Add dendrogram to an existing axis |
| `set_rank_axis_ticks!` | Label x-axis with rank names at their depth positions |
| `tip_positions` | Extract leaf-tip coordinates from a tree or plot |
| `augment_tip_phylopic!` | Add PhyloPic silhouettes at each leaf tip |
| `TaxonomyTreePlot` | Plot type (for dispatch and attribute access) |

## Documentation

- [Quick Start](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/quickstart/) — examples for all endpoint types, advanced query options
- [Caching](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/caching/) — file, memory, and autocaching; classroom pre-fetch patterns
- [TaxonomyTreeMakie](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/taxonomytree_makie/) — dendrogram visualisation guide and attribute reference
- [PhyloPicPBDB](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/phylopic_makie/) — PhyloPic overlay and gallery guide
- [Contributing](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/guide/contributing/) — testing, development, and external resources

**API reference**

- [Occurrences](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/occurrences/)
- [Collections](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/collections/)
- [Taxa](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/taxa/)
- [Specimens](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/specimens/)
- [Other endpoints](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/other/) — intervals, scales, strata, references, opinions
- [Taxonomy — queries and filtering](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/taxonomy_queries/)
- [Taxonomy — row filtering](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/taxonomy_filtering/)
- [Taxonomy — tree graphs](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/taxonomy_graphs/)
- [Taxonomy — search](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/taxonomy_search/)
- [PhyloPic acquisition](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/phylopic_acquire/)
- [PhyloPicPBDB Makie API](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/phylopic_makie/)
- [TaxonomyTreeMakie API](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/taxonomytree_makie/)
- [Interactive Help](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/apihelp/) — REPL-based parameter and field discovery
- [Depot](https://jeetsukumaran.github.io/PaleobiologyDB.jl/dev/api/depot/) — local data snapshot management

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