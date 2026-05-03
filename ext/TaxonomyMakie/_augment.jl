# ---------------------------------------------------------------------------
# TaxonomyMakie — tree-aware PhyloPic overlay API
#
# Provides a composable overlay API that separates tree geometry extraction
# from glyph rendering. Tree-specific planning stays in TaxonomyMakie;
# glyph rendering is delegated through the PBDB bridge into the shared
# PhyloPicMakie anchored-overlay substrate.
#
# Public:
#   leaf_positions(p::TaxonomyTreePlot) → NamedTuple
#   augment_leaf_phylopic!(ax, tree, xs, ys; ...) → Nothing
#   augment_leaf_phylopic!(ax, p::TaxonomyTreePlot; ...) → Nothing
# ---------------------------------------------------------------------------

"""
Valid `anchor` symbols for `augment_leaf_phylopic!`.
"""
const VALID_LEAF_ANCHORS = VALID_LEAF_OVERLAY_ANCHORS

# ---------------------------------------------------------------------------
# leaf_positions — TaxonomyTreePlot convenience overload
# ---------------------------------------------------------------------------

"""
    leaf_positions(p::TaxonomyTreePlot) -> NamedTuple

Extract leaf-node coordinates from a `TaxonomyTreePlot` object.

Convenience overload of [`leaf_positions`](@ref) that reads the
tree, `ladderize`, and `row_spacing` attributes from `p` and recomputes the
dendrogram layout.

Returns a `NamedTuple` with fields:
- `vertices::Vector{Int}` — leaf vertex indices into `p[:taxonomytree][].graph`
- `names::Vector{String}` — accepted taxon name for each leaf
- `x::Vector{Float64}` — x coordinate in data units for each leaf
- `y::Vector{Float64}` — y coordinate in data units for each leaf

## Examples

```julia
using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.TaxonomyMakie

fig, ax, plt = taxonomytreeplot(taxon_subtree("Panthera"))
leaves = leaf_positions(plt)
# leaves.names  — Vector{String} of leaf taxon names
# leaves.x      — x positions in data space
# leaves.y      — y positions in data space
```

See also [`leaf_positions`](@ref), [`augment_leaf_phylopic!`](@ref).
"""
function leaf_positions(p::TaxonomyTreePlot)::NamedTuple
    tree = p[:taxonomytree][]
    xs, ys = _compute_dendrogram_layout(
        tree;
        ladderize = p[:ladderize][],
        row_spacing = p[:row_spacing][],
    )
    return leaf_positions(tree, xs, ys)
end

# ---------------------------------------------------------------------------
# augment_leaf_phylopic! — primary method (tree + layout vectors)
# ---------------------------------------------------------------------------

"""
    augment_leaf_phylopic!(
        ax::Makie.Axis,
        tree::TaxonomyTree,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real};
        anchor::Symbol                 = :leaf,
        align::Bool                    = false,
        column_x::Union{Nothing, Real} = nothing,
        leaf_label_xoffset::Real       = 0.0,
        placement::Symbol              = :left,
        xoffset::Real                  = 0.0,
        yoffset::Real                  = 0.0,
        glyph_size::Real               = 0.4,
        aspect::Symbol                 = :preserve,
        rotation::Real                 = 0.0,
        mirror::Bool                   = false,
        image_rendering::Symbol        = :thumbnail,
        on_missing::Symbol             = :skip,
    ) -> Nothing

Add one PhyloPic silhouette per leaf of `tree` to `ax`.

This is the primary tree-aware overlay API.  It computes anchor positions
from the dendrogram layout and delegates all rendering to
[`augment_phylopic!`](@ref).

See also the convenience overload [`augment_leaf_phylopic!`](@ref)
which reads tree and layout directly from a `TaxonomyTreePlot`.

## Arguments

- `ax`: the `Makie.Axis` to annotate.
- `tree`: source [`TaxonomyTree`](@ref).
- `xs`, `ys`: layout vectors from `_compute_dendrogram_layout`, one
  value per vertex in `tree.graph`.

## Keyword arguments

### Anchor selection

- `anchor` (default `:leaf`) — how to compute the x-anchor for each leaf:
  - `:leaf` — the leaf node's x coordinate `xs[v]`
  - `:leaf_label_origin` — `xs[v] + leaf_label_xoffset`
- `leaf_label_xoffset` (default `0.0`) — label-start offset used when
  `anchor = :leaf_label_origin`.  Set to match the `leaf_label_xoffset` attribute of
  the corresponding `TaxonomyTreePlot` (recipe default `0.1`).

### Alignment

- `align` (default `false`) — when `true`, all silhouettes share a single
  x-column.  The column x equals `maximum(anchors)` unless `column_x` is set.
- `column_x` (default `nothing`) — explicit x position for the alignment
  column; ignored when `align = false`.

### Rendering (forwarded to `augment_phylopic!`)

- `placement` (default `:left`) — anchor position on the glyph relative to
  the data coordinate.  One of `:center`, `:left`, `:right`, `:top`,
  `:bottom`, `:topleft`, `:topright`, `:bottomleft`, `:bottomright`.
- `xoffset` (default `0.0`) — additional rightward shift in data units applied
  after anchoring.  This is the parameter to tune when the silhouettes
  overlap the text labels.
- `yoffset` (default `0.0`) — additional vertical shift in data units.
- `glyph_size` (default `0.4`) — half-height of each silhouette in data units
  (total height = `2 × glyph_size`).
- `aspect` (default `:preserve`) — `:preserve` maintains the original image
  aspect ratio; `:stretch` renders as a square.
- `rotation` (default `0.0`) — clockwise rotation in degrees (multiples of
  90° only).
- `mirror` (default `false`) — flip the silhouette horizontally.
- `image_rendering` (default `:thumbnail`) — PhyloPic image variant to fetch.
- `on_missing` (default `:skip`) — behaviour when no PhyloPic image is
  found: `:skip` (omit silently), `:placeholder` (placeholder glyph image),
  `:error` (throw).

## Returns

`Nothing`.  Silhouettes are added as side-effects to `ax`.

## Examples

```julia
using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.Taxonomy
using PaleobiologyDB.TaxonomyMakie

tree = taxon_subtree("Panthera")
fig, ax, plt = taxonomytreeplot(tree)

# Silhouettes 1.0 data unit right of each leaf
augment_leaf_phylopic!(ax, plt; xoffset = 1.0)

# Anchor at leaf-label origin so silhouettes appear after the text
augment_leaf_phylopic!(ax, plt;
    anchor             = :leaf_label_origin,
    leaf_label_xoffset = 0.1,   # match recipe leaf_label_xoffset attribute
    xoffset            = 0.5,
)

# Aligned column
augment_leaf_phylopic!(ax, plt; align = true, xoffset = 0.2)
```

See also [`leaf_positions`](@ref), [`taxonomytreeplot`](@ref).
"""
function augment_leaf_phylopic!(
        ax::Makie.Axis,
        tree::TaxonomyTree,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real};
        anchor::Symbol = :leaf,
        align::Bool = false,
        column_x::Union{Nothing, Real} = nothing,
        leaf_label_xoffset::Real = 0.0,
        placement::Symbol = :left,
        xoffset::Real = 0.0,
        yoffset::Real = 0.0,
        glyph_size::Real = 0.4,
        aspect::Symbol = :preserve,
        rotation::Real = 0.0,
        mirror::Bool = false,
        image_rendering::Symbol = :thumbnail,
        on_missing::Symbol = :skip,
    )::Nothing
    plan = _plan_leaf_node_phylopic_overlay(
        tree,
        xs,
        ys;
        anchor = anchor,
        align = align,
        column_x = column_x,
        leaf_label_xoffset = leaf_label_xoffset,
    )
    isempty(plan.leaf_vertices) && return nothing

    _augment_leaf_phylopic!(
        ax,
        plan;
        placement = placement,
        xoffset = xoffset,
        yoffset = yoffset,
        glyph_size = glyph_size,
        aspect = aspect,
        rotation = rotation,
        mirror = mirror,
        image_rendering = image_rendering,
        on_missing = on_missing,
    )
    return nothing
end

# ---------------------------------------------------------------------------
# augment_leaf_phylopic! — convenience overload (TaxonomyTreePlot)
# ---------------------------------------------------------------------------

"""
    augment_leaf_phylopic!(ax::Makie.Axis, p::TaxonomyTreePlot; kwargs...) -> Nothing

Convenience overload of [`augment_leaf_phylopic!`](@ref) that reads tree and
layout from a `TaxonomyTreePlot`. When `anchor = :leaf_label_origin` and no
fixed `column_x` override is requested, this overload reuses the plotted leaf
labels so the explicit two-step overlay follows the same label-aware placement
contract as `show_phylopic = true`.

All keyword arguments are forwarded unchanged to the primary method.  See
[`augment_leaf_phylopic!`](@ref) for full documentation.

## Examples

```julia
fig, ax, plt = taxonomytreeplot(taxon_subtree("Panthera"))
augment_leaf_phylopic!(ax, plt; xoffset = 1.0)
```
"""
function augment_leaf_phylopic!(
        _ax::Makie.Axis,
        p::TaxonomyTreePlot;
        anchor::Symbol = :leaf,
        align::Bool = false,
        column_x::Union{Nothing, Real} = nothing,
        leaf_label_xoffset::Real = p[:leaf_label_xoffset][],
        placement::Symbol = :left,
        xoffset::Real = 0.0,
        yoffset::Real = 0.0,
        glyph_size::Real = 0.4,
        aspect::Symbol = :preserve,
        rotation::Real = 0.0,
        mirror::Bool = false,
        image_rendering::Symbol = :thumbnail,
        on_missing::Symbol = :skip,
    )::Nothing
    planning = _plan_leaf_plot_phylopic_overlay(
        p;
        anchor = anchor,
        align = align,
        column_x = column_x,
        leaf_label_xoffset = leaf_label_xoffset,
        xoffset = xoffset,
        yoffset = yoffset,
    )
    isempty(planning.plan.leaf_vertices) && return nothing

    _augment_leaf_phylopic!(
        p,
        planning.plan;
        placement = placement,
        xoffset = planning.render_xoffset,
        yoffset = planning.render_yoffset,
        glyph_size = glyph_size,
        aspect = aspect,
        rotation = rotation,
        mirror = mirror,
        image_rendering = image_rendering,
        on_missing = on_missing,
    )
    return nothing
end
