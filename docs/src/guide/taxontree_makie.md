# TaxonTreeMakie — Makie tree visualization

`PaleobiologyDB.TaxonTreeMakie` is an optional extension that renders
[`TaxonTree`](@ref) objects as rectangular dendrograms in Makie figures.
It activates automatically when any Makie backend is loaded.

## Installation

Only a Makie backend is required — no additional packages beyond the backend:

```
pkg> add CairoMakie
```

## Activation

```julia
using PaleobiologyDB
using CairoMakie   # or GLMakie, WGLMakie, …
# → PaleobiologyDB.TaxonTreeMakie activates automatically
using PaleobiologyDB.TaxonTreeMakie
```

After loading the trigger package the extension module is accessible as
`PaleobiologyDB.TaxonTreeMakie`, and its exported symbols (`taxontreeplot`,
`taxontreeplot!`, `TaxonTreePlot`, `set_rank_axis_ticks!`) are brought into
scope via `using PaleobiologyDB.TaxonTreeMakie`.

## Quick start — basic dendrogram

Build a subtree with [`taxon_subtree`](@ref) then pass it to `taxontreeplot`:

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

fig, ax, p = taxontreeplot(tree; showtips = true)
display(fig)
```

`taxontreeplot` returns a 3-tuple `(fig, ax, plot_object)`.  The x-axis is
automatically labelled with rank names at their dendrogram depth positions.

## Coloring by rank

Set `color_by_rank = true` to assign each branch and node a colour based on
its taxonomic rank:

```julia
fig, ax, p = taxontreeplot(tree;
    color_by_rank = true,
    showtips      = true,
)
display(fig)
```

A custom palette can be supplied as a `Dict{String, Any}` mapping rank names
to any Makie-compatible colour:

```julia
palette = Dict(
    "order"  => :steelblue,
    "family" => :darkorange,
    "genus"  => :seagreen,
)

fig, ax, p = taxontreeplot(tree;
    color_by_rank = true,
    rank_palette  = palette,
    showtips      = true,
)
```

## Ladderized layout

`ladderize = true` sorts children of each node by ascending subtree leaf count
before the depth-first traversal.  Smaller subtrees appear at the top of the
plot, giving a cleaner, more asymmetric appearance for trees with unequal
branching:

```julia
fig, ax, p = taxontreeplot(tree;
    ladderize = true,
    showtips  = true,
)
```

## Showing internal node labels

Internal nodes (non-leaf taxa) can be labelled with their taxon names:

```julia
fig, ax, p = taxontreeplot(tree;
    showinternal      = true,
    internal_fontsize = 7,
    internal_color    = :gray50,
    showtips          = true,
)
```

## Adding to an existing Makie axis

`taxontreeplot!` adds a dendrogram to an axis you have already created,
allowing composition with other Makie plots or multi-panel figures:

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

tree = taxon_subtree("Canidae"; leaf_rank = "genus")

fig = Figure(size = (1000, 700))
ax  = Axis(fig[1, 1]; title = "Canidae genera")

taxontreeplot!(ax, tree; showtips = true, ladderize = true)
set_rank_axis_ticks!(ax, tree)

display(fig)
```

`set_rank_axis_ticks!` configures the x-axis ticks with rank names.  When
using the standalone `taxontreeplot`, this is called automatically unless
`show_rank_ticks = false` is passed.

## Multi-panel figure combining trees

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

t_fam = taxon_subtree("Carnivora"; leaf_rank = "family")
t_gen = taxon_subtree("Canidae";   leaf_rank = "genus")

fig = Figure(size = (1400, 600))

ax1 = Axis(fig[1, 1]; title = "Carnivora — families")
taxontreeplot!(ax1, t_fam; showtips = true, color_by_rank = true)
set_rank_axis_ticks!(ax1, t_fam)

ax2 = Axis(fig[1, 2]; title = "Canidae — genera")
taxontreeplot!(ax2, t_gen; showtips = true, ladderize = true)
set_rank_axis_ticks!(ax2, t_gen)

display(fig)
```

## Saving figures

Makie's standard `save` function works with any output format:

```julia
fig, ax, p = taxontreeplot(tree; showtips = true)

save("carnivora_families.png", fig)
save("carnivora_families.svg", fig)
save("carnivora_families.pdf", fig)
```

## Custom figure and axis options

Pass `figure_kwargs` and `axis_kwargs` (named tuples) to control the
underlying `Figure` and `Axis`:

```julia
fig, ax, p = taxontreeplot(tree;
    figure_kwargs = (; size = (1200, 900), backgroundcolor = :white),
    axis_kwargs   = (;
        title           = "Carnivora — family-level tree",
        titlesize       = 18,
        xlabel          = "Rank depth",
        xticklabelsize  = 11,
    ),
    showtips      = true,
    color_by_rank = true,
)
```

## Attribute reference

All attributes can be passed as keyword arguments to `taxontreeplot` or
`taxontreeplot!`.

| Attribute | Default | Description |
|---|---|---|
| `ladderize` | `false` | Sort children of each node by ascending subtree leaf count |
| `branch_color` | `:black` | Branch line colour (used when `color_by_rank = false`) |
| `branch_linewidth` | `1.5` | Branch line width in points |
| `show_nodes` | `true` | Draw a circular marker at every vertex |
| `node_color` | `:black` | Node marker colour (used when `color_by_rank = false`) |
| `node_size` | `5` | Node marker size in points |
| `color_by_rank` | `false` | Colour branches and nodes by taxonomic rank |
| `rank_palette` | `nothing` | `Dict{String,Any}` mapping rank → colour; `nothing` uses the built-in cycle |
| `showtips` | `true` | Show leaf taxon-name labels |
| `tip_fontsize` | `9` | Leaf label font size in points |
| `tip_color` | `:black` | Leaf label colour |
| `tip_xoffset` | `0.5` | Rightward offset for leaf labels in data units |
| `showinternal` | `false` | Show internal node name labels |
| `internal_fontsize` | `7` | Internal label font size in points |
| `internal_color` | `:gray40` | Internal label colour |

The following keywords are consumed by `taxontreeplot` (standalone) and are
**not** passed to the recipe:

| Keyword | Default | Description |
|---|---|---|
| `show_rank_ticks` | `true` | Call `set_rank_axis_ticks!` automatically |
| `figure_kwargs` | `(;)` | Forwarded to `Makie.Figure(; ...)` |
| `axis_kwargs` | `(;)` | Forwarded to `Makie.Axis(; ...)` |
