# TaxonTreeMakie — Makie tree visualization

`PaleobiologyDB.TaxonTreeMakie` is a submodule that renders
[`TaxonTree`](@ref) objects as rectangular dendrograms in Makie figures.

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

## PhyloPic silhouettes at leaf tips

`taxontreeplot` can overlay [PhyloPic](https://www.phylopic.org/) silhouette
images to the right of each leaf-tip label.  This requires `FileIO` to be
loaded in the same session (which also activates `PhyloPicMakie`):

```julia
using PaleobiologyDB
using CairoMakie
using FileIO   # enables PhyloPic image decoding
using PaleobiologyDB.TaxonTreeMakie
```

### Inline mode (default)

Each silhouette appears immediately to the right of its taxon-name label.
The horizontal gap is controlled by `phylopic_xoffset` (in data units):

```julia
tree = taxon_subtree("Carnivora"; leaf_rank = "family")

fig, ax, p = taxontreeplot(tree;
    showtips         = true,
    show_phylopic    = true,
    phylopic_xoffset = 0.5,
)
display(fig)
```

The result looks like:

```
────* Felidae     [IMG]
────* Canidae  [IMG]
```

### Aligned mode

Set `phylopic_align = true` to place all silhouettes in a single right-hand
column, regardless of label length.  Increase `phylopic_xoffset` to control
the column's distance from the deepest rank:

```julia
fig, ax, p = taxontreeplot(tree;
    showtips         = true,
    show_phylopic    = true,
    phylopic_align   = true,
    phylopic_xoffset = 2.0,
)
display(fig)
```

The result looks like:

```
────* Felidae                    [IMG]
────* Canidae                    [IMG]
────* Ursidae                    [IMG]
```

### Controlling glyph size and aspect ratio

`phylopic_glyph_size` sets the half-height of each silhouette in data units
(total height = `2 × phylopic_glyph_size`).  The default `0.4` works well for
trees where leaves are spaced 1 unit apart.  Set `phylopic_aspect = :stretch`
to force square glyphs instead of preserving the original image proportions:

```julia
fig, ax, p = taxontreeplot(tree;
    showtips             = true,
    show_phylopic        = true,
    phylopic_glyph_size  = 0.35,
    phylopic_aspect      = :preserve,   # default — maintains original proportions
)
```

### Handling missing images

Some taxa lack PhyloPic images.  The `phylopic_on_missing` attribute controls
what happens:

| Value | Behaviour |
|---|---|
| `:skip` (default) | Silently omit the glyph |
| `:placeholder` | Draw a translucent grey rectangle in place of the image |
| `:error` | Throw an `ErrorException` |

```julia
fig, ax, p = taxontreeplot(tree;
    show_phylopic       = true,
    phylopic_on_missing = :placeholder,
)
```

### Note on reactivity

PhyloPic images are loaded **once** when the plot is created.  Toggling
`p[:show_phylopic][] = false` after creation hides/shows the existing images
without re-downloading.  Changing `phylopic_glyph_size`, `phylopic_align`, or
the tree itself requires recreating the plot with `taxontreeplot`.

### Note on FileIO

If `FileIO` is not loaded, `show_phylopic = true` emits a one-time warning
and falls back to the `phylopic_on_missing` policy (default `:skip`, so no
images and no error).

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
| `show_phylopic` | `false` | Draw a PhyloPic silhouette to the right of each leaf tip (requires `FileIO`) |
| `phylopic_glyph_size` | `0.4` | Half-height of each silhouette in data units |
| `phylopic_align` | `false` | Place all silhouettes in a single right-hand column |
| `phylopic_xoffset` | `0.3` | Rightward gap in data units beyond the tip-label start position |
| `phylopic_on_missing` | `:skip` | Policy when no image is found: `:skip`, `:placeholder`, `:error` |
| `phylopic_aspect` | `:preserve` | `:preserve` (original proportions) or `:stretch` (square) |

The following keywords are consumed by `taxontreeplot` (standalone) and are
**not** passed to the recipe:

| Keyword | Default | Description |
|---|---|---|
| `show_rank_ticks` | `true` | Call `set_rank_axis_ticks!` automatically |
| `figure_kwargs` | `(;)` | Forwarded to `Makie.Figure(; ...)` |
| `axis_kwargs` | `(;)` | Forwarded to `Makie.Axis(; ...)` |
