
# ---------------------------------------------------------------------------
# PhyloPicMakie — core rendering loop
#
# Provides the generic augment_phylopic! and augment_phylopic_ranges! entry
# points that render pre-resolved image matrices onto a Makie axis.
#
# Name resolution (taxon → URL → image matrix) lives in
# PaleobiologyDB.PhyloPicPBDB, which calls this function after
# resolving images so that no PaleobiologyDB dependency is required here.
#
# The scale correction applied here compensates for axis anisotropy: in a
# TaxonTree or stratigraphic-range plot the x and y axes typically span
# different numbers of data units per screen pixel.  Without correction,
# aspect = :preserve images appear stretched horizontally or vertically.
# The fix uses a reactive Observable derived from the axis camera and
# viewport, so the image x-range updates automatically when axis limits
# change or the figure is resized.
#
# Public:
#   augment_phylopic!(ax, xs, ys, images; ...)  → Nothing
#   augment_phylopic_ranges!(ax, xstarts, xstops, ys, images; ...) → Nothing
# ---------------------------------------------------------------------------

import Makie

"""
    augment_phylopic!(
        ax::Makie.Axis,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real},
        images::AbstractVector;
        glyph_size::Real,
        aspect::Symbol,
        placement::Symbol,
        xoffset::Real,
        yoffset::Real,
        rotation::Real,
        mirror::Bool,
        on_missing::Symbol,
    ) -> Nothing

Add one `image!` call per data point to `ax` using pre-resolved image matrices.

`images` is a `Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}` — `nothing`
entries are handled according to `on_missing`.

This is the generic rendering entry point.  Callers are responsible for
supplying pre-resolved images.  For PBDB taxon-name resolution, use
`PaleobiologyDB.PhyloPicPBDB.augment_phylopic!` instead.

For `aspect = :preserve`, the x-range of each image is a reactive
`Makie.Observable` that recomputes whenever the axis scale changes, so
rendered images maintain their correct pixel-space aspect ratio on
anisotropic axes.
"""
function augment_phylopic!(
    ax::Makie.Axis,
    xs::AbstractVector{<:Real},
    ys::AbstractVector{<:Real},
    images::AbstractVector;
    glyph_size::Real,
    aspect::Symbol,
    placement::Symbol,
    xoffset::Real,
    yoffset::Real,
    rotation::Real,
    mirror::Bool,
    on_missing::Symbol,
)::Nothing
    on_missing ∈ VALID_ON_MISSING || throw(ArgumentError(
        "augment_phylopic: unknown `on_missing` value `$on_missing`. " *
        "Valid values: $(join(VALID_ON_MISSING, ", "))."
    ))

    n = length(xs)
    n == length(ys) == length(images) || throw(ArgumentError(
        "augment_phylopic: xs, ys, and images must all have the same length."
    ))

    # Reactive scale correction: recomputes whenever the axis limits or
    # viewport change.  The x-range of :preserve images lifts on this
    # observable so they stay correctly proportioned after auto-limits or
    # window resize events.
    scale_corr_obs = _axis_scale_correction_obs(ax.scene)

    for i in 1:n
        img = images[i]

        if isnothing(img)
            if on_missing === :error
                throw(ErrorException(
                    "augment_phylopic: missing image for data point $i " *
                    "(on_missing = :error)."
                ))
            elseif on_missing === :placeholder
                # Draw a small grey rectangle as a stand-in.  The placeholder
                # is intentionally square (aspect = :stretch) regardless of
                # the caller's aspect setting.
                x_lo, x_hi, y_lo, y_hi = _compute_image_bbox(
                    xs[i], ys[i], 1, 1;
                    glyph_size = glyph_size,
                    aspect = :stretch,
                    placement = placement,
                    xoffset = xoffset,
                    yoffset = yoffset,
                )
                Makie.poly!(
                    ax,
                    Makie.Rect2f(x_lo, y_lo, x_hi - x_lo, y_hi - y_lo);
                    color = (:lightgray, 0.5),
                    strokecolor = :gray,
                    strokewidth = 0.5,
                )
            end
            # :skip falls through to the next iteration
            continue
        end

        # Apply rotation (multiples of 90° only in v1)
        rendered = _apply_rotation(img, rotation)

        # Apply mirror (horizontal flip)
        if mirror
            rendered = rendered[:, end:-1:1]
        end

        # After rotation the pixel dimensions may swap; query after rotation.
        h_px, w_px = size(rendered)

        # Static y-range: governed only by glyph_size and placement in y.
        # y does not depend on image aspect ratio or axis x/y scale.
        _, _, y_lo, y_hi = _compute_image_bbox(
            xs[i], ys[i], w_px, h_px;
            glyph_size = glyph_size,
            aspect = aspect,
            placement = placement,
            xoffset = xoffset,
            yoffset = yoffset,
            axis_scale_correction = 1.0,
        )
        y_range = (y_lo, y_hi)

        # x-range: for :preserve aspect, make reactive so images stay
        # correctly proportioned when axis limits or viewport change.
        x_range = if aspect === :preserve
            Makie.lift(scale_corr_obs) do sc
                x_lo, x_hi, _, _ = _compute_image_bbox(
                    xs[i], ys[i], w_px, h_px;
                    glyph_size = glyph_size,
                    aspect = :preserve,
                    placement = placement,
                    xoffset = xoffset,
                    yoffset = yoffset,
                    axis_scale_correction = sc,
                )
                (x_lo, x_hi)
            end
        else
            # :stretch — equal data-unit width and height; no anisotropy
            # correction applies.
            x_lo, x_hi, _, _ = _compute_image_bbox(
                xs[i], ys[i], w_px, h_px;
                glyph_size = glyph_size,
                aspect = :stretch,
                placement = placement,
                xoffset = xoffset,
                yoffset = yoffset,
            )
            (x_lo, x_hi)
        end

        # Makie.image! expects column-major order: apply rotr90 so image rows
        # become plot columns (standard Makie convention).
        Makie.image!(
            ax,
            x_range,
            y_range,
            rotr90(rendered);
            interpolate = true,
        )
    end
    return nothing
end

"""
    augment_phylopic_ranges!(
        ax::Makie.Axis,
        xstart::AbstractVector{<:Real},
        xstop::AbstractVector{<:Real},
        y::AbstractVector{<:Real},
        images::AbstractVector;
        at::Symbol = :midpoint,
        kwargs...,
    ) -> Nothing

Add one PhyloPic glyph per datum to `ax` using pre-resolved image matrices,
where each glyph is anchored relative to a range `(xstart[i], xstop[i])`.

Computes anchor x coordinates from the range endpoints via `_range_anchor` and
then calls [`augment_phylopic!`](@ref).

## Arguments

- `xstart`, `xstop`: range endpoints in axis data units.
- `y`: vertical coordinate for each datum.
- `images`: pre-resolved image matrices (`nothing` entries handled by
  `on_missing`).
- `at`: where along the range to anchor the glyph.  One of:
  - `:start` — anchor at `xstart[i]`.
  - `:stop` — anchor at `xstop[i]`.
  - `:midpoint` (default) — anchor at the midpoint.
- All remaining keyword arguments are forwarded to [`augment_phylopic!`](@ref).

## Returns

`Nothing`.
"""
function augment_phylopic_ranges!(
    ax::Makie.Axis,
    xstart::AbstractVector{<:Real},
    xstop::AbstractVector{<:Real},
    y::AbstractVector{<:Real},
    images::AbstractVector;
    at::Symbol = :midpoint,
    kwargs...,
)::Nothing
    n = length(y)
    length(xstart) == n || throw(ArgumentError(
        "augment_phylopic_ranges!: `xstart` and `y` must have the same length."
    ))
    length(xstop) == n || throw(ArgumentError(
        "augment_phylopic_ranges!: `xstop` and `y` must have the same length."
    ))
    xs = [_range_anchor(Float64(xstart[i]), Float64(xstop[i]), at) for i in 1:n]
    augment_phylopic!(ax, xs, y, images; kwargs...)
    return nothing
end
