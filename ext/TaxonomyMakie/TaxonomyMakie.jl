"""
    TaxonomyMakie

Package extension for PaleobiologyDB.jl that activates when both Makie and
PhyloPicMakie are loaded.  Provides the full tree-visualization API (moved from
the former TaxonomyTreeMakie source submodule) and the PBDB–PhyloPic bridge
(vendored from the former PhyloPicPBDB source submodule).

Activated by:

    using PaleobiologyDB, PhyloPicMakie   # (any Makie backend triggers Makie)

Public API — tree visualization:

| Symbol | Description |
|---|---|
| `TaxonomyTreePlot` | Makie plot type |
| `taxonomytreeplot` | Standalone figure; returns `(Figure, Axis, TaxonomyTreePlot)` |
| `taxonomytreeplot!` | Add dendrogram to existing axis |
| `set_rank_axis_ticks!` | Label x-axis with rank names |
| `tip_positions` | Leaf-tip coordinates from a tree or plot |
| `augment_tip_phylopic!` | PhyloPic silhouettes at leaf tips |

Public API — PBDB–PhyloPic bridge (re-exported from PhyloPicPBDB):

| Symbol | Description |
|---|---|
| `acquire_phylopic` | Single-taxon or DataFrame enrichment |
| `augment_phylopic` / `augment_phylopic!` | Glyph overlay on Makie axis |
| `augment_phylopic_ranges` / `augment_phylopic_ranges!` | Range-anchored glyphs |
| `phylopic_images_dataframe` | All images for a taxon |
| `phylopic_node` | PBDB → PhyloPic node lookup |
| `phylopic_images` | PBDB → PhyloPic images |
| `phylopic_thumbnail_grid` / `phylopic_thumbnail_grid!` | Gallery figure/axis |
"""
module TaxonomyMakie

import Makie
import PhyloPicMakie
using PhyloPicMakie.Makie: @recipe, Attributes
import Graphs

using PaleobiologyDB
using PaleobiologyDB.Taxonomy: TaxonomyTree, TaxonNode, taxon_subtree

# Vendored PBDB–PhyloPic bridge submodule.
include("PhyloPicPBDB/src/PhyloPicPBDB.jl")
using .PhyloPicPBDB  # bring PhyloPicPBDB exports into TaxonomyMakie's scope for re-export

# Tree-visualization implementation files.
include("_layout.jl")
include("_recipe.jl")
include("_phylopic.jl")
include("_augment.jl")

# Tree-visualization exports (formerly TaxonomyTreeMakie).
export TaxonomyTreePlot, taxonomytreeplot, taxonomytreeplot!, set_rank_axis_ticks!
export tip_positions, augment_tip_phylopic!

# PBDB–PhyloPic bridge exports (re-exported from PhyloPicPBDB for flat API surface).
export acquire_phylopic
export augment_phylopic
export phylopic_images_dataframe
export phylopic_node
export phylopic_images
export augment_phylopic!
export augment_phylopic_ranges!
export augment_phylopic_ranges
export phylopic_thumbnail_grid!
export phylopic_thumbnail_grid

# Bind this extension in the parent package at load time (not precompile time)
# so users can access it via `using PaleobiologyDB.TaxonomyMakie`.
function __init__()
    Core.eval(PaleobiologyDB, :(TaxonomyMakie = $(@__MODULE__)))
end

end # module TaxonomyMakie
