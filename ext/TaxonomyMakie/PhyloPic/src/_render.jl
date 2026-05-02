# ---------------------------------------------------------------------------
# PhyloPic — rendering: augment_phylopic! and all public variants
#
# All public functions resolve images via _resolve_images (from _resolve.jl)
# and then delegate to PhyloPicMakie.augment_phylopic!.
#
# Tree-overlay entry points also use _augment_taxon_phylopic_anchored!, which
# resolves PBDB taxon names here and then forwards generic missing-image,
# rotation, mirroring, and anchored-overlay preparation to
# PhyloPicMakie._augment_resolved_phylopic_anchored!.
#
# _extract_column lives in PhyloPicMakie._augment_api and is accessed as
# PhyloPicMakie._extract_column here.
#
# Call graph:
#
#   augment_phylopic  / augment_phylopic!  (vector API)
#   augment_phylopic  / augment_phylopic!  (table API)
#       └─► PhyloPicMakie.augment_phylopic!(ax, xs, ys, images; kwargs...)
#
#   augment_phylopic_ranges  / augment_phylopic_ranges!  (vector API)
#   augment_phylopic_ranges  / augment_phylopic_ranges!  (table API)
#       └─► PhyloPicMakie.augment_phylopic!(ax, xs_anchor, ys, images; ...)
#               (after PhyloPicMakie._range_anchor)
#
# Makie, PhyloPicMakie, RGBA, N0f8, Colorant are all in scope from the
# enclosing PhyloPic module (PhyloPic.jl).
# ---------------------------------------------------------------------------

const _VALID_ANCHORED_ON_MISSING = (:skip, :error, :placeholder)
const _HAS_SCENE_LIKE_ANCHORED_INTERNALS =
    isdefined(PhyloPicMakie, :_anchor_positions_spec) &&
    isdefined(PhyloPicMakie, :_glyph_size_spec) &&
    isdefined(PhyloPicMakie, :_DataAnchors) &&
    isdefined(PhyloPicMakie, :_PixelAnchors) &&
    isdefined(PhyloPicMakie, :_DataGlyphSize) &&
    isdefined(PhyloPicMakie, :_AnchoredOverlay)

function _prepared_anchor_positions(anchor_positions, kept_indices::AbstractVector{<:Integer})
    anchor_positions isa AbstractVector && return anchor_positions[kept_indices]
    return Makie.lift(pos -> pos[kept_indices], anchor_positions)
end

function _prepare_resolved_anchor_overlay(
        anchor_positions,
        images::AbstractVector;
        rotation::Real,
        mirror::Bool,
        on_missing::Symbol,
    )
    on_missing ∈ _VALID_ANCHORED_ON_MISSING || throw(
        ArgumentError(
            "augment_phylopic: unknown `on_missing` value `$on_missing`. " *
                "Valid values: $(join(_VALID_ANCHORED_ON_MISSING, ", "))."
        )
    )

    kept_indices = Int[]
    rendered_images = AbstractMatrix[]
    sizehint!(kept_indices, length(images))
    sizehint!(rendered_images, length(images))

    for i in eachindex(images)
        img = images[i]

        if isnothing(img)
            if on_missing === :error
                throw(
                    ErrorException(
                        "augment_phylopic: missing image for data point $i " *
                            "(on_missing = :error)."
                    )
                )
            elseif on_missing === :placeholder
                push!(kept_indices, i)
                push!(rendered_images, PhyloPicMakie._placeholder_glyph())
            end
            continue
        end

        rendered = PhyloPicMakie._apply_rotation(img, rotation)
        mirror && (rendered = rendered[:, end:-1:1])

        push!(kept_indices, i)
        push!(rendered_images, rendered)
    end

    isempty(rendered_images) && return nothing
    return (
        anchor_positions = _prepared_anchor_positions(anchor_positions, kept_indices),
        images = rendered_images,
    )
end

function _transparent_anchored_probe_scatter!(parent, positions; visible)
    return Makie.scatter!(
        parent,
        positions;
        color = Makie.RGBAf(0, 0, 0, 0),
        markersize = 0,
        strokewidth = 0,
        visible = visible,
        inspectable = false,
    )
end

function _projected_anchor_positions_scene_like!(parent, anchor_spec, image_sizes; kwargs...)
    throw(
        ArgumentError(
            "augment_phylopic: this PhyloPicMakie surface does not expose the " *
                "plot-owned anchored-overlay internals required for non-axis parents."
        )
    )
end

if _HAS_SCENE_LIKE_ANCHORED_INTERNALS
    function _projected_anchor_positions_scene_like!(
            parent,
            anchor_spec::PhyloPicMakie._DataAnchors,
            image_sizes::AbstractVector{<:Tuple{<:Integer, <:Integer}};
            glyph_size::Real,
            aspect::Symbol,
            placement::Symbol,
            xoffset::Real,
            yoffset::Real,
            visible,
        )
        positions = Makie.lift(
            pos -> PhyloPicMakie._offset_point2f_positions(
                PhyloPicMakie._normalize_point2f_positions(pos),
                xoffset,
                yoffset,
            ),
            PhyloPicMakie._as_node(anchor_spec.positions),
        )

        anchor_source = _transparent_anchored_probe_scatter!(parent, positions; visible = visible)
        anchor_pixels = Makie.register_projected_positions!(
            anchor_source;
            input_name = :positions,
            output_name = :phylopic_anchor_pixel_positions,
            output_space = :pixel,
        )

        upper_source = _transparent_anchored_probe_scatter!(
            parent,
            Makie.lift(pos -> PhyloPicMakie._vertical_probe_positions(pos, glyph_size), positions);
            visible = visible,
        )
        lower_source = _transparent_anchored_probe_scatter!(
            parent,
            Makie.lift(pos -> PhyloPicMakie._vertical_probe_positions(pos, -glyph_size), positions);
            visible = visible,
        )
        upper_pixels = Makie.register_projected_positions!(
            upper_source;
            input_name = :positions,
            output_name = :phylopic_upper_pixel_positions,
            output_space = :pixel,
        )
        lower_pixels = Makie.register_projected_positions!(
            lower_source;
            input_name = :positions,
            output_name = :phylopic_lower_pixel_positions,
            output_space = :pixel,
        )

        pixel_half_heights = Makie.lift(upper_pixels, lower_pixels) do upper, lower
            Float32[
                hypot(up[1] - lo[1], up[2] - lo[2]) / 2.0f0
                for (up, lo) in zip(upper, lower)
            ]
        end

        extent_positions = Makie.lift(
            positions,
            PhyloPicMakie._axis_scale_correction_obs(Makie.parent_scene(parent)),
        ) do pos, scale_corr
            PhyloPicMakie._bbox_corner_positions(
                pos,
                image_sizes;
                glyph_size = glyph_size,
                aspect = aspect,
                placement = placement,
                axis_scale_correction = scale_corr,
            )
        end
        extent_source = _transparent_anchored_probe_scatter!(
            parent,
            extent_positions;
            visible = visible,
        )

        pixel_positions = Makie.lift(anchor_pixels) do pos
            PhyloPicMakie._normalize_point3f_positions(pos)
        end

        return (
            pixel_positions = pixel_positions,
            pixel_half_heights = pixel_half_heights,
            source_plots = (anchor_source, upper_source, lower_source, extent_source),
        )
    end

    function _projected_anchor_positions_scene_like!(
            parent,
            anchor_spec::PhyloPicMakie._PixelAnchors,
            image_sizes::AbstractVector{<:Tuple{<:Integer, <:Integer}};
            glyph_size::Real,
            aspect::Symbol,
            placement::Symbol,
            xoffset::Real,
            yoffset::Real,
            visible,
        )
        positions = Makie.lift(
            pos -> PhyloPicMakie._offset_point3f_positions(
                PhyloPicMakie._normalize_point3f_positions(pos),
                xoffset,
                yoffset,
            ),
            PhyloPicMakie._as_node(anchor_spec.positions),
        )
        half_heights = Makie.Observable(fill(Float32(glyph_size), length(image_sizes)))
        return (
            pixel_positions = positions,
            pixel_half_heights = half_heights,
            source_plots = (),
        )
    end
end

function _augment_phylopic_anchored_scene_like!(
        parent,
        anchor_positions,
        images::AbstractVector;
        anchor_space::Symbol,
        glyph_size_space::Symbol,
        glyph_size::Real,
        aspect::Symbol,
        placement::Symbol,
        xoffset::Real,
        yoffset::Real,
    )
    parent isa Makie.Axis && return PhyloPicMakie._augment_phylopic_anchored!(
        parent,
        anchor_positions,
        images;
        anchor_space = anchor_space,
        glyph_size_space = glyph_size_space,
        glyph_size = glyph_size,
        aspect = aspect,
        placement = placement,
        xoffset = xoffset,
        yoffset = yoffset,
    )
    isempty(images) && return nothing
    _HAS_SCENE_LIKE_ANCHORED_INTERNALS || throw(
        ArgumentError(
            "augment_phylopic: this PhyloPicMakie surface does not expose the " *
                "plot-owned anchored-overlay internals required for non-axis parents."
        )
    )

    anchor_spec = PhyloPicMakie._anchor_positions_spec(anchor_positions; anchor_space)
    size_spec = PhyloPicMakie._glyph_size_spec(glyph_size; glyph_size_space)
    (anchor_spec isa PhyloPicMakie._DataAnchors) ==
        (size_spec isa PhyloPicMakie._DataGlyphSize) || throw(
            ArgumentError(
                "augment_phylopic: unsupported mixed anchor/glyph space combination " *
                    "(`anchor_space = :$anchor_space`, `glyph_size_space = :$glyph_size_space`). " *
                    "Supported combinations are `(:data, :data)` and `(:pixel, :pixel)`."
            )
        )

    visible = Makie.Observable(true)
    image_sizes = [(size(img, 2), size(img, 1)) for img in images]
    geometry = _projected_anchor_positions_scene_like!(
        parent,
        anchor_spec,
        image_sizes;
        glyph_size = size_spec.half_height,
        aspect = aspect,
        placement = placement,
        xoffset = xoffset,
        yoffset = yoffset,
        visible = visible,
    )
    length(geometry.pixel_positions[]) == length(images) || throw(
        ArgumentError(
            "augment_phylopic: anchor and image vectors must have the same length."
        )
    )

    marker_sizes = Makie.lift(geometry.pixel_half_heights) do half_heights
        PhyloPicMakie._pixel_marker_sizes(image_sizes, half_heights; aspect)
    end
    marker_offsets = Makie.lift(marker_sizes) do sizes
        PhyloPicMakie._pixel_marker_offsets(sizes; placement)
    end

    visible_plot = Makie.scatter!(
        parent,
        geometry.pixel_positions;
        marker = images,
        markersize = marker_sizes,
        marker_offset = marker_offsets,
        markerspace = :pixel,
        space = :pixel,
        visible = visible,
        inspectable = false,
        transformation = :nothing,
    )
    for probe_plot in geometry.source_plots
        Makie.on(probe_plot, visible_plot.visible, update = true) do is_visible
            probe_plot[:visible] = is_visible
            return Makie.Consume(false)
        end
    end
    return PhyloPicMakie._AnchoredOverlay(visible_plot, geometry.source_plots)
end

# ---------------------------------------------------------------------------
# Public: core vector API
# ---------------------------------------------------------------------------

function _augment_taxon_phylopic_anchored!(
        parent,
        anchor_positions;
        taxon::Union{AbstractVector, Nothing} = nothing,
        glyph::Union{AbstractMatrix, Nothing} = nothing,
        anchor_space::Symbol,
        glyph_size_space::Symbol,
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
    n = anchor_positions isa AbstractVector ? length(anchor_positions) : length(anchor_positions[])
    images = _resolve_images(taxon, glyph, n; image_rendering)

    # Prefer the newer upstream helper when it is available. The unpinned test
    # environment currently resolves to an older mainline surface that exposes
    # only the lower-level anchored-overlay substrate.
    resolved_helper_name = Symbol("_augment_resolved_phylopic_anchored!")
    if isdefined(PhyloPicMakie, resolved_helper_name)
        resolved_helper! = getfield(PhyloPicMakie, resolved_helper_name)
        return resolved_helper!(
            parent,
            anchor_positions,
            images;
            anchor_space = anchor_space,
            glyph_size_space = glyph_size_space,
            placement = placement,
            xoffset = xoffset,
            yoffset = yoffset,
            glyph_size = glyph_size,
            aspect = aspect,
            rotation = rotation,
            mirror = mirror,
            on_missing = on_missing,
        )
    end

    prepared = _prepare_resolved_anchor_overlay(
        anchor_positions,
        images;
        rotation = rotation,
        mirror = mirror,
        on_missing = on_missing,
    )
    isnothing(prepared) && return nothing

    return _augment_phylopic_anchored_scene_like!(
        parent,
        prepared.anchor_positions,
        prepared.images;
        anchor_space = anchor_space,
        glyph_size_space = glyph_size_space,
        placement = placement,
        xoffset = xoffset,
        yoffset = yoffset,
        glyph_size = glyph_size,
        aspect = aspect,
    )
end

"""
    augment_phylopic!(
        ax::Makie.Axis,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        taxon::Union{AbstractVector, Nothing} = nothing,
        glyph::Union{AbstractMatrix{<:Colorant}, Nothing} = nothing,
        placement::Symbol = :center,
        xoffset::Real = 0.0,
        yoffset::Real = 0.0,
        glyph_size::Real = 0.4,
        aspect::Symbol = :preserve,
        rotation::Real = 0.0,
        mirror::Bool = false,
        image_rendering::Symbol = :thumbnail,
        on_missing::Symbol = :skip,
    ) -> Nothing

Add one PhyloPic silhouette glyph per datum to an existing Makie axis `ax`,
anchored at positions `(x[i], y[i])` in axis data coordinates.

This is the primitive operation.  All other `augment_phylopic` variants
reduce to this.

## Arguments

- `x`, `y`: anchor coordinates in axis data space.  Must have equal length.

### Image source (exactly one required)

- `taxon`: per-datum taxon names (used for glyph lookup via
  [`acquire_phylopic`](@ref)).  Missing or empty
  strings are handled according to `on_missing`.
- `glyph`: a single pre-loaded image matrix (e.g. from `FileIO.load`),
  broadcast to every data point.  When provided, `taxon` is ignored.

### Placement

- `placement`: anchor position on the glyph relative to the data coordinate.
  One of `:center` (default), `:left`, `:right`, `:top`, `:bottom`,
  `:topleft`, `:topright`, `:bottomleft`, `:bottomright`.
- `xoffset`, `yoffset`: additional offset in data units applied after
  anchoring.

### Sizing

- `glyph_size`: half-height of the rendered glyph in data units (total
  height = `2 * glyph_size`).  Default `0.4`.
- `aspect`: `:preserve` (default) maintains the original image aspect ratio;
  `:stretch` renders as a square.

### Rendering

- `image_rendering`: which PhyloPic image URL to fetch.  Default `:thumbnail`.
  Ignored when `glyph` is supplied directly.

  | `image_rendering` | Format |
  |---|---|
  | `:thumbnail` *(default)* | PNG; square thumbnail, largest available |
  | `:raster`      | PNG; full-resolution, largest available |
  | `:og_image`    | PNG; Open Graph social-media preview |
  | `:vector`      | SVG; black silhouette on transparent — requires SVG-capable `FileIO` plugin |
  | `:source_file` | SVG or raster — format matches the original upload |

- `rotation`: clockwise rotation in degrees.  Supported values: `0`, `90`,
  `180`, `270` (and their negatives / modulo equivalents).  Default `0.0`.
- `mirror`: if `true`, flip the glyph horizontally before rendering.

### Missing-value policy

- `on_missing`: how to handle data points for which no image is available.
  `:skip` (default) silently omits the glyph; `:error` throws; `:placeholder`
  draws a small grey rectangle at the glyph position.

## Returns

`Nothing`.  The glyphs are added as side-effects to `ax`.

## Examples

```julia
using PaleobiologyDB
using PaleobiologyDB.PhyloPic
using CairoMakie

fig = Figure()
ax  = Axis(fig[1, 1])
lines!(ax, [68.0, 66.0], [1, 1])

augment_phylopic!(
    ax,
    [68.0],
    [1.0];
    taxon          = ["Tyrannosaurus"],
    glyph_size     = 0.4,
    placement      = :left,
    image_rendering = :raster,
)
```
"""
function augment_phylopic!(
        ax::Makie.Axis,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
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
    )::Nothing
    n = length(x)
    length(y) == n || throw(
        ArgumentError(
            "augment_phylopic!: `x` and `y` must have the same length."
        )
    )
    images = _resolve_images(taxon, glyph, n; image_rendering)
    return PhyloPicMakie.augment_phylopic!(
        ax, x, y, images;
        glyph_size = glyph_size,
        aspect = aspect,
        placement = placement,
        xoffset = xoffset,
        yoffset = yoffset,
        rotation = rotation,
        mirror = mirror,
        on_missing = on_missing,
    )
end

"""
    augment_phylopic(
        ax::Makie.Axis,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        kwargs...,
    ) -> Nothing

Non-mutating alias for [`augment_phylopic!`](@ref).

Semantically identical: adds a glyph layer to an existing axis.  The `!`
convention is preserved in [`augment_phylopic!`](@ref); this alias is
provided for naming symmetry only.

See [`augment_phylopic!`](@ref) for the full keyword-argument documentation.
"""
function augment_phylopic(
        ax::Makie.Axis,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        kwargs...,
    )::Nothing
    return augment_phylopic!(ax, x, y; kwargs...)
end

# ---------------------------------------------------------------------------
# Public: range vector API
# ---------------------------------------------------------------------------

"""
    augment_phylopic_ranges!(
        ax::Makie.Axis,
        xstart::AbstractVector{<:Real},
        xstop::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        taxon::Union{AbstractVector, Nothing} = nothing,
        glyph::Union{AbstractMatrix{<:Colorant}, Nothing} = nothing,
        at::Symbol = :start,
        placement::Symbol = :center,
        xoffset::Real = 0.0,
        yoffset::Real = 0.0,
        glyph_size::Real = 0.4,
        aspect::Symbol = :preserve,
        rotation::Real = 0.0,
        mirror::Bool = false,
        on_missing::Symbol = :skip,
    ) -> Nothing

Add one PhyloPic silhouette per datum to `ax`, where each glyph is anchored
relative to a range `(xstart[i], xstop[i])` at vertical position `y[i]`.

This is a convenience wrapper for range-based data (e.g. stratigraphic
intervals).  It computes anchor x coordinates from the range endpoints and
then calls [`augment_phylopic!`](@ref).

## Arguments

- `xstart`, `xstop`: range endpoints in axis data units.
- `y`: vertical coordinate for each datum.
- `at`: where along the range to anchor the glyph.  One of:
  - `:start` (default) — anchor at `xstart[i]`.
  - `:stop` — anchor at `xstop[i]`.
  - `:midpoint` — anchor at the midpoint `(xstart[i] + xstop[i]) / 2`.
- All remaining keyword arguments are forwarded unchanged to
  [`augment_phylopic!`](@ref).

## Returns

`Nothing`.

## Examples

```julia
using PaleobiologyDB
using PaleobiologyDB.PhyloPic
using CairoMakie

taxa      = ["Tyrannosaurus", "Triceratops"]
first_app = [68.0, 68.0]
last_app  = [66.0, 66.0]

fig = Figure()
ax  = Axis(fig[1, 1]; xreversed = true,
           yticks = (1:length(taxa), taxa))

for (i, (fa, la)) in enumerate(zip(first_app, last_app))
    lines!(ax, [fa, la], [i, i]; linewidth = 4, color = :gray30)
end

augment_phylopic_ranges!(
    ax,
    first_app,
    last_app,
    collect(1:length(taxa));
    taxon     = taxa,
    at        = :start,
    glyph_size = 0.4,
    placement = :center,
)
```
"""
function augment_phylopic_ranges!(
        ax::Makie.Axis,
        xstart::AbstractVector{<:Real},
        xstop::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        at::Symbol = :start,
        kwargs...,
    )::Nothing
    n = length(xstart)
    length(xstop) == n || throw(
        ArgumentError(
            "augment_phylopic_ranges!: `xstart` and `xstop` must have the same length."
        )
    )
    length(y) == n || throw(
        ArgumentError(
            "augment_phylopic_ranges!: `y` must have the same length as `xstart`."
        )
    )
    xs = [PhyloPicMakie._range_anchor(xstart[i], xstop[i], at) for i in 1:n]
    return augment_phylopic!(ax, xs, y; kwargs...)
end

"""
    augment_phylopic_ranges(
        ax::Makie.Axis,
        xstart::AbstractVector{<:Real},
        xstop::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        kwargs...,
    ) -> Nothing

Non-mutating alias for [`augment_phylopic_ranges!`](@ref).

See [`augment_phylopic_ranges!`](@ref) for full documentation.
"""
function augment_phylopic_ranges(
        ax::Makie.Axis,
        xstart::AbstractVector{<:Real},
        xstop::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        kwargs...,
    )::Nothing
    return augment_phylopic_ranges!(ax, xstart, xstop, y; kwargs...)
end

# ---------------------------------------------------------------------------
# Public: table API
# ---------------------------------------------------------------------------

"""
    augment_phylopic!(
        ax::Makie.Axis,
        table;
        x,
        y,
        taxon = nothing,
        glyph = nothing,
        kwargs...,
    ) -> Nothing

Table-oriented variant of [`augment_phylopic!`](@ref).

Extracts coordinate and taxon columns from any Tables.jl-compatible source
(e.g. a `DataFrame`) and forwards to the vector API.

## Arguments

- `table`: any Tables.jl-compatible object.
- `x`: column selector for x coordinates (Symbol, String, or Integer).
- `y`: column selector for y coordinates.
- `taxon`: column selector for taxon names, or `nothing` if `glyph` is used.
- `glyph`: a single pre-loaded image matrix broadcast to all rows (alternative
  to `taxon`).
- All remaining keyword arguments are forwarded to the vector [`augment_phylopic!`](@ref).

## Returns

`Nothing`.

## Examples

```julia
using PaleobiologyDB
using PaleobiologyDB.PhyloPic
using CairoMakie, DataFrames

df = DataFrame(
    x     = [68.0, 68.0],
    y     = [1.0, 2.0],
    taxon = ["Tyrannosaurus", "Triceratops"],
)

fig = Figure()
ax  = Axis(fig[1, 1])
augment_phylopic!(ax, df; x = :x, y = :y, taxon = :taxon, glyph_size = 0.4)
```
"""
function augment_phylopic!(
        ax::Makie.Axis,
        table;
        x,
        y,
        taxon = nothing,
        glyph::Union{AbstractMatrix, Nothing} = nothing,
        kwargs...,
    )::Nothing
    xs = PhyloPicMakie._extract_column(table, x)
    ys = PhyloPicMakie._extract_column(table, y)
    taxa = isnothing(taxon) ? nothing : PhyloPicMakie._extract_column(table, taxon)
    return augment_phylopic!(ax, xs, ys; taxon = taxa, glyph = glyph, kwargs...)
end

"""
    augment_phylopic(
        ax::Makie.Axis,
        table;
        kwargs...,
    ) -> Nothing

Non-mutating alias for the table-based [`augment_phylopic!`](@ref).

See [`augment_phylopic!`](@ref) for full documentation.
"""
function augment_phylopic(ax::Makie.Axis, table; kwargs...)::Nothing
    return augment_phylopic!(ax, table; kwargs...)
end

# ---------------------------------------------------------------------------
# Public: range table API
# ---------------------------------------------------------------------------

"""
    augment_phylopic_ranges!(
        ax::Makie.Axis,
        table;
        xstart,
        xstop,
        y,
        taxon = nothing,
        glyph = nothing,
        at::Symbol = :start,
        kwargs...,
    ) -> Nothing

Table-oriented variant of [`augment_phylopic_ranges!`](@ref).

Extracts range and taxon columns from a Tables.jl-compatible source and
forwards to the vector range API.

## Arguments

- `table`: any Tables.jl-compatible object.
- `xstart`, `xstop`: column selectors for the range endpoints.
- `y`: column selector for the vertical coordinate.
- `taxon`: column selector for taxon names, or `nothing` if `glyph` is used.
- `glyph`: a single pre-loaded image matrix broadcast to all rows.
- `at`: `:start` (default), `:stop`, or `:midpoint` — which end of the range
  to anchor the glyph.
- All remaining keyword arguments are forwarded to the vector
  [`augment_phylopic_ranges!`](@ref).

## Returns

`Nothing`.

## Examples

```julia
using PaleobiologyDB
using PaleobiologyDB.PhyloPic
using CairoMakie, DataFrames

df = DataFrame(
    taxon      = ["Tyrannosaurus", "Triceratops"],
    first_app  = [68.0, 68.0],
    last_app   = [66.0, 66.0],
    row        = [1.0, 2.0],
)

fig = Figure()
ax  = Axis(fig[1, 1]; xreversed = true,
           yticks = (1:nrow(df), df.taxon))
for i in 1:nrow(df)
    lines!(ax, [df.first_app[i], df.last_app[i]], [i, i])
end

augment_phylopic_ranges!(
    ax, df;
    xstart = :first_app,
    xstop  = :last_app,
    y      = :row,
    taxon  = :taxon,
    at     = :start,
    glyph_size = 0.4,
)
```
"""
function augment_phylopic_ranges!(
        ax::Makie.Axis,
        table;
        xstart,
        xstop,
        y,
        taxon = nothing,
        glyph::Union{AbstractMatrix, Nothing} = nothing,
        at::Symbol = :start,
        kwargs...,
    )::Nothing
    xs = PhyloPicMakie._extract_column(table, xstart)
    xe = PhyloPicMakie._extract_column(table, xstop)
    ys = PhyloPicMakie._extract_column(table, y)
    taxa = isnothing(taxon) ? nothing : PhyloPicMakie._extract_column(table, taxon)
    return augment_phylopic_ranges!(ax, xs, xe, ys; taxon = taxa, glyph = glyph, at = at, kwargs...)
end

"""
    augment_phylopic_ranges(
        ax::Makie.Axis,
        table;
        kwargs...,
    ) -> Nothing

Non-mutating alias for the table-based [`augment_phylopic_ranges!`](@ref).

See [`augment_phylopic_ranges!`](@ref) for full documentation.
"""
function augment_phylopic_ranges(ax::Makie.Axis, table; kwargs...)::Nothing
    return augment_phylopic_ranges!(ax, table; kwargs...)
end
