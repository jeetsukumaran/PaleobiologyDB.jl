# PBDBMakie — Makie tree visualization

`PaleobiologyDB.PBDBMakie` is a package extension that renders
[`TaxonomyTree`](@ref) objects as rectangular dendrograms in Makie figures.
It activates when a Makie backend is loaded and is accessed through the
`PaleobiologyDB.PBDBMakie` submodule.

## Installation

```
pkg> add CairoMakie PhyloPicMakie
```

## Activation

```julia
using CairoMakie   # or GLMakie, WGLMakie, …
using PaleobiologyDB
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.PBDBMakie: taxonomytreeplot, taxonomytreeplot!, set_rank_axis_ticks!, augment_leaf_phylopic!
```

## Quick start — basic dendrogram

Build a subtree with [`taxon_subtree`](@ref) then pass it to `taxonomytreeplot`:

```julia
using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.PBDBMakie: taxonomytreeplot

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

fig, ax, plt = taxonomytreeplot(tree; show_leaf_labels = true)
display(fig)
```

`taxonomytreeplot` returns a `Makie.FigureAxisPlot` object containing the figure,
axis, and plot object accessible via `.figure`, `.axis`, and `.plot`. The x-axis is
automatically labelled with rank names at their dendrogram depth positions.

## Coloring by rank

Set `color_by_rank = true` to assign each branch and node a colour based on
its taxonomic rank:

```julia
fig, ax, plt = taxonomytreeplot(tree;
    color_by_rank = true,
    show_leaf_labels = true,
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

fig, ax, plt = taxonomytreeplot(tree;
    color_by_rank = true,
    rank_palette  = palette,
    show_leaf_labels = true,
)
```

## Ladderized layout

`ladderize = true` sorts children of each node by ascending subtree leaf count
before the depth-first traversal.  Smaller subtrees appear at the top of the
plot, giving a cleaner, more asymmetric appearance for trees with unequal
branching:

```julia
fig, ax, plt = taxonomytreeplot(tree;
    ladderize = true,
    show_leaf_labels = true,
)
```

## Showing internal node labels

Internal nodes (non-leaf taxa) can be labelled with their taxon names:

```julia
fig, ax, plt = taxonomytreeplot(tree;
    showinternal      = true,
    internal_fontsize = 7,
    internal_color    = :gray50,
    show_leaf_labels  = true,
)
```

## Adding to an existing Makie axis

`taxonomytreeplot!` adds a dendrogram to an axis you have already created,
allowing composition with other Makie plots or multi-panel figures:

```julia
using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.PBDBMakie: taxonomytreeplot!, set_rank_axis_ticks!

tree = taxon_subtree("Canidae"; leaf_rank = "genus")

fig = Figure(size = (1000, 700))
ax  = Axis(fig[1, 1]; title = "Canidae genera")

taxonomytreeplot!(ax, tree; show_leaf_labels = true, ladderize = true)
set_rank_axis_ticks!(ax, tree)

display(fig)
```

`set_rank_axis_ticks!` configures the x-axis ticks with rank names.  When
using the standalone `taxonomytreeplot`, this is called automatically unless
`show_rank_ticks = false` is passed.

## Multi-panel figure combining trees

```julia
using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.PBDBMakie: taxonomytreeplot!, set_rank_axis_ticks!

t_fam = taxon_subtree("Carnivora"; leaf_rank = "family")
t_gen = taxon_subtree("Canidae";   leaf_rank = "genus")

fig = Figure(size = (1400, 600))

ax1 = Axis(fig[1, 1]; title = "Carnivora — families")
taxonomytreeplot!(ax1, t_fam; show_leaf_labels = true, color_by_rank = true)
set_rank_axis_ticks!(ax1, t_fam)

ax2 = Axis(fig[1, 2]; title = "Canidae — genera")
taxonomytreeplot!(ax2, t_gen; show_leaf_labels = true, ladderize = true)
set_rank_axis_ticks!(ax2, t_gen)

display(fig)
```

## PhyloPic silhouettes beside leaf labels

`taxonomytreeplot` can overlay [PhyloPic](https://www.phylopic.org/) silhouette
images to the right of each leaf label. The default thumbnail-backed render
path works once a Makie backend and `PaleobiologyDB.PBDBMakie` are loaded:

```julia
using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.PBDBMakie: taxonomytreeplot
```

The default `phylopic_image_rendering = :thumbnail` path uses PNG thumbnails
through the hard dependency `PhyloPicMakie`. SVG-backed `:vector` or
`:source_file` cases still require an SVG-capable `FileIO` plugin in the
active environment.

### Inline mode (default)

Each silhouette appears immediately to the right of its taxon-name label.
The horizontal gap is controlled by `phylopic_xoffset` (in data units):

```julia
tree = taxon_subtree("Carnivora"; leaf_rank = "family")

fig, ax, plt = taxonomytreeplot(tree;
    show_leaf_labels = true,
    show_phylopic    = true,
    phylopic_xoffset = 0.25,
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
fig, ax, plt = taxonomytreeplot(tree;
    show_leaf_labels = true,
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
(total height = `2 × phylopic_glyph_size`).  The default `1.0` works well for
trees where leaves are spaced 2 units apart (the default `row_spacing`).  Set
`phylopic_aspect = :stretch` to force square glyphs instead of preserving the
original image proportions:

```julia
fig, ax, plt = taxonomytreeplot(tree;
    show_leaf_labels     = true,
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
| `:placeholder` | Draw a placeholder glyph image in place of the missing silhouette |
| `:error` | Throw an `ErrorException` |

```julia
fig, ax, plt = taxonomytreeplot(tree;
    show_phylopic       = true,
    phylopic_on_missing = :placeholder,
)
```

### Note on reactivity

PhyloPic images are loaded **once** when the plot is created.  Toggling
`p[:show_phylopic][] = false` after creation hides/shows the existing images
without re-downloading.  After creation, resize and relimit changes keep the
glyphs visibly sized and anchored to the intended label policy through the
shared overlay substrate.  Changing `phylopic_glyph_size`, `phylopic_align`,
or the tree itself still requires recreating the plot with
`taxonomytreeplot`.

### Note on extension activation

`show_phylopic = true` requires the `PBDBMakie` extension to be active,
which happens automatically when a Makie backend is loaded alongside
`PaleobiologyDB`. Bring the extension exports into scope with
`using PaleobiologyDB.PBDBMakie` or call them through the
`PaleobiologyDB.PBDBMakie` submodule. `PhyloPicMakie` is a hard
dependency of `PaleobiologyDB` and is always available once the package is
installed.

## Saving figures

Makie's standard `save` function works with any output format:

```julia
fig, ax, plt = taxonomytreeplot(tree; show_leaf_labels = true)

save("carnivora_families.png", fig)
save("carnivora_families.svg", fig)
save("carnivora_families.pdf", fig)
```

## Example scripts

`examples/src/taxonomytree.jl` is the direct happy-path tree example. It enables
`PaleobiologyDB.set_autocaching!(true)`, renders an Elephantidae genus tree
through the public `show_phylopic = true` path, saves `taxonomytree.png` in the
current working directory by default, and prints the output path. Pass a custom
output path as the first argument if you want the PNG somewhere else. Run it
from a development checkout with:

```bash
julia --project=examples examples/src/taxonomytree.jl
```

`examples/src/phylopicgallery.jl` is the companion gallery example. It enables
caching, builds a small multi-taxon PhyloPic gallery with `pbdb_phylopic_grid`,
saves `phylopicgallery.png` in the current working directory by default, and
prints the output path:

```bash
julia --project=examples examples/src/phylopicgallery.jl
```

## Custom figure and axis options

Pass `figure_kwargs` and `axis_kwargs` (named tuples) to control the
underlying `Figure` and `Axis`:

```julia
fig, ax, plt = taxonomytreeplot(tree;
    figure_kwargs = (; size = (1200, 900), backgroundcolor = :white),
    axis_kwargs   = (;
        title           = "Carnivora — family-level tree",
        titlesize       = 18,
        xlabel          = "Rank depth",
        xticklabelsize  = 11,
    ),
    show_leaf_labels = true,
    color_by_rank = true,
)
```

## Attribute reference

All attributes can be passed as keyword arguments to `taxonomytreeplot` or
`taxonomytreeplot!`.

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
| `show_leaf_labels` | `true` | Show leaf taxon-name labels |
| `leaf_label_fontsize` | `9` | Leaf label font size in points |
| `leaf_label_color` | `:black` | Leaf label colour |
| `leaf_label_xoffset` | `0.1` | Rightward offset for leaf labels in data units |
| `leaf_label_yoffset` | `0.0` | Vertical offset for leaf labels in data units (positive = upward) |
| `showinternal` | `false` | Show internal node name labels |
| `internal_fontsize` | `7` | Internal label font size in points |
| `internal_color` | `:gray40` | Internal label colour |
| `row_spacing` | `2.0` | Vertical gap between consecutive leaf rows in data units |
| `show_phylopic` | `false` | Draw a PhyloPic silhouette to the right of each leaf label |
| `phylopic_glyph_size` | `1.0` | Half-height of each silhouette in data units |
| `phylopic_align` | `false` | Place all silhouettes in a single right-hand column |
| `phylopic_xoffset` | `0.65` | Rightward gap in data units beyond the leaf-label origin |
| `phylopic_yoffset` | `0.3` | Vertical offset for PhyloPic silhouettes in data units (positive = upward) |
| `phylopic_image_rendering` | `:thumbnail` | Image URL to fetch: `:thumbnail`, `:raster`, `:og_image`, `:vector`, or `:source_file` |
| `phylopic_on_missing` | `:skip` | Policy when no image is found: `:skip`, `:placeholder` (placeholder glyph image), `:error` |
| `phylopic_aspect` | `:preserve` | `:preserve` (original proportions) or `:stretch` (square) |

The following keywords are consumed by `taxonomytreeplot` (standalone) and are
**not** passed to the recipe:

| Keyword | Default | Description |
|---|---|---|
| `show_rank_ticks` | `true` | Call `set_rank_axis_ticks!` automatically |
| `figure_kwargs` | `(;)` | Forwarded to `Makie.Figure(; ...)` |
| `axis_kwargs` | `(;)` | Forwarded to `Makie.Axis(; ...)` |
