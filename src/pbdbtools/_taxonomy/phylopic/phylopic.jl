"""
    PaleobiologyDB.Taxonomy.PhyloPicPBDB

PBDB-specific PhyloPic integration submodule.

Provides the PBDB → PhyloPic name resolution pipeline and Makie visualization
wrappers.

## Data API (re-exported from `Taxonomy`)

| Function | Description |
|---|---|
| `acquire_phylopic(taxon_name, prefix; ...)` | Single-taxon metadata lookup → NamedTuple |
| `acquire_phylopic(df, field, prefix; ...)` | DataFrame enrichment → DataFrame |
| `augment_phylopic(df, field, prefix; ...)` | In-place DataFrame enrichment |
| `phylopic_images_dataframe(taxon_name; ...)` | All images for a taxon → DataFrame |
| `phylopic_node(taxon_name; ...)` | PBDB → PhyloPic node lookup → PhyloPicNode |
| `phylopic_images(taxon_name; ...)` | PBDB → PhyloPic images → Vector{PhyloPicImage} |

## Makie API

| Function | Description |
|---|---|
| `augment_phylopic!(ax, xs, ys; taxon, ...)` | Add one glyph per datum |
| `augment_phylopic(ax, xs, ys; taxon, ...)` | Non-bang alias |
| `augment_phylopic!(ax, table; x, y, taxon, ...)` | Table-oriented variant |
| `augment_phylopic_ranges!(ax, xstart, xstop, y; taxon, ...)` | Range-anchored glyphs |
| `augment_phylopic_ranges(...)` | Non-bang alias |
| `phylopic_thumbnail_grid!(ax, taxon; ...)` | Gallery in existing axis |
| `phylopic_thumbnail_grid(taxon; ...)` | Factory: creates Figure + Axis |
"""
module PhyloPicPBDB

import PhyloPicMakie
# Access PhyloPicDB through the nested module hierarchy.
const PhyloPicDB = PhyloPicMakie.PhyloPicDB

import Makie
using Makie: RGBA, N0f8, Colorant
import DataCaches: autocache
import DataFrames: DataFrame, AbstractDataFrame, nrow, hcat

# Core PBDB-PhyloPic data bridge (no Makie dependency).
# Exports: acquire_phylopic, augment_phylopic (DataFrame variant),
#          phylopic_images_dataframe, phylopic_node, phylopic_images
include("_phylopic_core.jl")

# Makie visualization bridge.
# Exports: augment_phylopic! (Axis variants), augment_phylopic (Axis variants),
#          augment_phylopic_ranges!, augment_phylopic_ranges,
#          phylopic_thumbnail_grid!, phylopic_thumbnail_grid
include("_resolve.jl")
include("_render.jl")
include("_phylopic_thumbnail_grid.jl")

end # module PhyloPicPBDB
