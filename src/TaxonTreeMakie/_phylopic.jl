
# ---------------------------------------------------------------------------
# TaxonTreeMakie — PhyloPic silhouette support for dendrogram leaf tips
#
# This file provides helpers for loading and rendering PhyloPic silhouette
# images at the tip positions of a TaxonTree dendrogram.
#
# Public (within extension):
#   _load_tip_phylopic_image(taxon_name) → Union{Matrix{Makie.RGBA{Makie.N0f8}}, Nothing}
#   _render_tip_phylopic!(p, tree, xs, ys; ...) → Nothing
#
# Image loading delegates to PhyloPicMakie._load_phylopic_image (which
# handles both URL resolution and image decoding via FileIO).  PhyloPicMakie
# is a hard dependency of PaleobiologyDB so it is always available.
#
# Coordinate geometry and reactive axis-scale correction are delegated to
# PhyloPicMakie._compute_image_bbox and PhyloPicMakie._axis_scale_correction_obs
# so that the bug-fix (anisotropic-axis aspect correction) is applied
# consistently.
# ---------------------------------------------------------------------------

import PhyloPicMakie
const PhyloPicDB = PhyloPicMakie.PhyloPicDB
using PaleobiologyDB.PhyloPicPBDB: acquire_phylopic

# ---------------------------------------------------------------------------
# Image loading
# ---------------------------------------------------------------------------

"""
    _load_tip_phylopic_image(
        taxon_name::AbstractString;
        image_rendering::Symbol = :thumbnail,
    ) -> Union{Matrix{Makie.RGBA{Makie.N0f8}}, Nothing}

Look up and download the PhyloPic image for `taxon_name`.

`image_rendering` controls which URL is fetched:

| `image_rendering` | `acquire_phylopic` field | Format |
|---|---|---|
| `:thumbnail` *(default)* | `:phylopic_thumbnail` | PNG; square thumbnail, largest available |
| `:raster` | `:phylopic_raster` | PNG; full-resolution, largest available |
| `:og_image` | `:phylopic_og_image` | PNG; Open Graph social-media preview |
| `:vector` | `:phylopic_vector` | SVG; black silhouette on transparent — requires FileIO SVG plugin |
| `:source_file` | `:phylopic_source_file` | SVG or raster — format matches the original upload |

Delegates to `PhyloPicMakie._load_phylopic_image` for URL resolution and image
decoding.  Both the PhyloPic metadata lookup (taxon → URL) and the image
download are cached via `DataCaches.jl`; repeated calls for the same taxon
name within a session are instant.

## Returns

A `Matrix{RGBA{N0f8}}` in Julia column-major layout, or `nothing` when the
image could not be resolved or loaded.  Callers should apply `rotr90` before
passing to `Makie.image!`.
"""
function _load_tip_phylopic_image(
    taxon_name::AbstractString;
    image_rendering::Symbol = :thumbnail,
)::Union{Matrix{Makie.RGBA{Makie.N0f8}}, Nothing}
    image_rendering ∈ PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS || throw(ArgumentError(
        "_load_tip_phylopic_image: unknown `image_rendering` value `:$image_rendering`. " *
        "Valid values: $(join(string.(':', PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS), ", "))."
    ))

    rec = try
        acquire_phylopic(string(taxon_name))
    catch err
        @warn "TaxonTreeMakie: PhyloPic lookup failed for \"$taxon_name\"" exception = err
        return nothing
    end

    field = if image_rendering === :thumbnail
        :phylopic_thumbnail
    elseif image_rendering === :raster
        :phylopic_raster
    elseif image_rendering === :og_image
        :phylopic_og_image
    elseif image_rendering === :vector
        :phylopic_vector
    else  # :source_file, already validated above
        :phylopic_source_file
    end

    url = get(rec, field, missing)
    if ismissing(url) || isempty(string(url))
        return nothing
    end

    try
        return PhyloPicMakie._load_phylopic_image(string(url))
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
        image_rendering::Symbol = :thumbnail,
    ) -> Nothing

Add one `Makie.image!` (or `Makie.poly!` placeholder) per leaf tip to the
compound plot `p`.

This function is called **once** during `Makie.plot!` when `show_phylopic`
is true.  Images are static after creation; toggling `p[:show_phylopic][]`
changes their visibility without re-fetching.

For `aspect = :preserve`, the x-range of each image is a reactive
`Makie.Observable` derived from `PhyloPicMakie._axis_scale_correction_obs`.
This corrects for anisotropic axes (where one data unit occupies a different
number of pixels in x vs y) so rendered glyphs maintain correct pixel-space
proportions after auto-limits or window resize events.

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
- `image_rendering`: which image URL to fetch.  Valid values:
  `:thumbnail` (default), `:raster`, `:og_image`, `:vector`, `:source_file`.
  See [`PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS`](@ref) for the full table.

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
    image_rendering::Symbol = :thumbnail,
)::Nothing
    on_missing ∈ (:skip, :placeholder, :error) || throw(ArgumentError(
        "_render_tip_phylopic!: unknown `on_missing` value `$on_missing`. " *
        "Valid values: :skip, :placeholder, :error."
    ))
    image_rendering ∈ PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS || throw(ArgumentError(
        "_render_tip_phylopic!: unknown `image_rendering` value `:$image_rendering`. " *
        "Valid values: $(join(string.(':', PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS), ", "))."
    ))

    g = tree.graph
    leaf_vertices = [v for v in Graphs.vertices(g) if isempty(Graphs.outneighbors(g, v))]
    isempty(leaf_vertices) && return nothing

    # Reactive scale correction: recomputes whenever the axis limits or
    # viewport change so :preserve images stay correctly proportioned.
    scale_corr_obs = PhyloPicMakie._axis_scale_correction_obs(
        Makie.parent_scene(p)
    )

    # Aligned mode: all images share a single x column.
    x_align = maximum(Float64(xs[v]) for v in leaf_vertices) + Float64(tip_xoffset) +
               Float64(phylopic_xoffset)

    for v in leaf_vertices
        taxon_name = tree.taxa[v].name
        img = _load_tip_phylopic_image(taxon_name; image_rendering)

        # x anchor: either per-leaf or uniform column.
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
        h_px, w_px = size(img)

        # Static y-range: glyph_size governs y extent; independent of scale.
        _, _, y_lo, y_hi = PhyloPicMakie._compute_image_bbox(
            x_anchor, y_anchor, w_px, h_px;
            glyph_size            = glyph_size,
            aspect                = aspect,
            placement             = :left,
            xoffset               = 0.0,
            yoffset               = 0.0,
            axis_scale_correction = 1.0,
        )

        # Reactive x-range for :preserve aspect: recalculates whenever the
        # axis scale changes so the glyph stays proportioned on anisotropic axes.
        x_range = if aspect === :preserve
            Makie.lift(scale_corr_obs) do sc
                x_lo, x_hi, _, _ = PhyloPicMakie._compute_image_bbox(
                    x_anchor, y_anchor, w_px, h_px;
                    glyph_size            = glyph_size,
                    aspect                = :preserve,
                    placement             = :left,
                    xoffset               = 0.0,
                    yoffset               = 0.0,
                    axis_scale_correction = sc,
                )
                (x_lo, x_hi)
            end
        else
            # :stretch — equal data-unit width and height; no anisotropy correction.
            x_lo, x_hi, _, _ = PhyloPicMakie._compute_image_bbox(
                x_anchor, y_anchor, w_px, h_px;
                glyph_size = glyph_size,
                aspect     = :stretch,
                placement  = :left,
                xoffset    = 0.0,
                yoffset    = 0.0,
            )
            (x_lo, x_hi)
        end

        # Makie.image! expects row-major data; rotr90 converts Julia column-major.
        Makie.image!(
            p,
            x_range,
            (y_lo, y_hi),
            rotr90(img);
            interpolate = true,
            visible     = p[:show_phylopic],
            clip_planes = Makie.Plane3f[],
        )
    end

    return nothing
end
