
# ---------------------------------------------------------------------------
# PhyloPicDB.PhyloPicMakie — core rendering loop
#
# Provides _augment_phylopic_core!, the inner loop that maps a vector of
# pre-resolved image matrices onto Makie.image! calls on an axis.
#
# Name resolution (taxon → URL → image matrix) lives in
# PaleobiologyDB.PhyloPicPBDB, which calls this function after resolving
# images so that no PaleobiologyDB dependency is required here.
#
# The scale correction applied here compensates for axis anisotropy: in a
# TaxonTree or stratigraphic-range plot the x and y axes typically span
# different numbers of data units per screen pixel.  Without correction,
# aspect = :preserve images appear stretched horizontally or vertically.
# The fix uses a reactive Observable derived from the axis camera and
# viewport, so the image x-range updates automatically when axis limits
# change or the figure is resized.
#
# Public (within extension):
#   _augment_phylopic_core!(ax, xs, ys, images; ...) → Nothing
# ---------------------------------------------------------------------------

import Makie

"""
    _augment_phylopic_core!(
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

Add one `image!` call per data point to `ax`.

`images` is a `Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}` — `nothing`
entries are handled according to `on_missing`.

For `aspect = :preserve`, the x-range of each image is a reactive
`Makie.Observable` that recomputes whenever the axis scale changes, so
rendered images maintain their correct pixel-space aspect ratio on
anisotropic axes.
"""
function _augment_phylopic_core!(
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
