# ---------------------------------------------------------------------------
# TaxonomyTreeMakie — PhyloPic silhouette support for dendrogram leaf tips
#
# This file provides helpers for loading and rendering PhyloPic silhouettes
# at dendrogram leaf tips using Makie scatter markers. The anchor remains in
# data space, while marker size and offset are handled in pixel space via
# `markerspace = :pixel`, which avoids anisotropic-axis distortion.
# ---------------------------------------------------------------------------

const PhyloPicDB = PhyloPicMakie.PhyloPicDB
using .PhyloPic: acquire_phylopic

# ---------------------------------------------------------------------------
# Image loading
# ---------------------------------------------------------------------------

function _load_tip_phylopic_image(
        taxon_name::AbstractString;
        image_rendering::Symbol = :thumbnail,
    )::Union{Matrix{Makie.RGBA{Makie.N0f8}}, Nothing}
    image_rendering ∈ PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS || throw(
        ArgumentError(
            "_load_tip_phylopic_image: unknown `image_rendering` value `:$image_rendering`. " *
                "Valid values: $(join(string.(':', PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS), ", "))."
        )
    )

    rec = try
        acquire_phylopic(string(taxon_name))
    catch err
        @warn string("TaxonomyTreeMakie: PhyloPic lookup failed for \"", taxon_name, "\"") exception = err
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
    else
        :phylopic_source_file
    end

    url = get(rec, field, missing)
    if ismissing(url) || isempty(string(url))
        return nothing
    end

    try
        return PhyloPicMakie._load_phylopic_image(string(url))
    catch err
        @warn string("TaxonomyTreeMakie: image load failed for \"", taxon_name, "\"") exception = err
        return nothing
    end
end

# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

function _rect_origin_widths(rect)
    origin = try
        getproperty(rect, :origin)
    catch
        nothing
    end
    widths = try
        getproperty(rect, :widths)
    catch
        nothing
    end
    if !(isnothing(origin) || isnothing(widths))
        return Float64(origin[1]), Float64(origin[2]), Float64(widths[1]), Float64(widths[2])
    end

    xmin = try
        Float64(Makie.minimum(rect)[1])
    catch
        nothing
    end
    ymin = try
        Float64(Makie.minimum(rect)[2])
    catch
        nothing
    end
    xmax = try
        Float64(Makie.maximum(rect)[1])
    catch
        nothing
    end
    ymax = try
        Float64(Makie.maximum(rect)[2])
    catch
        nothing
    end
    if !(isnothing(xmin) || isnothing(ymin) || isnothing(xmax) || isnothing(ymax))
        return xmin, ymin, xmax - xmin, ymax - ymin
    end

    throw(ArgumentError("Unable to extract rectangle geometry from $(typeof(rect))."))
end

function _scene_limit_rect(scene)
    for getter in (
            s -> try s.camera_controls.limits[] catch; nothing end,
            s -> try s.limits[] catch; nothing end,
            s -> try s.finallimits[] catch; nothing end,
        )
        rect = getter(scene)
        !isnothing(rect) && return rect
    end
    return nothing
end

function _axis_pixels_per_data(p)::Tuple{Float64, Float64}
    scene = Makie.parent_scene(p)
    viewport = try
        scene.viewport[]
    catch
        nothing
    end
    data_rect = _scene_limit_rect(scene)

    if isnothing(viewport) || isnothing(data_rect)
        return 1.0, 1.0
    end

    _, _, vp_w, vp_h = _rect_origin_widths(viewport)
    _, _, data_w, data_h = _rect_origin_widths(data_rect)

    vp_w > 0 || return 1.0, 1.0
    vp_h > 0 || return 1.0, 1.0
    data_w > 0 || return 1.0, 1.0
    data_h > 0 || return 1.0, 1.0

    return vp_w / data_w, vp_h / data_h
end

function _text_bbox_metrics_px(text_plot)
    bb = Makie.boundingbox(text_plot, :pixel)
    x0, _, w, h = _rect_origin_widths(bb)
    return (
        left = x0,
        right = x0 + w,
        width = w,
        height = h,
    )
end

function _marker_size_px(
        img::AbstractMatrix;
        glyph_size::Real,
        aspect::Symbol,
        y_px_per_data::Real,
    )
    h_px, w_px = size(img)
    target_h_px = max(1.0, 2.0 * Float64(glyph_size) * Float64(y_px_per_data))
    if aspect === :stretch
        return (target_h_px, target_h_px)
    elseif aspect === :preserve
        return (target_h_px * Float64(w_px) / Float64(h_px), target_h_px)
    else
        throw(ArgumentError("_marker_size_px: unknown `aspect` value `$aspect`. Valid values: :preserve, :stretch."))
    end
end

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

function _render_tip_phylopic!(
        p,
        tree::TaxonomyTree,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real};
        leaf_vertices::AbstractVector{<:Integer},
        leaf_text_plots::AbstractVector,
        glyph_size::Real,
        do_align::Bool,
        phylopic_xoffset::Real,
        phylopic_yoffset::Real,
        tip_xoffset::Real,
        on_missing::Symbol,
        aspect::Symbol,
        image_rendering::Symbol = :thumbnail,
    )::Nothing
    on_missing ∈ (:skip, :placeholder, :error) || throw(
        ArgumentError(
            "_render_tip_phylopic!: unknown `on_missing` value `$on_missing`. Valid values: :skip, :placeholder, :error."
        )
    )
    image_rendering ∈ PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS || throw(
        ArgumentError(
            "_render_tip_phylopic!: unknown `image_rendering` value `:$image_rendering`. " *
                "Valid values: $(join(string.(':', PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS), ", "))."
        )
    )

    isempty(leaf_vertices) && return nothing
    length(leaf_vertices) == length(leaf_text_plots) || throw(
        ArgumentError("_render_tip_phylopic!: `leaf_vertices` and `leaf_text_plots` must have the same length.")
    )

    x_px_per_data, y_px_per_data = _axis_pixels_per_data(p)
    gap_px = Float64(phylopic_xoffset) * x_px_per_data
    text_metrics = [_text_bbox_metrics_px(tp) for tp in leaf_text_plots]
    global_right_px = maximum(tm.right for tm in text_metrics)

    for (i, v) in enumerate(leaf_vertices)
        taxon_name = tree.taxa[v].name
        img = _load_tip_phylopic_image(taxon_name; image_rendering)
        marker_size_px = if isnothing(img)
            (max(1.0, 2.0 * Float64(glyph_size) * y_px_per_data), max(1.0, 2.0 * Float64(glyph_size) * y_px_per_data))
        else
            _marker_size_px(img; glyph_size = glyph_size, aspect = aspect, y_px_per_data = y_px_per_data)
        end
        marker_w_px, _ = marker_size_px

        if isnothing(img)
            if on_missing === :error
                throw(
                    ErrorException(
                        string(
                            "_render_tip_phylopic!: no PhyloPic image available for \"",
                            taxon_name,
                            "\" (on_missing = :error).",
                        )
                    )
                )
            elseif on_missing === :skip
                continue
            end
        end

        label_metrics = text_metrics[i]
        label_extent_px = do_align ? (global_right_px - label_metrics.left) : label_metrics.width
        marker_dx_px = label_extent_px + gap_px + 0.5 * marker_w_px

        position = Makie.Point2f(
            Float64(xs[v]) + Float64(tip_xoffset),
            Float64(ys[v]) + Float64(phylopic_yoffset),
        )

        if isnothing(img)
            Makie.scatter!(
                p,
                [position];
                marker = Makie.Rect,
                markerspace = :pixel,
                markersize = marker_size_px,
                marker_offset = (marker_dx_px, 0.0),
                color = (:lightgray, 0.5),
                strokecolor = :gray,
                strokewidth = 0.5,
                visible = p[:show_phylopic],
                clip_planes = Makie.Plane3f[],
            )
        else
            Makie.scatter!(
                p,
                [position];
                marker = rotr90(img),
                markerspace = :pixel,
                markersize = marker_size_px,
                marker_offset = (marker_dx_px, 0.0),
                visible = p[:show_phylopic],
                clip_planes = Makie.Plane3f[],
            )
        end
    end

    return nothing
end
