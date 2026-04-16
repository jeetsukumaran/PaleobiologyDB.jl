"""
    PaleobiologyDB.Taxonomy.TaxonTreeMakie

## Quick start

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.Taxonomy.TaxonTreeMakie

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Standalone figure (returns Figure, Axis, TaxonTreePlot)
fig, ax, p = taxontreeplot(tree; showtips = true, color_by_rank = true)
save("carnivora_families.png", fig)

# Add to an existing axis
fig2 = Figure(size = (900, 600))
ax2  = Axis(fig2[1, 1]; title = "Canidae genera")
tree2 = taxon_subtree("Canidae"; leaf_rank = "genus")
taxontreeplot!(ax2, tree2; showtips = true, ladderize = true)
set_rank_axis_ticks!(ax2, tree2)
display(fig2)

# Overlay PhyloPic silhouettes after the fact (recommended for fine control)
fig3, ax3, p3 = taxontreeplot(taxon_subtree("Panthera"))
augment_tip_phylopic!(ax3, p3; xoffset = 1.0)
```

## Public API

| Symbol | Description |
|---|---|
| `TaxonTreePlot` | Makie plot type (for dispatch / attribute access) |
| [`taxontreeplot`](@ref) | Create a standalone figure; returns `(Figure, Axis, TaxonTreePlot)` |
| `taxontreeplot!` | Add a dendrogram to an existing axis |
| [`set_rank_axis_ticks!`](@ref) | Label the x-axis with rank names at their depth positions |
| [`tip_positions`](@ref) | Extract leaf-tip coordinates `(vertices, names, x, y)` from a tree or plot |
| [`augment_tip_phylopic!`](@ref) | Add PhyloPic silhouettes at each leaf tip of an existing plot |
"""
module TaxonTreeMakie

import PhyloPicMakie
import PhyloPicMakie.Makie
# Bring @recipe and Attributes into scope; import Makie alone does not expose
# macros.  All other Makie symbols are accessed as Makie.xxx via the module-
# level `import Makie` in TaxonTreeMakie.jl.
using PhyloPicMakie.Makie: @recipe, Attributes
import Graphs

using PaleobiologyDB
using PaleobiologyDB.Taxonomy: TaxonTree, TaxonNode

export TaxonTreePlot, taxontreeplot, taxontreeplot!, set_rank_axis_ticks!
export tip_positions, augment_tip_phylopic!

include("_layout.jl")
include("_recipe.jl")
include("_phylopic.jl")
include("_augment.jl")

end # module TaxonTreeMakie
