
# Bring @recipe and Attributes into scope; import Makie alone does not expose
# macros.  All other Makie symbols are accessed as Makie.xxx via the module-
# level `import Makie` in TaxonTreeMakie.jl.
using Makie: @recipe, Attributes

# ---------------------------------------------------------------------------
# TaxonTreeMakie — @recipe definition, Makie.plot! implementation, and
# convenience wrappers.
#
# Call graph:
#
#   taxontreeplot(tree; ...)               (standalone, creates Figure + Axis)
#       └─► taxontreeplot!(ax, tree; ...)  (recipe-generated, adds to axis)
#               └─► Makie.plot!(p::TaxonTreePlot)
#                       ├─ _compute_dendrogram_layout  from _layout.jl
#                       ├─ _dendrogram_segment_pairs   from _layout.jl
#                       ├─ Makie.linesegments!
#                       ├─ Makie.scatter!
#                       └─ Makie.text!
#
#   set_rank_axis_ticks!(ax, tree)         (axis helper — call after taxontreeplot!)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Internal color helpers
# ---------------------------------------------------------------------------

# Fixed palette for rank-based coloring.  Drawn from a colorblind-friendly
# sequence; wraps around for trees that span more than 7 ranks.
const _RANK_COLORS = [
    Makie.RGBf(0.000, 0.447, 0.698),   # blue
    Makie.RGBf(0.902, 0.624, 0.000),   # orange
    Makie.RGBf(0.337, 0.706, 0.914),   # sky blue
    Makie.RGBf(0.000, 0.620, 0.451),   # green
    Makie.RGBf(0.941, 0.894, 0.259),   # yellow
    Makie.RGBf(0.835, 0.369, 0.000),   # vermillion
    Makie.RGBf(0.800, 0.475, 0.655),   # reddish purple
]

"""
    _build_rank_color_map(
        tree::TaxonTree,
        rank_palette::Union{AbstractDict, Nothing},
    ) -> Dict{String, Makie.RGBAf}

Build a mapping from rank name to colour for `tree`.

When `rank_palette` is a `Dict`, its entries take precedence; ranks absent
from the dict fall back to the built-in `_RANK_COLORS` cycle.  When
`rank_palette` is `nothing`, the built-in cycle is used for all ranks.

Ranks are sorted by their dendrogram depth (coarser first) before colours are
assigned, so the same rank always receives the same colour for a given tree.
"""
function _build_rank_color_map(
    tree::TaxonTree,
    rank_palette::Union{AbstractDict, Nothing},
)::Dict{String, Makie.RGBAf}
    ranks = sort(
        unique(n.rank for n in tree.taxa if !isempty(n.rank));
        by = r -> get(_RANK_DEPTH, r, 99),
    )
    return Dict{String, Makie.RGBAf}(
        r => Makie.RGBAf(Makie.to_color(
            isnothing(rank_palette)
                ? _RANK_COLORS[mod1(i, length(_RANK_COLORS))]
                : get(rank_palette, r, _RANK_COLORS[mod1(i, length(_RANK_COLORS))])
        ))
        for (i, r) in enumerate(ranks)
    )
end

"""
    _segment_colors_vec(
        tree::TaxonTree,
        segs::AbstractVector{<:NTuple{4}},
        rank_palette::Union{AbstractDict, Nothing},
        default_color,
    ) -> Vector{Makie.RGBAf}

Return a colour vector of length `2 * length(segs)` (one colour per
`linesegments!` point) for rank-based branch colouring.

Segments are in the same order as [`_dendrogram_segment_pairs`](@ref): for
each internal vertex, first the vertical connector (coloured by the vertex's
own rank), then one horizontal branch per child (coloured by the child's rank).

When `rank_palette` is `nothing`, the built-in cycle is used.
"""
function _segment_colors_vec(
    tree::TaxonTree,
    segs::AbstractVector,
    rank_palette::Union{AbstractDict, Nothing},
    default_color,
)::Vector{Makie.RGBAf}
    cmap = _build_rank_color_map(tree, rank_palette)
    fallback = Makie.RGBAf(Makie.to_color(default_color))
    g = tree.graph

    # Build one colour per segment in the same iteration order as
    # _dendrogram_segment_pairs, then duplicate for the 2-point representation.
    seg_colors = Makie.RGBAf[]
    sizehint!(seg_colors, length(segs))
    for v in Graphs.vertices(g)
        children = Graphs.outneighbors(g, v)
        isempty(children) && continue
        # Vertical connector → colour of vertex v
        push!(seg_colors, get(cmap, tree.taxa[v].rank, fallback))
        # Horizontal branch to each child → colour of child
        for c in children
            push!(seg_colors, get(cmap, tree.taxa[c].rank, fallback))
        end
    end

    # linesegments! expects one colour per point (2 × n_segments)
    return repeat(seg_colors; inner = 2)
end

"""
    _node_colors_vec(
        tree::TaxonTree,
        rank_palette::Union{AbstractDict, Nothing},
        default_color,
    ) -> Vector{Makie.RGBAf}

Return a colour vector, one entry per vertex of `tree` (in vertex-index order),
for rank-based node colouring.
"""
function _node_colors_vec(
    tree::TaxonTree,
    rank_palette::Union{AbstractDict, Nothing},
    default_color,
)::Vector{Makie.RGBAf}
    cmap = _build_rank_color_map(tree, rank_palette)
    fallback = Makie.RGBAf(Makie.to_color(default_color))
    return [
        get(cmap, tree.taxa[v].rank, fallback)
        for v in Graphs.vertices(tree.graph)
    ]
end

# ---------------------------------------------------------------------------
# Recipe definition
# ---------------------------------------------------------------------------

"""
    TaxonTreePlot

Makie plot type for rendering a [`TaxonTree`](@ref) as a rectangular
dendrogram.  Produced by [`taxontreeplot`](@ref) (standalone figure) or
[`taxontreeplot!`](@ref) (existing axis).

## Attributes

| Attribute | Default | Description |
|---|---|---|
| `ladderize` | `false` | Sort children of each node by ascending subtree leaf count |
| `branch_color` | `:black` | Branch line colour (used when `color_by_rank = false`) |
| `branch_linewidth` | `1.5` | Branch line width in points |
| `show_nodes` | `true` | Draw a circular marker at every vertex |
| `node_color` | `:black` | Node marker colour (used when `color_by_rank = false`) |
| `node_size` | `5` | Node marker size in points |
| `color_by_rank` | `false` | Colour branches and nodes by taxonomic rank |
| `rank_palette` | `nothing` | `Dict{String,Any}` mapping rank name → colour; `nothing` uses the built-in cycle |
| `showtips` | `true` | Show leaf taxon-name labels |
| `tip_fontsize` | `9` | Leaf label font size in points |
| `tip_color` | `:black` | Leaf label colour |
| `tip_xoffset` | `0.5` | Rightward offset for leaf labels in data units |
| `showinternal` | `false` | Show internal node name labels |
| `internal_fontsize` | `7` | Internal label font size in points |
| `internal_color` | `:gray40` | Internal label colour |

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Add to an existing Makie axis
fig = Figure(size = (900, 600))
ax  = Axis(fig[1, 1])
taxontreeplot!(ax, tree; showtips = true, color_by_rank = true)
set_rank_axis_ticks!(ax, tree)
display(fig)
```

See also [`taxontreeplot`](@ref), [`taxontreeplot!`](@ref),
[`set_rank_axis_ticks!`](@ref).
"""
@recipe(TaxonTreePlot, taxontree) do scene
    Attributes(
        # Layout
        ladderize         = false,
        # Branches
        branch_color      = :black,
        branch_linewidth  = 1.5,
        # Nodes
        show_nodes        = true,
        node_color        = :black,
        node_size         = 5,
        # Rank-based colouring
        color_by_rank     = false,
        rank_palette      = nothing,
        # Leaf labels
        showtips          = true,
        tip_fontsize      = 9,
        tip_color         = :black,
        tip_xoffset       = 0.5,
        # Internal labels
        showinternal      = false,
        internal_fontsize = 7,
        internal_color    = :gray40,
    )
end

# ---------------------------------------------------------------------------
# plot! implementation
# ---------------------------------------------------------------------------

function Makie.plot!(p::TaxonTreePlot{<:Tuple{TaxonTree}})
    tree_obs = p[:taxontree]

    # ── Layout (reactive to tree and ladderize) ───────────────────────────
    layout_obs = Makie.lift(tree_obs, p[:ladderize]) do tree, lad
        _compute_dendrogram_layout(tree; ladderize = lad)
    end

    # ── Branch segments: (x1,y1,x2,y2) tuples ────────────────────────────
    segs_obs = Makie.lift(layout_obs, tree_obs) do (xs, ys), tree
        _dendrogram_segment_pairs(tree, xs, ys)
    end

    # ── Convert to Point2f pairs for linesegments! ────────────────────────
    pts_obs = Makie.lift(segs_obs) do segs
        pts = Makie.Point2f[]
        sizehint!(pts, 2 * length(segs))
        for (x1, y1, x2, y2) in segs
            push!(pts, Makie.Point2f(x1, y1))
            push!(pts, Makie.Point2f(x2, y2))
        end
        pts
    end

    # ── Branch colours ────────────────────────────────────────────────────
    branch_colors_obs = Makie.lift(
        tree_obs, segs_obs,
        p[:color_by_rank], p[:rank_palette], p[:branch_color],
    ) do tree, segs, cbr, palette, bc
        cbr ? _segment_colors_vec(tree, segs, palette, bc) :
              fill(Makie.RGBAf(Makie.to_color(bc)), 2 * length(segs))
    end

    Makie.linesegments!(
        p, pts_obs;
        color     = branch_colors_obs,
        linewidth = p[:branch_linewidth],
    )

    # ── Node markers ──────────────────────────────────────────────────────
    node_pts_obs = Makie.lift(layout_obs, tree_obs) do (xs, ys), tree
        [Makie.Point2f(xs[v], ys[v]) for v in Graphs.vertices(tree.graph)]
    end

    node_colors_obs = Makie.lift(
        tree_obs, p[:color_by_rank], p[:rank_palette], p[:node_color],
    ) do tree, cbr, palette, nc
        cbr ? _node_colors_vec(tree, palette, nc) :
              fill(Makie.RGBAf(Makie.to_color(nc)), Graphs.nv(tree.graph))
    end

    Makie.scatter!(
        p, node_pts_obs;
        color      = node_colors_obs,
        markersize = p[:node_size],
        visible    = p[:show_nodes],
    )

    # ── Leaf labels ───────────────────────────────────────────────────────
    leaf_vertices_obs = Makie.lift(tree_obs) do tree
        g = tree.graph
        [v for v in Graphs.vertices(g) if isempty(Graphs.outneighbors(g, v))]
    end

    leaf_pts_obs = Makie.lift(layout_obs, leaf_vertices_obs, p[:tip_xoffset]) do (xs, ys), lvs, xoff
        [Makie.Point2f(xs[v] + xoff, ys[v]) for v in lvs]
    end

    leaf_names_obs = Makie.lift(tree_obs, leaf_vertices_obs) do tree, lvs
        [tree.taxa[v].name for v in lvs]
    end

    Makie.text!(
        p, leaf_pts_obs;
        text    = leaf_names_obs,
        fontsize = p[:tip_fontsize],
        color   = p[:tip_color],
        align   = (:left, :center),
        visible = p[:showtips],
    )

    # ── Internal node labels ──────────────────────────────────────────────
    internal_vertices_obs = Makie.lift(tree_obs) do tree
        g = tree.graph
        [v for v in Graphs.vertices(g) if !isempty(Graphs.outneighbors(g, v))]
    end

    internal_pts_obs = Makie.lift(layout_obs, internal_vertices_obs) do (xs, ys), ivs
        [Makie.Point2f(xs[v], ys[v]) for v in ivs]
    end

    internal_names_obs = Makie.lift(tree_obs, internal_vertices_obs) do tree, ivs
        [tree.taxa[v].name for v in ivs]
    end

    Makie.text!(
        p, internal_pts_obs;
        text     = internal_names_obs,
        fontsize = p[:internal_fontsize],
        color    = p[:internal_color],
        align    = (:center, :bottom),
        visible  = p[:showinternal],
    )

    return p
end

# ---------------------------------------------------------------------------
# Axis helper
# ---------------------------------------------------------------------------

"""
    set_rank_axis_ticks!(ax::Makie.Axis, tree::TaxonTree) -> Nothing

Configure the x-axis tick labels on `ax` to display rank names at their
dendrogram x-depth positions.

Only ranks that are present in `tree` and whose depth is known (i.e. present
in `_RANK_DEPTH`) are labelled.  Tick labels are rotated 45° to prevent
overlap.

Typically called immediately after [`taxontreeplot!`](@ref):

```julia
p = taxontreeplot!(ax, tree; showtips = true)
set_rank_axis_ticks!(ax, tree)
```

[`taxontreeplot`](@ref) (standalone) calls this automatically when
`show_rank_ticks = true` (the default).

## Arguments

- `ax`: the `Makie.Axis` on which to set ticks.
- `tree`: the [`TaxonTree`](@ref) whose ranks determine the tick positions.
"""
function set_rank_axis_ticks!(ax::Makie.Axis, tree::TaxonTree)::Nothing
    depths_and_ranks = sort(
        [
            (_rank_depth(r), r)
            for r in unique(n.rank for n in tree.taxa if !isempty(n.rank))
            if _rank_depth(r) >= 0
        ];
        by = first,
    )
    ax.xticks = (
        Float64[d for (d, _) in depths_and_ranks],
        [r for (_, r) in depths_and_ranks],
    )
    ax.xticklabelrotation = π / 4
    return nothing
end

# ---------------------------------------------------------------------------
# Standalone wrapper: taxontreeplot
# ---------------------------------------------------------------------------

"""
    taxontreeplot(
        tree::TaxonTree;
        show_rank_ticks::Bool = true,
        figure_kwargs::NamedTuple = (;),
        axis_kwargs::NamedTuple = (;),
        kwargs...,
    ) -> Tuple{Makie.Figure, Makie.Axis, TaxonTreePlot}

Create a standalone Makie figure containing a dendrogram of `tree`.

Returns `(fig, ax, plot_object)`, which can be destructured:

```julia
fig, ax, p = taxontreeplot(tree; showtips = true)
display(fig)
save("tree.png", fig)
```

## Arguments

- `tree`: the [`TaxonTree`](@ref) to visualise.
- `show_rank_ticks` (default `true`): when `true`, calls
  [`set_rank_axis_ticks!`](@ref) to label the x-axis with rank names.
- `figure_kwargs`: keyword arguments forwarded to `Makie.Figure(; ...)`.
- `axis_kwargs`: keyword arguments forwarded to `Makie.Axis(; ...)`.
- All remaining keyword arguments are forwarded to [`TaxonTreePlot`](@ref)
  attributes (see [`taxontreeplot!`](@ref)).

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonTreeMakie

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Basic dendrogram with tip labels
fig, ax, p = taxontreeplot(tree; showtips = true)
save("carnivora_families.png", fig)

# Coloured by rank, ladderized
fig2, ax2, p2 = taxontreeplot(tree;
    color_by_rank = true,
    ladderize     = true,
    showtips      = true,
)

# Custom figure and axis sizes
fig3, ax3, p3 = taxontreeplot(tree;
    figure_kwargs = (; size = (1200, 800)),
    axis_kwargs   = (; title = "Carnivora families", yreversed = false),
)
```

See also [`taxontreeplot!`](@ref), [`TaxonTreePlot`](@ref),
[`set_rank_axis_ticks!`](@ref).
"""
function taxontreeplot(
    tree::TaxonTree;
    show_rank_ticks::Bool = true,
    figure_kwargs::NamedTuple = (;),
    axis_kwargs::NamedTuple = (;),
    kwargs...,
)::Tuple{Makie.Figure, Makie.Axis, TaxonTreePlot}
    fig = Makie.Figure(; figure_kwargs...)
    ax  = Makie.Axis(fig[1, 1]; axis_kwargs...)
    p   = taxontreeplot!(ax, tree; kwargs...)
    show_rank_ticks && set_rank_axis_ticks!(ax, tree)
    return (fig, ax, p)
end
