
# ---------------------------------------------------------------------------
# TaxonTreeMakie — tree-aware PhyloPic overlay API
#
# Provides a composable overlay API that separates tree geometry extraction
# from glyph rendering.  All rendering is delegated to
# PaleobiologyDB.PhyloPicPBDB.augment_phylopic! so that placement math,
# reactive axis-scale correction, and image caching are handled in one place.
#
# Public:
#   tip_positions(p::TaxonTreePlot) → NamedTuple
#   augment_tip_phylopic!(ax, tree, xs, ys; ...) → Nothing
#   augment_tip_phylopic!(ax, p::TaxonTreePlot; ...) → Nothing
# ---------------------------------------------------------------------------

"""
Valid `anchor` symbols for `augment_tip_phylopic!`.
"""
const VALID_TIP_ANCHORS = (:tip, :tip_label_origin)

# ---------------------------------------------------------------------------
# tip_positions — TaxonTreePlot convenience overload
# ---------------------------------------------------------------------------

"""
    tip_positions(p::TaxonTreePlot) -> NamedTuple

Extract leaf-tip coordinates from a `TaxonTreePlot` object.

Convenience overload of [`tip_positions`](@ref) that reads the
tree and `ladderize` attribute from `p` and recomputes the dendrogram layout.

Returns a `NamedTuple` with fields:
- `vertices::Vector{Int}` — leaf vertex indices into `p[:taxontree][].graph`
- `names::Vector{String}` — accepted taxon name for each leaf
- `x::Vector{Float64}` — x coordinate in data units for each leaf
- `y::Vector{Float64}` — y coordinate in data units for each leaf

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy, CairoMakie
using PaleobiologyDB.TaxonTreeMakie

fig, ax, p = taxontreeplot(taxon_subtree("Panthera"))
tips = tip_positions(p)
# tips.names  — Vector{String} of leaf taxon names
# tips.x      — x positions in data space
# tips.y      — y positions in data space
```

See also [`tip_positions`](@ref), [`augment_tip_phylopic!`](@ref).
"""
function tip_positions(p::TaxonTreePlot)::NamedTuple
    tree   = p[:taxontree][]
    xs, ys = _compute_dendrogram_layout(tree; ladderize = p[:ladderize][])
    return tip_positions(tree, xs, ys)
end

# ---------------------------------------------------------------------------
# augment_tip_phylopic! — primary method (tree + layout vectors)
# ---------------------------------------------------------------------------

"""
    augment_tip_phylopic!(
        ax::Makie.Axis,
        tree::TaxonTree,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real};
        anchor::Symbol                 = :tip,
        align::Bool                    = false,
        column_x::Union{Nothing, Real} = nothing,
        tip_xoffset::Real              = 0.0,
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

Add one PhyloPic silhouette per leaf tip of `tree` to `ax`.

This is the primary tree-aware overlay API.  It computes anchor positions
from the dendrogram layout and delegates all rendering to
[`PaleobiologyDB.PhyloPicPBDB.augment_phylopic!`](@ref).

See also the convenience overload [`augment_tip_phylopic!`](@ref)
which reads tree and layout directly from a `TaxonTreePlot`.

## Arguments

- `ax`: the `Makie.Axis` to annotate.
- `tree`: source [`TaxonTree`](@ref).
- `xs`, `ys`: layout vectors from `_compute_dendrogram_layout`, one
  value per vertex in `tree.graph`.

## Keyword arguments

### Anchor selection

- `anchor` (default `:tip`) — how to compute the x-anchor for each leaf:
  - `:tip` — the leaf node's x coordinate `xs[v]`
  - `:tip_label_origin` — `xs[v] + tip_xoffset`
- `tip_xoffset` (default `0.0`) — label-start offset used when
  `anchor = :tip_label_origin`.  Set to match the `tip_xoffset` attribute of
  the corresponding `TaxonTreePlot` (recipe default `0.2`).

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
  found: `:skip` (omit silently), `:placeholder` (grey rectangle), `:error`
  (throw).

## Returns

`Nothing`.  Silhouettes are added as side-effects to `ax`.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.Taxonomy, CairoMakie
using PaleobiologyDB.TaxonTreeMakie

tree = taxon_subtree("Panthera")
fig, ax, p = taxontreeplot(tree)

# Silhouettes 1.0 data unit right of each leaf tip
augment_tip_phylopic!(ax, p; xoffset = 1.0)

# Anchor at tip-label origin so silhouettes appear after the text
augment_tip_phylopic!(ax, p;
    anchor      = :tip_label_origin,
    tip_xoffset = 0.2,   # match recipe tip_xoffset attribute
    xoffset     = 0.5,
)

# Aligned column
augment_tip_phylopic!(ax, p; align = true, xoffset = 0.2)
```

See also [`tip_positions`](@ref), [`taxontreeplot`](@ref).
"""
function augment_tip_phylopic!(
    ax::Makie.Axis,
    tree::TaxonTree,
    xs::AbstractVector{<:Real},
    ys::AbstractVector{<:Real};
    anchor::Symbol                  = :tip,
    align::Bool                     = false,
    column_x::Union{Nothing, Real}  = nothing,
    tip_xoffset::Real               = 0.0,
    placement::Symbol               = :left,
    xoffset::Real                   = 0.0,
    yoffset::Real                   = 0.0,
    glyph_size::Real                = 0.4,
    aspect::Symbol                  = :preserve,
    rotation::Real                  = 0.0,
    mirror::Bool                    = false,
    image_rendering::Symbol         = :thumbnail,
    on_missing::Symbol              = :skip,
)::Nothing
    anchor ∈ VALID_TIP_ANCHORS || throw(ArgumentError(
        "augment_tip_phylopic!: unknown `anchor` value `:$anchor`. " *
        "Valid values: $(join(string.(':', VALID_TIP_ANCHORS), ", "))."
    ))

    tips = tip_positions(tree, xs, ys)
    isempty(tips.vertices) && return nothing

    x_anchors = Float64[
        anchor === :tip ? Float64(xs[v]) : Float64(xs[v]) + Float64(tip_xoffset)
        for v in tips.vertices
    ]

    if align
        xcol = isnothing(column_x) ? maximum(x_anchors) : Float64(column_x)
        fill!(x_anchors, xcol)
    end

    PaleobiologyDB.PhyloPicPBDB.augment_phylopic!(
        ax, x_anchors, tips.y;
        taxon           = tips.names,
        placement       = placement,
        xoffset         = xoffset,
        yoffset         = yoffset,
        glyph_size      = glyph_size,
        aspect          = aspect,
        rotation        = rotation,
        mirror          = mirror,
        image_rendering = image_rendering,
        on_missing      = on_missing,
    )
    return nothing
end

# ---------------------------------------------------------------------------
# augment_tip_phylopic! — convenience overload (TaxonTreePlot)
# ---------------------------------------------------------------------------

"""
    augment_tip_phylopic!(ax::Makie.Axis, p::TaxonTreePlot; kwargs...) -> Nothing

Convenience overload of [`augment_tip_phylopic!`](@ref) that reads tree and
layout from a `TaxonTreePlot`.

All keyword arguments are forwarded unchanged to the primary method.  See
[`augment_tip_phylopic!`](@ref) for full documentation.

## Examples

```julia
fig, ax, p = taxontreeplot(taxon_subtree("Panthera"))
augment_tip_phylopic!(ax, p; xoffset = 1.0)
```
"""
function augment_tip_phylopic!(
    ax::Makie.Axis,
    p::TaxonTreePlot;
    kwargs...,
)::Nothing
    tree   = p[:taxontree][]
    xs, ys = _compute_dendrogram_layout(tree; ladderize = p[:ladderize][])
    augment_tip_phylopic!(ax, tree, xs, ys; kwargs...)
    return nothing
end
