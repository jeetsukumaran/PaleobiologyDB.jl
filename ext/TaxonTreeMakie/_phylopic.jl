
# ---------------------------------------------------------------------------
# TaxonTreeMakie — PhyloPic silhouette support for dendrogram leaf tips
#
# This file provides helpers for loading and rendering PhyloPic silhouette
# images at the tip positions of a TaxonTree dendrogram.
#
# Public (within extension):
#   _compute_tip_image_bbox(x, y, img_width, img_height; ...)
#       → NTuple{4, Float64}   (x_lo, x_hi, y_lo, y_hi)
#   _load_tip_phylopic_image(taxon_name) → Union{Matrix{Makie.RGBA{Makie.N0f8}}, Nothing}
#   _render_tip_phylopic!(p, tree, xs, ys; ...) → Nothing
#
# Image loading delegates to PaleobiologyDB.PhyloPicMakie when that extension
# is loaded (i.e. when FileIO is in the session).  If PhyloPicMakie is not
# yet loaded, _load_tip_phylopic_image returns nothing and a one-time warning
# is emitted; the on_missing policy at the call site then applies.
#
# The coordinate helper _compute_tip_image_bbox is a pure duplicate of
# PhyloPicMakie._compute_image_bbox — copied here to avoid cross-extension
# coupling.  Both implementations must be kept in sync.
# ---------------------------------------------------------------------------

using PaleobiologyDB.Taxonomy: acquire_phylopic

# ---------------------------------------------------------------------------
# Pure coordinate helpers
# ---------------------------------------------------------------------------

# Placement-anchor offsets: fraction of half-width/half-height to add to the
# centre so the requested edge/corner lands on the anchor point.
#
#   :left  → anchor is the left edge → shift centre rightward by +half_w
#   :right → anchor is the right edge → shift centre leftward by -half_w
#   (etc.)
#
# Returns (pfx, pfy) in half-dimension units.
function _tip_placement_offsets(placement::Symbol)::Tuple{Float64, Float64}
    placement === :center      && return (0.0,   0.0)
    placement === :left        && return (0.5,   0.0)
    placement === :right       && return (-0.5,  0.0)
    placement === :top         && return (0.0,  -0.5)
    placement === :bottom      && return (0.0,   0.5)
    placement === :topleft     && return (0.5,  -0.5)
    placement === :topright    && return (-0.5, -0.5)
    placement === :bottomleft  && return (0.5,   0.5)
    placement === :bottomright && return (-0.5,  0.5)
    throw(ArgumentError(
        "_render_tip_phylopic!: unknown placement `$placement`."
    ))
end

"""
    _compute_tip_image_bbox(
        x, y, img_width, img_height;
        glyph_size, aspect, placement, xoffset, yoffset,
    ) -> NTuple{4, Float64}

Compute the axis data-space bounding box `(x_lo, x_hi, y_lo, y_hi)` for a
PhyloPic glyph image centred (or anchored by `placement`) at `(x, y)`.

This is a local pure duplicate of `PhyloPicMakie._compute_image_bbox`,
intentionally kept here to avoid cross-extension coupling.  Both must be
kept in sync.

## Arguments

- `x`, `y`: anchor coordinates in axis data space.
- `img_width`, `img_height`: pixel dimensions of the source image (used only
  when `aspect = :preserve`).
- `glyph_size`: half-height of the rendered glyph in data units.
- `aspect`: `:preserve` maintains the image's aspect ratio; `:stretch`
  renders as a square.
- `placement`: anchor position on the glyph.  `:left` places the left edge
  of the glyph at `(x + xoffset, y + yoffset)`.
- `xoffset`, `yoffset`: additional offset in data units applied after
  anchoring.

## Returns

`(x_lo, x_hi, y_lo, y_hi)` — the bounding rectangle in data space.
"""
function _compute_tip_image_bbox(
    x::Real,
    y::Real,
    img_width::Integer,
    img_height::Integer;
    glyph_size::Real,
    aspect::Symbol,
    placement::Symbol,
    xoffset::Real,
    yoffset::Real,
)::NTuple{4, Float64}
    half_h = Float64(glyph_size)

    half_w = if aspect === :preserve
        img_height == 0 ? half_h : half_h * (Float64(img_width) / Float64(img_height))
    elseif aspect === :stretch
        half_h
    else
        throw(ArgumentError(
            "_render_tip_phylopic!: unknown aspect `$aspect`. " *
            "Valid values: :preserve, :stretch."
        ))
    end

    cx = Float64(x) + Float64(xoffset)
    cy = Float64(y) + Float64(yoffset)

    (pfx, pfy) = _tip_placement_offsets(placement)
    cx += pfx * 2 * half_w
    cy += pfy * 2 * half_h

    return (cx - half_w, cx + half_w, cy - half_h, cy + half_h)
end

# ---------------------------------------------------------------------------
# Image loading
# ---------------------------------------------------------------------------

# Guard flag: emit the "PhyloPicMakie not loaded" warning at most once per
# session so repeated calls don't flood the console.
const _PHYLOPIC_MISSING_WARNED = Ref(false)

"""
    _load_tip_phylopic_image(
        taxon_name::AbstractString,
    ) -> Union{Matrix{Makie.RGBA{Makie.N0f8}}, Nothing}

Look up and download the PhyloPic thumbnail for `taxon_name`.

Delegates to `PaleobiologyDB.PhyloPicMakie` for URL resolution and image
decoding (which requires `FileIO` to be loaded in the session).  When
`PhyloPicMakie` is not yet available, emits a one-time warning and returns
`nothing`.

Both the PhyloPic metadata lookup (taxon → URL) and the image download are
cached via `DataCaches.jl`; repeated calls for the same taxon name within a
session are instant.

## Returns

A `Matrix{RGBA{N0f8}}` in Julia column-major layout, or `nothing` when the
image could not be resolved or loaded.  Callers should apply `rotr90` before
passing to `Makie.image!`.
"""
function _load_tip_phylopic_image(
    taxon_name::AbstractString,
)::Union{Matrix{Makie.RGBA{Makie.N0f8}}, Nothing}
    if !isdefined(PaleobiologyDB, :PhyloPicMakie)
        if !_PHYLOPIC_MISSING_WARNED[]
            _PHYLOPIC_MISSING_WARNED[] = true
            @warn "TaxonTreeMakie: PhyloPic silhouettes require FileIO.jl. " *
                  "Load it with `using FileIO` to enable image rendering."
        end
        return nothing
    end

    rec = try
        acquire_phylopic(string(taxon_name))
    catch err
        @warn "TaxonTreeMakie: PhyloPic lookup failed for \"$taxon_name\"" exception = err
        return nothing
    end

    url = get(rec, :phylopic_thumbnail, missing)
    if ismissing(url) || isempty(string(url))
        return nothing
    end

    try
        return PaleobiologyDB.PhyloPicMakie._load_phylopic_image(string(url))
    catch err
        @warn "TaxonTreeMakie: image load failed for \"$taxon_name\"" exception = err
        return nothing
    end
end

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

"""
    _render_tip_phylopic!(
        p,
        tree::TaxonTree,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real};
        glyph_size::Real,
        do_align::Bool,
        phylopic_xoffset::Real,
        tip_xoffset::Real,
        on_missing::Symbol,
        aspect::Symbol,
    ) -> Nothing

Add one `Makie.image!` (or `Makie.poly!` placeholder) per leaf tip to the
compound plot `p`.

This function is called **once** during `Makie.plot!` when `show_phylopic`
is true.  Images are static after creation; toggling `p[:show_phylopic][]`
changes their visibility without re-fetching.

## Arguments

- `p`: the `TaxonTreePlot` compound plot to add child plots to.
- `tree`: the `TaxonTree` being rendered.
- `xs`, `ys`: dendrogram layout coordinates, one per vertex (from
  `_compute_dendrogram_layout`).
- `glyph_size`: half-height of each rendered silhouette in data units.
- `do_align`: when `true`, all images are placed at the same x position
  (`max(leaf x) + tip_xoffset + phylopic_xoffset`); when `false`, each image
  is placed at `xs[leaf] + tip_xoffset + phylopic_xoffset`.
- `phylopic_xoffset`: additional rightward gap in data units beyond the
  tip-label start x.
- `tip_xoffset`: the recipe's `tip_xoffset` attribute (where text labels
  start, in data units).
- `on_missing`: policy when no image is available.
  - `:skip` — silently omit the glyph.
  - `:placeholder` — draw a translucent grey rectangle.
  - `:error` — throw an `ErrorException`.
- `aspect`: `:preserve` maintains aspect ratio; `:stretch` renders square.

## Returns

`Nothing`.  Child plots are added as side effects to `p`.
"""
function _render_tip_phylopic!(
    p,
    tree::TaxonTree,
    xs::AbstractVector{<:Real},
    ys::AbstractVector{<:Real};
    glyph_size::Real,
    do_align::Bool,
    phylopic_xoffset::Real,
    tip_xoffset::Real,
    on_missing::Symbol,
    aspect::Symbol,
)::Nothing
    on_missing ∈ (:skip, :placeholder, :error) || throw(ArgumentError(
        "_render_tip_phylopic!: unknown `on_missing` value `$on_missing`. " *
        "Valid values: :skip, :placeholder, :error."
    ))

    g = tree.graph
    leaf_vertices = [v for v in Graphs.vertices(g) if isempty(Graphs.outneighbors(g, v))]
    isempty(leaf_vertices) && return nothing

    # Aligned mode: all images share a single x column
    x_align = maximum(Float64(xs[v]) for v in leaf_vertices) + Float64(tip_xoffset) +
               Float64(phylopic_xoffset)

    for v in leaf_vertices
        taxon_name = tree.taxa[v].name
        img = _load_tip_phylopic_image(taxon_name)

        # x anchor: either per-leaf or uniform column
        x_anchor = do_align ? x_align : Float64(xs[v]) + Float64(tip_xoffset) +
                                         Float64(phylopic_xoffset)
        y_anchor = Float64(ys[v])

        if isnothing(img)
            if on_missing === :error
                throw(ErrorException(
                    "_render_tip_phylopic!: no PhyloPic image available for " *
                    "\"$taxon_name\" (on_missing = :error)."
                ))
            elseif on_missing === :placeholder
                # Draw a grey rectangle as a stand-in glyph.
                x_lo = x_anchor
                x_hi = x_anchor + 2 * Float64(glyph_size)
                y_lo = y_anchor - Float64(glyph_size)
                y_hi = y_anchor + Float64(glyph_size)
                Makie.poly!(
                    p,
                    Makie.Rect2f(x_lo, y_lo, x_hi - x_lo, y_hi - y_lo);
                    color       = (:lightgray, 0.5),
                    strokecolor = :gray,
                    strokewidth = 0.5,
                    visible     = p[:show_phylopic],
                    clip_planes = Makie.Plane3f[],
                )
            end
            # :skip → nothing
            continue
        end

        # img from _load_tip_phylopic_image is column-major (height × width).
        # Pass width and height in the order _compute_tip_image_bbox expects.
        h_px, w_px = size(img)
        x_lo, x_hi, y_lo, y_hi = _compute_tip_image_bbox(
            x_anchor, y_anchor, w_px, h_px;
            glyph_size = glyph_size,
            aspect     = aspect,
            placement  = :left,
            xoffset    = 0.0,
            yoffset    = 0.0,
        )

        # Makie.image! expects row-major data; rotr90 converts Julia column-major.
        Makie.image!(
            p,
            (x_lo, x_hi),
            (y_lo, y_hi),
            rotr90(img);
            interpolate = true,
            visible     = p[:show_phylopic],
            clip_planes = Makie.Plane3f[],
        )
    end

    return nothing
end
