
# ---------------------------------------------------------------------------
# PhyloPicMakie — rendering: augment_phylopic! and all public variants
#
# All public functions delegate to _augment_phylopic_core! after resolving
# the image source and computing anchor coordinates.
#
# Call graph:
#
#   augment_phylopic  / augment_phylopic!  (vector API)
#   augment_phylopic  / augment_phylopic!  (table API)
#       └─► _augment_phylopic_core!(ax, xs, ys, images; kwargs...)
#               ├─ _compute_image_bbox(...)       from _coordinates.jl
#               └─ Makie.image!(ax, ...)
#
#   augment_phylopic_ranges  / augment_phylopic_ranges!  (vector API)
#   augment_phylopic_ranges  / augment_phylopic_ranges!  (table API)
#       └─► augment_phylopic!(ax, xs_anchor, ys; ...)   (after _range_anchor)
#
# ---------------------------------------------------------------------------

import Makie
using PaleobiologyDB.Taxonomy: acquire_phylopic

# ---------------------------------------------------------------------------
# Internal: resolve images for a vector of taxa / glyphs
# ---------------------------------------------------------------------------

"""
    _resolve_images(
        taxon::Union{AbstractVector, Nothing},
        glyph::Union{AbstractMatrix{<:Colorant}, Nothing},
        n::Integer,
    ) -> Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}

For each of the `n` data points, return either a decoded image matrix or
`nothing` (when the image could not be resolved).

Exactly one of `taxon` or `glyph` must be non-`nothing`:
- If `glyph` is provided, it is broadcast to all `n` points.
- If `taxon` is provided, `acquire_phylopic` is called for each unique name
  and the thumbnail is downloaded via `_load_phylopic_image`.
"""
function _resolve_images(
    taxon::Union{AbstractVector, Nothing},
    glyph::Union{AbstractMatrix, Nothing},
    n::Integer,
)::Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}
    if !isnothing(glyph)
        # Broadcast the single pre-loaded image to every data point.
        img_rgba = Matrix{RGBA{N0f8}}(RGBA{N0f8}.(glyph))
        return fill(img_rgba, n)
    end

    isnothing(taxon) && throw(ArgumentError(
        "augment_phylopic: one of `taxon` or `glyph` must be provided."
    ))
    length(taxon) == n || throw(ArgumentError(
        "augment_phylopic: `taxon` length ($(length(taxon))) must match " *
        "coordinate length ($n)."
    ))

    # Deduplicate: call acquire_phylopic once per unique non-missing name.
    unique_names = unique(skipmissing(taxon))
    url_cache = Dict{String, Union{String, Missing}}()
    for name in unique_names
        s = string(name)
        isempty(strip(s)) && continue
        rec = acquire_phylopic(s)
        # The field is prefixed with "phylopic_" by default
        url_cache[s] = get(rec, :phylopic_thumbnail, missing)
    end

    results = Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}(undef, n)
    for i in 1:n
        v = taxon[i]
        if ismissing(v)
            results[i] = nothing
            continue
        end
        s = string(v)
        if isempty(strip(s))
            results[i] = nothing
            continue
        end
        url = get(url_cache, s, missing)
        if ismissing(url)
            results[i] = nothing
        else
            try
                results[i] = _load_phylopic_image(url)
            catch err
                @warn "augment_phylopic: could not load image for \"$s\"" exception = err
                results[i] = nothing
            end
        end
    end
    return results
end

# ---------------------------------------------------------------------------
# Internal: core rendering loop
# ---------------------------------------------------------------------------

"""
    _augment_phylopic_core!(
        ax, xs, ys, images;
        glyph_size, aspect, placement, xoffset, yoffset,
        rotation, mirror, on_missing,
    ) -> Nothing

Add one `image!` call per data point to `ax`.

`images` is a `Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}` — `nothing`
entries are handled according to `on_missing`.
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

    for i in 1:n
        img = images[i]

        if isnothing(img)
            if on_missing === :error
                throw(ErrorException(
                    "augment_phylopic: missing image for data point $i " *
                    "(on_missing = :error)."
                ))
            elseif on_missing === :placeholder
                # Draw a small grey rectangle as a stand-in.
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

        # Compute bounding box (after rotation the dimensions may swap)
        h_px, w_px = size(rendered)   # after rotr90, height and width are swapped
        x_lo, x_hi, y_lo, y_hi = _compute_image_bbox(
            xs[i], ys[i], w_px, h_px;
            glyph_size = glyph_size,
            aspect = aspect,
            placement = placement,
            xoffset = xoffset,
            yoffset = yoffset,
        )

        # Makie.image! expects column-major order: apply rotr90 so
        # image rows become plot columns (standard Makie convention).
        Makie.image!(
            ax,
            (x_lo, x_hi),
            (y_lo, y_hi),
            rotr90(rendered);
            interpolate = true,
        )
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Public: core vector API
# ---------------------------------------------------------------------------

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
        clip::Bool = true,
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
  [`PaleobiologyDB.Taxonomy.acquire_phylopic`](@ref)).  Missing or empty
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

- `rotation`: clockwise rotation in degrees.  Supported values: `0`, `90`,
  `180`, `270` (and their negatives / modulo equivalents).  Default `0.0`.
- `mirror`: if `true`, flip the glyph horizontally before rendering.
- `clip`: if `true` (default), let Makie clip images to the axis bounds
  automatically (current behaviour — explicit bounding-box intersection is
  not yet implemented).

### Missing-value policy

- `on_missing`: how to handle data points for which no image is available.
  `:skip` (default) silently omits the glyph; `:error` throws; `:placeholder`
  draws a small grey rectangle at the glyph position.

## Returns

`Nothing`.  The glyphs are added as side-effects to `ax`.

## Examples

```julia
using PaleobiologyDB, PaleobiologyDB.PhyloPicMakie
using CairoMakie, FileIO

fig = Figure()
ax  = Axis(fig[1, 1])
lines!(ax, [68.0, 66.0], [1, 1])

augment_phylopic!(
    ax,
    [68.0],
    [1.0];
    taxon     = ["Tyrannosaurus"],
    glyph_size = 0.4,
    placement = :left,
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
    clip::Bool = true,
    on_missing::Symbol = :skip,
)::Nothing
    n = length(x)
    length(y) == n || throw(ArgumentError(
        "augment_phylopic!: `x` and `y` must have the same length."
    ))
    images = _resolve_images(taxon, glyph, n)
    _augment_phylopic_core!(
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
        clip::Bool = true,
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
using PaleobiologyDB, PaleobiologyDB.PhyloPicMakie
using CairoMakie, FileIO

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
    length(xstop) == n || throw(ArgumentError(
        "augment_phylopic_ranges!: `xstart` and `xstop` must have the same length."
    ))
    length(y) == n || throw(ArgumentError(
        "augment_phylopic_ranges!: `y` must have the same length as `xstart`."
    ))
    xs = [_range_anchor(xstart[i], xstop[i], at) for i in 1:n]
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
# Internal: table column extraction
# ---------------------------------------------------------------------------

"""
    _extract_column(table, col_selector) -> AbstractVector

Extract a column from a table-like object using `col_selector`, which may be
a `Symbol` or `String` (column name) or `Integer` (column index).

Works with any object that supports `propertynames` / `getproperty` (e.g.
`DataFrame`), as well as any object supporting integer indexing of column
vectors.

Throws `ArgumentError` if the column is not found.
"""
function _extract_column(table, col_selector)::AbstractVector
    if col_selector isa Symbol
        available = propertynames(table)
        col_selector ∈ available ||
            throw(ArgumentError(
                "augment_phylopic: column `$col_selector` not found. " *
                "Available columns: " * join(string.(available), ", ") * "."
            ))
        return getproperty(table, col_selector)
    elseif col_selector isa AbstractString
        return _extract_column(table, Symbol(col_selector))
    elseif col_selector isa Integer
        available = propertynames(table)
        1 ≤ col_selector ≤ length(available) ||
            throw(ArgumentError(
                "augment_phylopic: column index $col_selector is out of range " *
                "(table has $(length(available)) columns)."
            ))
        return getproperty(table, available[col_selector])
    else
        throw(ArgumentError(
            "augment_phylopic: column selector must be a Symbol, String, or Integer. " *
            "Got $(typeof(col_selector))."
        ))
    end
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
using PaleobiologyDB, PaleobiologyDB.PhyloPicMakie
using CairoMakie, FileIO, DataFrames

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
    xs     = _extract_column(table, x)
    ys     = _extract_column(table, y)
    taxa   = isnothing(taxon) ? nothing : _extract_column(table, taxon)
    augment_phylopic!(ax, xs, ys; taxon = taxa, glyph = glyph, kwargs...)
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
using PaleobiologyDB, PaleobiologyDB.PhyloPicMakie
using CairoMakie, FileIO, DataFrames

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
    xs     = _extract_column(table, xstart)
    xe     = _extract_column(table, xstop)
    ys     = _extract_column(table, y)
    taxa   = isnothing(taxon) ? nothing : _extract_column(table, taxon)
    augment_phylopic_ranges!(ax, xs, xe, ys; taxon = taxa, glyph = glyph, at = at, kwargs...)
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
    augment_phylopic_ranges!(ax, table; kwargs...)
end
