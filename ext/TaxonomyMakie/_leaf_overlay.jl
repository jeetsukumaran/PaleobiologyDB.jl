# ---------------------------------------------------------------------------
# TaxonomyMakie — internal leaf-overlay planning
#
# Owns tree-specific leaf discovery plus translation from tree and label
# policy into data-space anchor instructions. Rendering remains delegated to
# the PBDB bridge and the shared PhyloPicMakie anchored-overlay substrate.
# ---------------------------------------------------------------------------

struct _LeafOverlayPlan{P}
    leaf_vertices::Vector{Int}
    leaf_names::Vector{String}
    anchor_positions::P
end

const VALID_LEAF_OVERLAY_ANCHORS = (:tip, :tip_label_origin)

function _leaf_overlay_probe_scatter!(scene_like, positions)
    return Makie.scatter!(
        scene_like,
        positions;
        color = Makie.RGBAf(0, 0, 0, 0),
        markersize = 0,
        strokewidth = 0,
        visible = false,
        inspectable = false,
    )
end

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

function _text_bbox_metrics_px(text_plot)
    bb = Makie.boundingbox(text_plot, :pixel)
    x0, _, w, _ = _rect_origin_widths(bb)
    return (
        left = x0,
        right = x0 + w,
        width = w,
    )
end

function _plan_leaf_tip_phylopic_overlay(
        tree::TaxonomyTree,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real};
        anchor::Symbol = :tip,
        align::Bool = false,
        column_x::Union{Nothing, Real} = nothing,
        tip_xoffset::Real = 0.0,
    )::_LeafOverlayPlan
    anchor ∈ VALID_LEAF_OVERLAY_ANCHORS || throw(
        ArgumentError(
            "_plan_leaf_tip_phylopic_overlay: unknown `anchor` value `:$anchor`. " *
                "Valid values: $(join(string.(':', VALID_LEAF_OVERLAY_ANCHORS), ", "))."
        )
    )

    leaves = _leaf_positions(tree, xs, ys)
    x_anchors = Float64[
        anchor === :tip ? leaves.x[i] : leaves.x[i] + Float64(tip_xoffset)
        for i in eachindex(leaves.vertices)
    ]

    if align && !isempty(x_anchors)
        xcol = isnothing(column_x) ? maximum(x_anchors) : Float64(column_x)
        fill!(x_anchors, xcol)
    end

    anchor_positions = Makie.Point2f[
        Makie.Point2f(Float32(x_anchors[i]), Float32(leaves.y[i]))
        for i in eachindex(leaves.vertices)
    ]
    return _LeafOverlayPlan(leaves.vertices, leaves.names, anchor_positions)
end

function _plan_leaf_label_phylopic_overlay(
        ax::Makie.Axis,
        tree::TaxonomyTree,
        xs::AbstractVector{<:Real},
        ys::AbstractVector{<:Real};
        leaf_text_plots::AbstractVector,
        tip_xoffset::Real = 0.0,
        tip_yoffset::Real = 0.0,
        phylopic_xoffset::Real = 0.0,
        phylopic_yoffset::Real = 0.0,
        align::Bool = false,
    )::_LeafOverlayPlan
    leaves = _leaf_positions(tree, xs, ys)
    length(leaves.vertices) == length(leaf_text_plots) || throw(
        ArgumentError(
            "_plan_leaf_label_phylopic_overlay: `leaf_text_plots` must match the number of leaves."
        )
    )
    isempty(leaves.vertices) && return _LeafOverlayPlan(leaves.vertices, leaves.names, Makie.Point2f[])

    label_origin_points = Makie.Point2f[
        Makie.Point2f(
            Float32(leaves.x[i] + Float64(tip_xoffset)),
            Float32(leaves.y[i] + Float64(tip_yoffset)),
        )
        for i in eachindex(leaves.vertices)
    ]
    label_unit_points = Makie.Point2f[
        Makie.Point2f(p[1] + 1.0f0, p[2]) for p in label_origin_points
    ]

    label_origin_source = _leaf_overlay_probe_scatter!(ax, label_origin_points)
    label_unit_source = _leaf_overlay_probe_scatter!(ax, label_unit_points)
    label_origin_pixels = Makie.register_projected_positions!(
        label_origin_source;
        input_name = :positions,
        output_name = gensym(:taxonomy_leaf_label_origin_pixels),
        output_space = :pixel,
    )
    label_unit_pixels = Makie.register_projected_positions!(
        label_unit_source;
        input_name = :positions,
        output_name = gensym(:taxonomy_leaf_label_unit_pixels),
        output_space = :pixel,
    )

    label_origin_xs = Float64[leaves.x[i] + Float64(tip_xoffset) for i in eachindex(leaves.vertices)]
    anchor_positions = Makie.lift(label_origin_pixels, label_unit_pixels) do origins, units
        bbox_metrics = [_text_bbox_metrics_px(tp) for tp in leaf_text_plots]
        global_right_px = isempty(bbox_metrics) ? 0.0 : maximum(tm.right for tm in bbox_metrics)
        planned = Makie.Point2f[]
        sizehint!(planned, length(leaves.vertices))

        for i in eachindex(leaves.vertices)
            x_px_per_data = max(
                abs(Float64(units[i][1]) - Float64(origins[i][1])),
                eps(Float64),
            )
            label_extent_px = align ? (global_right_px - bbox_metrics[i].left) : bbox_metrics[i].width
            anchor_x = label_origin_xs[i] + label_extent_px / x_px_per_data + Float64(phylopic_xoffset)
            anchor_y = leaves.y[i] + Float64(phylopic_yoffset)
            push!(planned, Makie.Point2f(Float32(anchor_x), Float32(anchor_y)))
        end
        return planned
    end

    return _LeafOverlayPlan(leaves.vertices, leaves.names, anchor_positions)
end

function _augment_leaf_phylopic!(
        ax::Makie.Axis,
        plan::_LeafOverlayPlan;
        taxon::Union{AbstractVector, Nothing} = nothing,
        glyph::Union{AbstractMatrix, Nothing} = nothing,
        placement::Symbol = :center,
        xoffset::Real = 0.0,
        yoffset::Real = 0.0,
        glyph_size::Real = 0.4,
        aspect::Symbol = :preserve,
        rotation::Real = 0.0,
        mirror::Bool = false,
        image_rendering::Symbol = :thumbnail,
        on_missing::Symbol = :skip,
    )
    resolved_taxa = isnothing(taxon) ? plan.leaf_names : taxon
    return PhyloPic._augment_taxon_phylopic_anchored!(
        ax,
        plan.anchor_positions;
        taxon = resolved_taxa,
        glyph = glyph,
        anchor_space = :data,
        glyph_size_space = :data,
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
end
