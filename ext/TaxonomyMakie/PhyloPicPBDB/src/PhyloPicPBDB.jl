"""
    PaleobiologyDB.PhyloPicPBDB

PBDB-specific PhyloPic integration submodule.

Provides the PBDB → PhyloPic name resolution pipeline and Makie visualization
wrappers.

## Data API

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

import ..PhyloPicMakie
# Access PhyloPicDB and Makie through the parent extension's PhyloPicMakie binding.
# PhyloPicMakie is a weakdep trigger imported by TaxonomyMakie (the parent extension),
# so we reference it via the parent scope rather than importing it afresh.
const PhyloPicDB = PhyloPicMakie.PhyloPicDB
const Makie = PhyloPicMakie.Makie
const RGBA = Makie.RGBA
const N0f8 = Makie.N0f8
const Colorant = Makie.Colorant
import DataCaches: autocache
import DataFrames: DataFrame, AbstractDataFrame, nrow, hcat

# Data API exports
export acquire_phylopic
export augment_phylopic
export phylopic_images_dataframe
export phylopic_node
export phylopic_images

# Makie API exports
export augment_phylopic!
export augment_phylopic_ranges!
export augment_phylopic_ranges
export phylopic_thumbnail_grid!
export phylopic_thumbnail_grid

# Core PBDB-PhyloPic data bridge (no Makie dependency).
include("_phylopic_core.jl")

# Makie visualization bridge.
include("_resolve.jl")
include("_render.jl")
include("_phylopic_thumbnail_grid.jl")

end # module PhyloPicPBDB
