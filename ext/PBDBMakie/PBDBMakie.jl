"""
    PBDBMakie

Package extension for PaleobiologyDB.jl that activates when both Makie and
PhyloPicMakie are loaded.  Provides the full tree-visualization API and the
PBDB–PhyloPic bridge (vendored from the former PhyloPic source submodule).

Activated by:

    using CairoMakie  # or any Makie backend
    using PaleobiologyDB
    using PaleobiologyDB.PBDBMakie

Public API — tree visualization:

| Symbol | Description |
|---|---|
| `TaxonomyTreePlot` | Makie plot type |
| `taxonomytreeplot` | Standalone figure; returns `Makie.FigureAxisPlot` |
| `taxonomytreeplot!` | Add dendrogram to existing axis |
| `set_rank_axis_ticks!` | Label x-axis with rank names |
| `leaf_positions` | Leaf-node coordinates from a tree or plot |
| `augment_leaf_phylopic!` | PhyloPic silhouettes anchored at leaves or leaf labels |

Public API — PBDB–PhyloPic bridge (re-exported from PhyloPic):

| Symbol | Description |
|---|---|
| `acquire_phylopic` | Single-taxon or DataFrame enrichment |
| `augment_phylopic` / `augment_phylopic!` | Glyph overlay on Makie axis |
| `augment_phylopic_ranges` / `augment_phylopic_ranges!` | Range-anchored glyphs |
| `phylopic_images_dataframe` | All images for a taxon |
| `phylopic_node` | PBDB → PhyloPic node lookup |
| `phylopic_images` | PBDB → PhyloPic images |
| `pbdb_phylopic_grid` / `pbdb_phylopic_grid!` | Gallery figure/axis |
"""
module PBDBMakie

import Makie
import PhyloPicMakie
using Makie: @recipe, Attributes
import Graphs

using PaleobiologyDB
using PaleobiologyDB.Taxonomy: TaxonomyTree, TaxonNode, taxon_subtree

# Vendored PBDB–PhyloPic bridge submodule.
include("PhyloPic/src/PhyloPic.jl")
using .PhyloPic  # bring PhyloPic exports into PBDBMakie's scope for re-export

# Tree-visualization implementation files.
include("_layout.jl")
include("_leaf_overlay.jl")
include("_recipe.jl")
include("_augment.jl")

# Tree-visualization exports.
export TaxonomyTreePlot, taxonomytreeplot, taxonomytreeplot!, set_rank_axis_ticks!
export leaf_positions, augment_leaf_phylopic!

# PBDB–PhyloPic bridge exports (re-exported from PhyloPic for flat API surface).
export acquire_phylopic
export augment_phylopic
export phylopic_images_dataframe
export phylopic_node
export phylopic_images
export augment_phylopic!
export augment_phylopic_ranges!
export augment_phylopic_ranges
export pbdb_phylopic_grid!
export pbdb_phylopic_grid

# Julia's extension system does not re-export extension symbols into the parent
# module's namespace. Without this binding, `using PaleobiologyDB.PBDBMakie`
# (the canonical way for users to bring this extension's exports into scope) would
# not work. This is a deliberate design choice: PBDBMakie is exposed as a
# named sub-module of PaleobiologyDB until it becomes its own registered package,
# at which point this will be replaced by a normal `using` statement.
function __init__()
    Core.eval(PaleobiologyDB, :(PBDBMakie = $(@__MODULE__)))
end

end # module PBDBMakie
