"""
    PaleobiologyDB.TaxonTreeMakie

Makie extension providing `@recipe`-based visualisation of [`TaxonTree`](@ref)
objects as rectangular dendrograms.

The extension activates automatically when any Makie backend is loaded:

```julia
using PaleobiologyDB
using CairoMakie   # or GLMakie, WGLMakie, …
# → PaleobiologyDB.TaxonTreeMakie is now available
```

## Quick start

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

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
```

## Public API

| Symbol | Description |
|---|---|
| [`TaxonTreePlot`](@ref) | Makie plot type (for dispatch / attribute access) |
| [`taxontreeplot`](@ref) | Create a standalone figure; returns `(Figure, Axis, TaxonTreePlot)` |
| [`taxontreeplot!`](@ref) | Add a dendrogram to an existing axis |
| [`set_rank_axis_ticks!`](@ref) | Label the x-axis with rank names at their depth positions |
"""
module TaxonTreeMakie

import Makie
import Graphs

using PaleobiologyDB
using PaleobiologyDB.Taxonomy: TaxonTree, TaxonNode

export TaxonTreePlot, taxontreeplot, taxontreeplot!, set_rank_axis_ticks!

include("_layout.jl")
include("_recipe.jl")

function __init__()
    # Bind this extension module to PaleobiologyDB.TaxonTreeMakie so that
    # callers can access it as PaleobiologyDB.TaxonTreeMakie after extension
    # load.  Julia 1.9+ extensions are top-level modules and are not
    # automatically installed as submodule bindings in the parent package.
    Core.eval(PaleobiologyDB, :(const TaxonTreeMakie = $(@__MODULE__)))
end

end # module TaxonTreeMakie
