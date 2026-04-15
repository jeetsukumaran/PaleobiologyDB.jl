
# ---------------------------------------------------------------------------
# PhyloPicMakie — PhyloPic-native public augment_phylopic! API
#
# Provides the public PhyloPic-native entry points for adding PhyloPic
# silhouette glyphs to a Makie axis.  All functions are keyed on PhyloPic
# node UUIDs (strings) or pre-loaded image matrices (glyph), with no
# dependency on PaleobiologyDB or PBDB taxon names.
#
# Also contains _extract_column, a generic table-column extractor shared
# with PaleobiologyDB.PhyloPicPBDB (which references it as
# PhyloPicMakie._extract_column).
#
# Call graph:
#
#   augment_phylopic! / augment_phylopic  (vector API, PhyloPic-native)
#   augment_phylopic! / augment_phylopic  (table API)
#   augment_phylopic_ranges! / augment_phylopic_ranges  (range vector API)
#   augment_phylopic_ranges! / augment_phylopic_ranges  (range table API)
#       └─► _resolve_images_by_uuid(node_uuids, glyph, n; image_rendering)
#               └─► augment_phylopic!(ax, xs, ys, images; ...)  [_render_core.jl]
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Internal: generic table column extraction
# ---------------------------------------------------------------------------

"""
    _extract_column(table, col_selector) -> AbstractVector

Extract a column from a table-like object using `col_selector`, which may be
a `Symbol` or `String` (column name) or `Integer` (one-based column index).

Works with any object that supports `propertynames` / `getproperty`
(e.g. `DataFrame`, `NamedTuple`), as well as integer-index access via
`propertynames`.

Throws `ArgumentError` if the column is not found or the index is out of
range.
"""
function _extract_column(table, col_selector)::AbstractVector
    if col_selector isa Symbol
        available = propertynames(table)
        col_selector ∈ available || throw(ArgumentError(
            "column `:$col_selector` not found. " *
            "Available columns: " * join(string.(Symbol.(":", available)), ", ") * "."
        ))
        return getproperty(table, col_selector)
    elseif col_selector isa AbstractString
        return _extract_column(table, Symbol(col_selector))
    elseif col_selector isa Integer
        available = propertynames(table)
        1 ≤ col_selector ≤ length(available) || throw(ArgumentError(
            "column index $col_selector is out of range " *
            "(table has $(length(available)) columns)."
        ))
        return getproperty(table, available[col_selector])
    else
        throw(ArgumentError(
            "column selector must be a Symbol, String, or Integer. " *
            "Got $(typeof(col_selector))."
        ))
    end
end

# ---------------------------------------------------------------------------
# Public: core vector API (PhyloPic-native)
# ---------------------------------------------------------------------------

"""
    augment_phylopic!(
        ax::Makie.Axis,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        node_uuid::Union{AbstractVector, Nothing} = nothing,
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
    ) -> Nothing

Add one PhyloPic silhouette glyph per datum to an existing Makie axis `ax`,
anchored at positions `(x[i], y[i])` in axis data coordinates.

This is the **PhyloPic-native** public API: image sources are specified as
PhyloPic node UUIDs (strings).  For PBDB taxon-name resolution use
`PaleobiologyDB.PhyloPicPBDB.augment_phylopic!` instead.

## Arguments

- `x`, `y`: anchor coordinates in axis data space.  Must have equal length.

### Image source (exactly one required)

- `node_uuid`: per-datum PhyloPic node UUID strings.  `nothing` entries are
  handled according to `on_missing`.
- `glyph`: a single pre-loaded image matrix (e.g. from `FileIO.load`),
  broadcast to every data point.  When provided, `node_uuid` is ignored.

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
  | `:raster`    | PNG; full-resolution, largest available |
  | `:og_image`  | PNG; Open Graph social-media preview |
  | `:vector`    | SVG; black silhouette on transparent — requires SVG-capable `FileIO` plugin |
  | `:source_file` | SVG or raster — format matches the original upload |

- `rotation`: clockwise rotation in degrees.  Supported values: `0`, `90`,
  `180`, `270`.  Default `0.0`.
- `mirror`: if `true`, flip the glyph horizontally before rendering.

### Missing-value policy

- `on_missing`: how to handle data points for which no image is available.
  `:skip` (default) silently omits the glyph; `:error` throws;
  `:placeholder` draws a small grey rectangle at the glyph position.

## Returns

`Nothing`.  The glyphs are added as side-effects to `ax`.

## Examples

```julia
using PhyloPicMakie, CairoMakie

fig = Figure()
ax  = Axis(fig[1, 1])

augment_phylopic!(
    ax,
    [1.0, 2.0],
    [1.0, 2.0];
    node_uuid       = ["3c4b8687-2401-4e5b-afb5-19aa3e7e8b26", nothing],
    glyph_size      = 0.4,
    placement       = :center,
    image_rendering = :thumbnail,
)
```
"""
function augment_phylopic!(
    ax::Makie.Axis,
    x::AbstractVector{<:Real},
    y::AbstractVector{<:Real};
    node_uuid::Union{AbstractVector, Nothing} = nothing,
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
    length(y) == n || throw(ArgumentError(
        "augment_phylopic!: `x` and `y` must have the same length."
    ))
    isnothing(node_uuid) && isnothing(glyph) && throw(ArgumentError(
        "augment_phylopic!: one of `node_uuid` or `glyph` must be provided."
    ))
    images = _resolve_images_by_uuid(node_uuid, glyph, n; image_rendering)
    augment_phylopic!(
        ax, x, y, images;
        glyph_size = glyph_size,
        aspect     = aspect,
        placement  = placement,
        xoffset    = xoffset,
        yoffset    = yoffset,
        rotation   = rotation,
        mirror     = mirror,
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
provided for naming symmetry.

See [`augment_phylopic!`](@ref) for the full keyword-argument documentation.
"""
function augment_phylopic(
    ax::Makie.Axis,
    x::AbstractVector{<:Real},
    y::AbstractVector{<:Real};
    kwargs...,
)::Nothing
    augment_phylopic!(ax, x, y; kwargs...)
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
        node_uuid::Union{AbstractVector, Nothing} = nothing,
        glyph::Union{AbstractMatrix, Nothing} = nothing,
        at::Symbol = :start,
        kwargs...,
    ) -> Nothing

Add one PhyloPic silhouette per datum to `ax`, anchored relative to a range
`(xstart[i], xstop[i])` at vertical position `y[i]`.

This is the **PhyloPic-native** range-based convenience wrapper for range
data (e.g. stratigraphic intervals).  It computes anchor x coordinates from
the range endpoints and then calls [`augment_phylopic!`](@ref).

## Arguments

- `xstart`, `xstop`: range endpoints in axis data units.
- `y`: vertical coordinate for each datum.
- `node_uuid`: per-datum PhyloPic node UUID strings (see
  [`augment_phylopic!`](@ref)).
- `glyph`: a single pre-loaded image matrix broadcast to all data points.
- `at`: where along the range to anchor the glyph.
  - `:start` (default) — anchor at `xstart[i]`.
  - `:stop` — anchor at `xstop[i]`.
  - `:midpoint` — anchor at `(xstart[i] + xstop[i]) / 2`.
- All remaining keyword arguments are forwarded to [`augment_phylopic!`](@ref).

## Returns

`Nothing`.

## Examples

```julia
using PhyloPicMakie, CairoMakie

node_uuids = ["3c4b8687-2401-4e5b-afb5-19aa3e7e8b26",
              "7fb20e1a-3a19-4e8c-beb9-3e7ffb59c0cf"]
first_app  = [68.0, 68.0]
last_app   = [66.0, 66.0]

fig = Figure()
ax  = Axis(fig[1, 1]; xreversed = true)
augment_phylopic_ranges!(
    ax, first_app, last_app, collect(1.0:2.0);
    node_uuid  = node_uuids,
    at         = :start,
    glyph_size = 0.4,
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
    length(xstop) == n || throw(ArgumentError(
        "augment_phylopic_ranges!: `xstart` and `xstop` must have the same length."
    ))
    length(y) == n || throw(ArgumentError(
        "augment_phylopic_ranges!: `y` must have the same length as `xstart`."
    ))
    xs = [_range_anchor(Float64(xstart[i]), Float64(xstop[i]), at) for i in 1:n]
    augment_phylopic!(ax, xs, y; kwargs...)
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
    augment_phylopic_ranges!(ax, xstart, xstop, y; kwargs...)
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
        node_uuid = nothing,
        glyph = nothing,
        kwargs...,
    ) -> Nothing

Table-oriented variant of [`augment_phylopic!`](@ref).

Extracts coordinate and node-UUID columns from any Tables.jl-compatible
source (e.g. a `DataFrame`) and forwards to the vector API.

## Arguments

- `table`: any object supporting `propertynames` / `getproperty`.
- `x`: column selector for x coordinates (Symbol, String, or Integer).
- `y`: column selector for y coordinates.
- `node_uuid`: column selector for PhyloPic node UUID strings, or `nothing`
  if `glyph` is used instead.
- `glyph`: a single pre-loaded image matrix broadcast to all rows.
- All remaining keyword arguments are forwarded to the vector
  [`augment_phylopic!`](@ref).

## Returns

`Nothing`.

## Examples

```julia
using PhyloPicMakie, CairoMakie, DataFrames

df = DataFrame(
    x    = [1.0, 2.0],
    y    = [1.0, 2.0],
    uuid = ["3c4b8687-2401-4e5b-afb5-19aa3e7e8b26",
            "7fb20e1a-3a19-4e8c-beb9-3e7ffb59c0cf"],
)

fig = Figure()
ax  = Axis(fig[1, 1])
augment_phylopic!(ax, df; x = :x, y = :y, node_uuid = :uuid, glyph_size = 0.4)
```
"""
function augment_phylopic!(
    ax::Makie.Axis,
    table;
    x,
    y,
    node_uuid = nothing,
    glyph::Union{AbstractMatrix, Nothing} = nothing,
    kwargs...,
)::Nothing
    xs    = _extract_column(table, x)
    ys    = _extract_column(table, y)
    uuids = isnothing(node_uuid) ? nothing : _extract_column(table, node_uuid)
    augment_phylopic!(ax, xs, ys; node_uuid = uuids, glyph = glyph, kwargs...)
end

"""
    augment_phylopic(ax::Makie.Axis, table; kwargs...) -> Nothing

Non-mutating alias for the table-based [`augment_phylopic!`](@ref).

See [`augment_phylopic!`](@ref) for full documentation.
"""
function augment_phylopic(ax::Makie.Axis, table; kwargs...)::Nothing
    augment_phylopic!(ax, table; kwargs...)
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
        node_uuid = nothing,
        glyph = nothing,
        at::Symbol = :start,
        kwargs...,
    ) -> Nothing

Table-oriented variant of [`augment_phylopic_ranges!`](@ref).

Extracts range and node-UUID columns from a Tables.jl-compatible source
and forwards to the vector range API.

## Arguments

- `table`: any object supporting `propertynames` / `getproperty`.
- `xstart`, `xstop`: column selectors for the range endpoints.
- `y`: column selector for the vertical coordinate.
- `node_uuid`: column selector for PhyloPic node UUID strings, or `nothing`
  if `glyph` is used.
- `glyph`: a single pre-loaded image matrix broadcast to all rows.
- `at`: `:start` (default), `:stop`, or `:midpoint`.
- All remaining keyword arguments are forwarded to the vector API.

## Returns

`Nothing`.

## Examples

```julia
using PhyloPicMakie, CairoMakie, DataFrames

df = DataFrame(
    first_app = [68.0, 68.0],
    last_app  = [66.0, 66.0],
    row       = [1.0, 2.0],
    uuid      = ["3c4b8687-2401-4e5b-afb5-19aa3e7e8b26",
                 "7fb20e1a-3a19-4e8c-beb9-3e7ffb59c0cf"],
)

fig = Figure()
ax  = Axis(fig[1, 1]; xreversed = true)
augment_phylopic_ranges!(
    ax, df;
    xstart    = :first_app,
    xstop     = :last_app,
    y         = :row,
    node_uuid = :uuid,
    at        = :start,
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
    node_uuid = nothing,
    glyph::Union{AbstractMatrix, Nothing} = nothing,
    at::Symbol = :start,
    kwargs...,
)::Nothing
    xs    = _extract_column(table, xstart)
    xe    = _extract_column(table, xstop)
    ys    = _extract_column(table, y)
    uuids = isnothing(node_uuid) ? nothing : _extract_column(table, node_uuid)
    augment_phylopic_ranges!(ax, xs, xe, ys; node_uuid = uuids, glyph = glyph, at = at, kwargs...)
end

"""
    augment_phylopic_ranges(ax::Makie.Axis, table; kwargs...) -> Nothing

Non-mutating alias for the table-based [`augment_phylopic_ranges!`](@ref).

See [`augment_phylopic_ranges!`](@ref) for full documentation.
"""
function augment_phylopic_ranges(ax::Makie.Axis, table; kwargs...)::Nothing
    augment_phylopic_ranges!(ax, table; kwargs...)
end
