# ---------------------------------------------------------------------------
# TaxonomyTreeMakie — @recipe definition, Makie.plot! implementation, and
# convenience wrappers.
#
# Call graph:
#
#   taxonomytreeplot(tree; ...)               (standalone, creates Figure + Axis)
#       └─► taxonomytreeplot!(ax, tree; ...)  (recipe-generated, adds to axis)
#               └─► Makie.plot!(p::TaxonomyTreePlot)
#                       ├─ _compute_dendrogram_layout  from _layout.jl
#                       ├─ _dendrogram_segment_pairs   from _layout.jl
#                       ├─ Makie.linesegments!
#                       ├─ Makie.scatter!
#                       └─ Makie.text!
#
#   set_rank_axis_ticks!(ax, tree)         (axis helper — call after taxonomytreeplot!)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Internal color helpers
# ---------------------------------------------------------------------------

# Fixed palette for rank-based coloring.  Drawn from a colorblind-friendly
# sequence; wraps around for trees that span more than 7 ranks.
const _RANK_COLORS = [
    Makie.RGBf(0.0, 0.447, 0.698),   # blue
    Makie.RGBf(0.902, 0.624, 0.0),   # orange
    Makie.RGBf(0.337, 0.706, 0.914),   # sky blue
    Makie.RGBf(0.0, 0.62, 0.451),   # green
    Makie.RGBf(0.941, 0.894, 0.259),   # yellow
    Makie.RGBf(0.835, 0.369, 0.0),   # vermillion
    Makie.RGBf(0.8, 0.475, 0.655),   # reddish purple
]

"""
    _build_rank_color_map(
        tree::TaxonomyTree,
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
        tree::TaxonomyTree,
        rank_palette::Union{AbstractDict, Nothing},
    )::Dict{String, Makie.RGBAf}
    ranks = sort(
        unique(n.rank for n in tree.taxa if !isempty(n.rank));
        by = r -> get(_RANK_DEPTH, r, 99),
    )
    return Dict{String, Makie.RGBAf}(
        r => Makie.RGBAf(
                Makie.to_color(
                    isnothing(rank_palette)
                    ? _RANK_COLORS[mod1(i, length(_RANK_COLORS))]
                    : get(rank_palette, r, _RANK_COLORS[mod1(i, length(_RANK_COLORS))])
                )
            )
            for (i, r) in enumerate(ranks)
    )
end

"""
    _segment_colors_vec(
        tree::TaxonomyTree,
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
        tree::TaxonomyTree,
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
        tree::TaxonomyTree,
        rank_palette::Union{AbstractDict, Nothing},
        default_color,
        vertices::AbstractVector{<:Integer} = collect(Graphs.vertices(tree.graph)),
    ) -> Vector{Makie.RGBAf}

Return a colour vector, one entry per element of `vertices` (in the order given),
for rank-based node colouring.

When `vertices` is omitted, colours are returned for all vertices of `tree` in
vertex-index order.  Pass a filtered list to colour only a subset of nodes (e.g.
when unifurcation nodes are hidden via `show_unifurcation_nodes = false`).
"""
function _node_colors_vec(
        tree::TaxonomyTree,
        rank_palette::Union{AbstractDict, Nothing},
        default_color,
        vertices::AbstractVector{<:Integer} = collect(Graphs.vertices(tree.graph)),
    )::Vector{Makie.RGBAf}
    cmap = _build_rank_color_map(tree, rank_palette)
    fallback = Makie.RGBAf(Makie.to_color(default_color))
    return [get(cmap, tree.taxa[v].rank, fallback) for v in vertices]
end

# ---------------------------------------------------------------------------
# Recipe definition
# ---------------------------------------------------------------------------

"""
    TaxonomyTreePlot

Makie plot type for rendering a [`TaxonomyTree`](@ref) as a rectangular
dendrogram.  Produced by [`taxonomytreeplot`](@ref) (standalone figure) or
`taxonomytreeplot!` (existing axis).

## Attributes

| Attribute | Default | Description |
|---|---|---|
| `ladderize` | `false` | Sort children of each node by ascending subtree leaf count |
| `branch_color` | `:black` | Branch line colour (used when `color_by_rank = false`) |
| `branch_linewidth` | `1.5` | Branch line width in points |
| `show_nodes` | `true` | Draw a circular marker at every vertex |
| `show_unifurcation_nodes` | `true` | When `false`, suppress markers at single-child (unifurcation) nodes; branch segments are still drawn |
| `node_color` | `:black` | Node marker colour (used when `color_by_rank = false`) |
| `node_size` | `5` | Node marker size in points |
| `color_by_rank` | `false` | Colour branches and nodes by taxonomic rank |
| `rank_palette` | `nothing` | `Dict{String,Any}` mapping rank name → colour; `nothing` uses the built-in cycle |
| `showtips` | `true` | Show leaf taxon-name labels |
| `tip_fontsize` | `9` | Leaf label font size in points |
| `tip_color` | `:black` | Leaf label colour |
| `row_spacing` | `2.0` | Vertical gap between consecutive leaf rows in data units; `2.0` gives double-spaced positions, `1.0` uses unit spacing |
| `tip_xoffset` | `0.1` | Rightward offset for leaf labels in data units |
| `tip_yoffset` | `0.0` | Vertical offset for leaf labels in data units (positive = upward) |
| `showinternal` | `false` | Show internal node name labels |
| `internal_fontsize` | `7` | Internal label font size in points |
| `internal_color` | `:gray40` | Internal label colour |
| `show_phylopic` | `false` | Draw a PhyloPic silhouette to the right of each leaf tip label|
| `phylopic_glyph_size` | `1.0` | Half-height of each silhouette glyph in data units (total height = `2 × phylopic_glyph_size`) |
| `phylopic_align` | `false` | When `true`, all silhouettes are placed at a single right-hand column; when `false`, each appears immediately right of its label |
| `phylopic_xoffset` | `0.65` | Additional rightward gap in data units beyond the tip-label start position |
| `phylopic_yoffset` | `0.3` | Vertical offset for PhyloPic silhouettes in data units (positive = upward); applied independently of `tip_yoffset` |
| `phylopic_on_missing` | `:skip` | Policy when no PhyloPic image is found: `:skip` (omit), `:placeholder` (grey box), `:error` (throw) |
| `phylopic_aspect` | `:preserve` | `:preserve` maintains the original image aspect ratio; `:stretch` renders as a square |
| `phylopic_image_rendering` | `:thumbnail` | Image URL to fetch: `:thumbnail` (PNG thumbnail), `:raster` (PNG full-res), `:og_image` (PNG Open Graph), `:vector` (SVG — requires FileIO SVG plugin), `:source_file` (SVG or raster); see `PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS` |

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonomyTreeMakie

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Add to an existing Makie axis
fig = Figure(size = (900, 600))
ax  = Axis(fig[1, 1])
taxonomytreeplot!(ax, tree; showtips = true, color_by_rank = true)
set_rank_axis_ticks!(ax, tree)
display(fig)
```

See also [`taxonomytreeplot`](@ref), `taxonomytreeplot!`,
[`set_rank_axis_ticks!`](@ref).
"""
@recipe(TaxonomyTreePlot, taxonomytree) do scene
    Attributes(
        # Layout
        ladderize = false,
        row_spacing = 2.0,
        # Branches
        branch_color = :black,
        branch_linewidth = 1.5,
        # Nodes
        show_nodes = true,
        show_unifurcation_nodes = true,
        node_color = :black,
        node_size = 5,
        # Rank-based colouring
        color_by_rank = false,
        rank_palette = nothing,
        # Leaf labels
        showtips = true,
        tip_fontsize = 9,
        tip_color = :black,
        tip_xoffset = 0.1,
        tip_yoffset = 0.0,
        # Internal labels
        showinternal = false,
        internal_fontsize = 7,
        internal_color = :gray40,
        # PhyloPic silhouettes at leaf tips
        show_phylopic = false,
        phylopic_glyph_size = 1.0,
        phylopic_align = false,
        phylopic_xoffset = 0.65,
        phylopic_yoffset = 0.3,
        phylopic_on_missing = :skip,
        phylopic_aspect = :preserve,
        phylopic_image_rendering = :thumbnail,
    )
end

# ---------------------------------------------------------------------------
# plot! implementation
# ---------------------------------------------------------------------------

function Makie.plot!(p::TaxonomyTreePlot{<:Tuple{TaxonomyTree}})
    tree_obs = p[:taxonomytree]

    # ── Layout (reactive to tree and ladderize) ───────────────────────────
    layout_obs = Makie.lift(tree_obs, p[:ladderize], p[:row_spacing]) do tree, lad, rsp
        _compute_dendrogram_layout(tree; ladderize = lad, row_spacing = rsp)
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
        color = branch_colors_obs,
        linewidth = p[:branch_linewidth],
    )

    # ── Node markers ──────────────────────────────────────────────────────
    # Compute the set of vertices to render as markers.  When
    # show_unifurcation_nodes = false, single-child nodes are filtered out so
    # they appear as transparent pass-throughs rather than extra dots.
    node_vertices_obs = Makie.lift(tree_obs, p[:show_unifurcation_nodes]) do tree, show_uni
        g = tree.graph
        if show_uni
            collect(Graphs.vertices(g))
        else
            [v for v in Graphs.vertices(g) if length(Graphs.outneighbors(g, v)) != 1]
        end
    end

    node_pts_obs = Makie.lift(layout_obs, node_vertices_obs) do (xs, ys), verts
        [Makie.Point2f(xs[v], ys[v]) for v in verts]
    end

    node_colors_obs = Makie.lift(
        tree_obs, node_vertices_obs, p[:color_by_rank], p[:rank_palette], p[:node_color],
    ) do tree, verts, cbr, palette, nc
        cbr ? _node_colors_vec(tree, palette, nc, verts) :
            fill(Makie.RGBAf(Makie.to_color(nc)), length(verts))
    end

    Makie.scatter!(
        p, node_pts_obs;
        color = node_colors_obs,
        markersize = p[:node_size],
        visible = p[:show_nodes],
    )

    # ── Leaf labels ───────────────────────────────────────────────────────
    leaf_vertices_obs = Makie.lift(tree_obs) do tree
        g = tree.graph
        [v for v in Graphs.vertices(g) if isempty(Graphs.outneighbors(g, v))]
    end

    leaf_vertices = leaf_vertices_obs[]
    leaf_text_plots = Any[]
    sizehint!(leaf_text_plots, length(leaf_vertices))
    for v in leaf_vertices
        leaf_point = Makie.Point2f(
            layout_obs[][1][v] + p[:tip_xoffset][],
            layout_obs[][2][v] + p[:tip_yoffset][],
        )
        leaf_text_plot = Makie.text!(
            p,
            leaf_point;
            text = tree_obs[].taxa[v].name,
            fontsize = p[:tip_fontsize],
            color = p[:tip_color],
            align = (:left, :center),
            visible = p[:showtips],
            clip_planes = Makie.Plane3f[],
        )
        push!(leaf_text_plots, leaf_text_plot)
    end

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
        text = internal_names_obs,
        fontsize = p[:internal_fontsize],
        color = p[:internal_color],
        align = (:center, :bottom),
        visible = p[:showinternal],
        clip_planes = Makie.Plane3f[],
    )

    # ── PhyloPic tip silhouettes ──────────────────────────────────────────
    # Images are loaded once at plot-creation time (network results cached).
    # Toggling show_phylopic after creation changes visibility without
    # re-fetching.  Changing glyph_size, phylopic_align, the tree, or other
    # layout attributes requires recreating the plot.
    if p[:show_phylopic][]
        _render_tip_phylopic!(
            p,
            tree_obs[],
            layout_obs[]...;
            leaf_vertices = leaf_vertices,
            leaf_text_plots = leaf_text_plots,
            glyph_size = p[:phylopic_glyph_size][],
            do_align = p[:phylopic_align][],
            phylopic_xoffset = p[:phylopic_xoffset][],
            phylopic_yoffset = p[:phylopic_yoffset][],
            tip_xoffset = p[:tip_xoffset][],
            on_missing = p[:phylopic_on_missing][],
            aspect = p[:phylopic_aspect][],
            image_rendering = p[:phylopic_image_rendering][],
        )
    end

    return p
end

# ---------------------------------------------------------------------------
# Axis helper
# ---------------------------------------------------------------------------

"""
    set_rank_axis_ticks!(ax::Makie.Axis, tree::TaxonomyTree) -> Nothing

Configure the x-axis tick labels on `ax` to display rank names at their
dendrogram x-depth positions.

Only ranks that are present in `tree` and whose depth is known (i.e. present
in `_RANK_DEPTH`) are labelled.  Tick labels are rotated 45° to prevent
overlap.

Typically called immediately after `taxonomytreeplot!`:

```julia
p = taxonomytreeplot!(ax, tree; showtips = true)
set_rank_axis_ticks!(ax, tree)
```

[`taxonomytreeplot`](@ref) (standalone) calls this automatically when
`show_rank_ticks = true` (the default).

## Arguments

- `ax`: the `Makie.Axis` on which to set ticks.
- `tree`: the [`TaxonomyTree`](@ref) whose ranks determine the tick positions.
"""
function set_rank_axis_ticks!(ax::Makie.Axis, tree::TaxonomyTree)::Nothing
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
# Standalone wrapper: taxonomytreeplot
# ---------------------------------------------------------------------------

"""
    taxonomytreeplot(
        tree::TaxonomyTree;
        show_rank_ticks::Bool = true,
        figure_kwargs::NamedTuple = (;),
        axis_kwargs::NamedTuple = (;),
        kwargs...,
    ) -> Makie.FigureAxisPlot

Create a standalone Makie figure containing a dendrogram of `tree`.

Returns a `Makie.FigureAxisPlot` object containing the figure, axis, and plot:

```julia
fig, ax, plt = taxonomytreeplot(tree; showtips = true)
display(fig)
save("tree.png", fig)
```

## Arguments

- `tree`: the [`TaxonomyTree`](@ref) to visualise.
- `show_rank_ticks` (default `true`): when `true`, calls
  [`set_rank_axis_ticks!`](@ref) to label the x-axis with rank names.
- `figure_kwargs`: keyword arguments forwarded to `Makie.Figure(; ...)`.
- `axis_kwargs`: keyword arguments forwarded to `Makie.Axis(; ...)`.
- All remaining keyword arguments are forwarded to `TaxonomyTreePlot`
  attributes (see `taxonomytreeplot!`).

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy
using CairoMakie
using PaleobiologyDB.TaxonomyTreeMakie

tree = taxon_subtree("Carnivora"; leaf_rank = "family")

# Basic dendrogram with tip labels
fig, ax, plt = taxonomytreeplot(tree; showtips = true)
save("carnivora_families.png", fig)

# Coloured by rank, ladderized
fig2, ax2, plt2 = taxonomytreeplot(tree;
    color_by_rank = true,
    ladderize     = true,
    showtips      = true,
)

# Custom figure and axis sizes
fig3, ax3, plt3 = taxonomytreeplot(tree;
    figure_kwargs = (; size = (1200, 800)),
    axis_kwargs   = (; title = "Carnivora families", yreversed = false),
)
```

See also `taxonomytreeplot!`, `TaxonomyTreePlot`,
[`set_rank_axis_ticks!`](@ref).
"""
function taxonomytreeplot(
        tree::TaxonomyTree;
        show_rank_ticks::Bool = true,
        figure_kwargs::NamedTuple = (;),
        axis_kwargs::NamedTuple = (;),
        kwargs...,
    )::Makie.FigureAxisPlot
    # Auto-size the figure based on the number of leaves so that dense trees
    # are not cramped.  User-supplied figure_kwargs / axis_kwargs take
    # precedence via merge (last-writer wins in NamedTuple merge).
    g = tree.graph
    n_leaves = count(v -> isempty(Graphs.outneighbors(g, v)), Graphs.vertices(g))
    default_height = max(400, n_leaves * 18)

    effective_figure_kwargs = merge((; size = (900, default_height)), figure_kwargs)
    # Right margin: 30% for tip labels alone; 50% when PhyloPic silhouettes
    # are also requested (images extend further right than text).
    # clip_planes = Plane3f[] on text! and image! calls ensures glyphs that
    # extend beyond the axis edge are still shown.
    has_phylopic = Bool(get(kwargs, :show_phylopic, false))
    right_margin = has_phylopic ? 0.5f0 : 0.3f0
    effective_axis_kwargs = merge((; xautolimitmargin = (0.05f0, right_margin)), axis_kwargs)

    fig = Makie.Figure(; effective_figure_kwargs...)
    ax = Makie.Axis(fig[1, 1]; effective_axis_kwargs...)
    p = taxonomytreeplot!(ax, tree; kwargs...)
    show_rank_ticks && set_rank_axis_ticks!(ax, tree)
    return Makie.FigureAxisPlot(fig, ax, p)
end

# ---------------------------------------------------------------------------
# String dispatch: taxonomytreeplot(taxon_name; ...)
# ---------------------------------------------------------------------------

"""
    taxonomytreeplot(
        taxon_name::AbstractString;
        leaf_rank::Union{AbstractString, Nothing} = nothing,
        strict_leaf_rank::Bool = true,
        show_rank_ticks::Bool = true,
        figure_kwargs::NamedTuple = (;),
        axis_kwargs::NamedTuple = (;),
        kwargs...,
    ) -> Makie.FigureAxisPlot

Convenience method: look up `taxon_name` in the PBDB, build its subtree, and
render it as a dendrogram in a standalone figure.

Calls [`taxon_subtree`](@ref) with `leaf_rank` and `strict_leaf_rank`, then
delegates to [`taxonomytreeplot`](@ref).  All remaining keyword
arguments (recipe attributes such as `ladderize`, `showtips`, `row_spacing`,
`show_phylopic`, etc.) are forwarded unchanged.  See `TaxonomyTreePlot` for the
full attribute reference.

## Arguments

- `taxon_name`: PBDB taxon name (e.g. `"Carnivora"`, `"Canidae"`).
- `leaf_rank`: prune the subtree at this rank (e.g. `"family"`, `"genus"`).
  `nothing` (default) keeps all descendants.
- `strict_leaf_rank`: when `true` (default), only taxa whose rank exactly
  matches `leaf_rank` become leaves; pass `false` to also include shallower
  terminals.
- `show_rank_ticks`, `figure_kwargs`, `axis_kwargs`: forwarded to
  [`taxonomytreeplot`](@ref).

## Examples

```julia
using PaleobiologyDB, CairoMakie
using PaleobiologyDB.Taxonomy.TaxonomyTreeMakie

fig, ax, plt = taxonomytreeplot("Carnivora"; leaf_rank = "family")
save("carnivora.png", fig)

fig2, ax2, plt2 = taxonomytreeplot("Canidae"; leaf_rank = "genus", ladderize = true, row_spacing = 1.5)
```
"""
function taxonomytreeplot(
        taxon_name::AbstractString;
        leaf_rank::Union{AbstractString, Nothing} = nothing,
        strict_leaf_rank::Bool = true,
        show_rank_ticks::Bool = true,
        figure_kwargs::NamedTuple = (;),
        axis_kwargs::NamedTuple = (;),
        kwargs...,
    )::Makie.FigureAxisPlot
    tree = taxon_subtree(taxon_name; leaf_rank, strict_leaf_rank)
    return taxonomytreeplot(tree; show_rank_ticks, figure_kwargs, axis_kwargs, kwargs...)
end
