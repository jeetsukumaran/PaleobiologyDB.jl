
# ---------------------------------------------------------------------------
# PhyloPicMakie — pure coordinate and placement calculations
#
# All functions here are pure: they depend only on their arguments and
# produce no side effects.  They can be tested without loading Makie.
#
# Public (within extension):
#   _compute_image_bbox(x, y, img_width, img_height; ...)
#       → NTuple{4, Float64}  (x_lo, x_hi, y_lo, y_hi)
#   _apply_rotation(img, rotation_deg) → AbstractMatrix
#   _range_anchor(xstart, xstop, at) → Float64
# ---------------------------------------------------------------------------

"""
Valid placement symbols for the anchor corner/edge on the glyph.
"""
const VALID_PLACEMENTS = (
    :center,
    :left,
    :right,
    :top,
    :bottom,
    :topleft,
    :topright,
    :bottomleft,
    :bottomright,
)

"""
Valid `at` symbols for range-based placement.
"""
const VALID_AT_POSITIONS = (:start, :stop, :midpoint)

"""
Valid `on_missing` symbols.
"""
const VALID_ON_MISSING = (:skip, :error, :placeholder)

"""
Valid rotation multiples (degrees, multiples of 90).
"""
const VALID_ROTATIONS_DEG = (0.0, 90.0, 180.0, 270.0, -90.0, -180.0, -270.0)

# ---------------------------------------------------------------------------
# Internal: anchor offset fraction for each placement symbol
# ---------------------------------------------------------------------------

#  Returns (fx, fy) ∈ [0,1]² — the fraction of image width/height to
#  subtract from the centre to reach the requested anchor point, expressed
#  in image-half units.
#
#  :center     → (0.0, 0.0) — anchor is the centre itself
#  :left       → (+0.5, 0.0) — anchor is the left edge centre
#  :right      → (-0.5, 0.0) — anchor is the right edge centre
#  :top        → (0.0, -0.5) — anchor is the top edge centre
#  :bottom     → (0.0, +0.5) — anchor is the bottom edge centre
#  :topleft    → (+0.5, -0.5)
#  :topright   → (-0.5, -0.5)
#  :bottomleft → (+0.5, +0.5)
#  :bottomright→ (-0.5, +0.5)
#
function _placement_offsets(placement::Symbol)::Tuple{Float64, Float64}
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
        "augment_phylopic: unknown placement `$placement`. " *
        "Valid values: $(join(VALID_PLACEMENTS, ", "))."
    ))
end

# ---------------------------------------------------------------------------
# Public: bounding box
# ---------------------------------------------------------------------------

"""
    _compute_image_bbox(
        x, y, img_width, img_height;
        glyph_size, aspect, placement, xoffset, yoffset
    ) -> NTuple{4, Float64}

Compute the axis data-space bounding box `(x_lo, x_hi, y_lo, y_hi)` for a
glyph image centred (or anchored by `placement`) at `(x, y)`.

All coordinates are in **data space**.  The caller is responsible for any
pixel-to-data conversion before calling this function.

## Arguments

- `x`, `y`: anchor coordinates in axis data space.
- `img_width`, `img_height`: pixel dimensions of the source image (used only
  when `aspect = :preserve`).
- `glyph_size`: half-height of the rendered glyph in data units.  The total
  height is `2 * glyph_size`.
- `aspect`: `:preserve` maintains the image's aspect ratio; `:stretch`
  renders as a square with side `2 * glyph_size`.
- `placement`: anchor position on the glyph (see `VALID_PLACEMENTS`).
- `xoffset`, `yoffset`: additional offset in data units applied after
  anchoring.

## Returns

`(x_lo, x_hi, y_lo, y_hi)` — the bounding rectangle in data space.

## Examples

```julia
using PaleobiologyDB.PhyloPicMakie

# 40×20 image, glyph_size = 0.4, placement = :center
bbox = PaleobiologyDB.PhyloPicMakie._compute_image_bbox(
    5.0, 3.0, 40, 20;
    glyph_size = 0.4, aspect = :preserve,
    placement = :center, xoffset = 0.0, yoffset = 0.0,
)
# bbox ≈ (5.0 - 0.8, 5.0 + 0.8, 3.0 - 0.4, 3.0 + 0.4)
```
"""
function _compute_image_bbox(
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
            "augment_phylopic: unknown aspect `$aspect`. " *
            "Valid values: :preserve, :stretch."
        ))
    end

    # Base bounding box centred at origin, then shift to (x, y)
    cx = Float64(x) + Float64(xoffset)
    cy = Float64(y) + Float64(yoffset)

    # Adjust for placement: shift the box so the anchor point lands on (cx, cy)
    (pfx, pfy) = _placement_offsets(placement)
    cx += pfx * 2 * half_w
    cy += pfy * 2 * half_h

    return (cx - half_w, cx + half_w, cy - half_h, cy + half_h)
end

# ---------------------------------------------------------------------------
# Public: rotation
# ---------------------------------------------------------------------------

"""
    _apply_rotation(img::AbstractMatrix, rotation_deg::Real) -> AbstractMatrix

Rotate `img` by `rotation_deg` degrees (must be a multiple of 90°).

Supported values: `0`, `90`, `180`, `270`, `-90`, `-180`, `-270`.

Returns the rotated image.  The original matrix is not modified.

## Arguments

- `img`: the source image matrix.
- `rotation_deg`: rotation in degrees.  Values are normalised modulo 360.

## Errors

Throws `ArgumentError` for non-multiple-of-90 values.
"""
function _apply_rotation(img::AbstractMatrix, rotation_deg::Real)::AbstractMatrix
    deg = mod(Float64(rotation_deg), 360.0)
    deg ≈ 0.0   && return img
    deg ≈ 90.0  && return rotr90(img)
    deg ≈ 180.0 && return rot180(img)
    deg ≈ 270.0 && return rotl90(img)
    throw(ArgumentError(
        "augment_phylopic: rotation must be a multiple of 90 degrees. " *
        "Got $(rotation_deg) degrees. Arbitrary angles are not yet supported."
    ))
end

# ---------------------------------------------------------------------------
# Public: range anchor
# ---------------------------------------------------------------------------

"""
    _range_anchor(xstart::Real, xstop::Real, at::Symbol) -> Float64

Compute the x anchor coordinate for a range `[xstart, xstop]` according to
the `at` placement directive.

## Arguments

- `xstart`, `xstop`: range endpoints (order does not matter for `:midpoint`).
- `at`: `:start`, `:stop`, or `:midpoint`.

## Returns

The x coordinate at which to anchor the glyph.

## Errors

Throws `ArgumentError` for unknown `at` values.
"""
function _range_anchor(xstart::Real, xstop::Real, at::Symbol)::Float64
    at === :start    && return Float64(xstart)
    at === :stop     && return Float64(xstop)
    at === :midpoint && return (Float64(xstart) + Float64(xstop)) / 2.0
    throw(ArgumentError(
        "augment_phylopic_ranges: unknown `at` value `$at`. " *
        "Valid values: $(join(VALID_AT_POSITIONS, ", "))."
    ))
end
