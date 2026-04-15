
# ---------------------------------------------------------------------------
# PhyloPicMakie — thumbnail grid rendering
#
# Provides a gallery-style view of PhyloPic thumbnails.  All helpers here are
# generic: they work with PhyloPicDB types (PhyloPicImage, PhyloPicNode) and
# Makie, with no dependency on PaleobiologyDB.
#
# The low-level entry points take pre-built cell data (images, labels,
# group_sizes) produced by the caller.  PBDB-specific data fetching (resolving
# taxon names → images) lives in PaleobiologyDB.PhyloPicPBDB, which
# calls phylopic_thumbnail_grid! after building the cell arrays.
#
# Public:
#   phylopic_thumbnail_grid!(ax, cell_images, labels, group_sizes; ...) → Nothing
#   phylopic_thumbnail_grid(cell_images, labels, group_sizes; ...)  → Makie.Figure
#
# Internal helpers:
#   _infer_thumbnail_grid_shape, _thumbnail_grid_positions,
#   _thumbnail_grid_axis_limits, _thumbnail_label_position,
#   _draw_thumbnail_placeholder!, _apply_image_selector,
#   _select_image_url, _download_image, _rows_grid_positions,
#   _grouped_grid_total_rows, _grouped_grid_positions,
#   _extract_image_field, _join_fields, _build_label
# ---------------------------------------------------------------------------

import Makie

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS    = 4
const DEFAULT_THUMBNAIL_GRID_CELL_WIDTH     = 1.0
const DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT    = 1.6
const DEFAULT_THUMBNAIL_GRID_GLYPH_FRACTION = 0.55
const DEFAULT_THUMBNAIL_GRID_LABEL_GAP      = 0.10
const DEFAULT_THUMBNAIL_GRID_FONT_SIZE      = 18.0
const DEFAULT_THUMBNAIL_GRID_FIGURE_MARGIN_PX = 80
const DEFAULT_THUMBNAIL_GRID_CELL_WIDTH_PX  = 320
const DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT_PX = 260
const DEFAULT_THUMBNAIL_GRID_TITLE_GAP      = 0.12

"""
Valid `image_layout` symbols for the thumbnail grid.
"""
const VALID_IMAGE_LAYOUTS = (:flat, :blocks, :rows)

"""
All field symbols recognised by [`_extract_image_field`](@ref) and accepted in
the `AbstractVector{Symbol}` form of `image_label`.

Includes virtual fields computed from the cell context:
- `:taxon_name` — the taxon name string supplied by the caller.
- `:index`      — position of the image within a taxon's group.

And every labelable field of [`PhyloPicDB.PhyloPicImage`](@ref), including
`:node_name` (preferred name of the node at `specific_node_uuid`).

This constant is an alias for [`PhyloPicDB.PHYLOPIC_IMAGE_ALL_LABEL_FIELDS`](@ref).
"""
const ALLFIELDS_IMAGE_LABEL = PhyloPicDB.PHYLOPIC_IMAGE_ALL_LABEL_FIELDS

"""
Field symbols used by the `:BASICFIELDS` image label preset: image index,
node name, and taxon name.

This constant is an alias for
[`PhyloPicDB.PHYLOPIC_IMAGE_BASIC_LABEL_FIELDS`](@ref).
"""
const BASICFIELDS_IMAGE_LABEL = PhyloPicDB.PHYLOPIC_IMAGE_BASIC_LABEL_FIELDS

# ---------------------------------------------------------------------------
# Grid geometry helpers
# ---------------------------------------------------------------------------

"""
    _infer_thumbnail_grid_shape(
        n::Integer;
        ncols::Union{Integer, Nothing} = nothing,
        nrows::Union{Integer, Nothing} = nothing,
    ) -> Tuple{Int, Int}

Infer a rectangular grid shape `(ncols, nrows)` for `n` thumbnails.

If neither dimension is supplied, the function chooses a compact grid while
capping the default number of columns to keep the plot width bounded for
screen viewing.  This makes larger galleries grow vertically rather than
expanding indefinitely across the screen.

Throws `ArgumentError` if either requested dimension is non-positive or if the
requested grid cannot accommodate `n` taxa.
"""
function _infer_thumbnail_grid_shape(
    n::Integer;
    ncols::Union{Integer, Nothing} = nothing,
    nrows::Union{Integer, Nothing} = nothing,
)::Tuple{Int, Int}
    n ≥ 0 || throw(ArgumentError(
        "phylopic_thumbnail_grid: `n` must be non-negative. Got $n."
    ))

    if !isnothing(ncols)
        ncols > 0 || throw(ArgumentError(
            "phylopic_thumbnail_grid: `ncols` must be positive. Got $ncols."
        ))
    end
    if !isnothing(nrows)
        nrows > 0 || throw(ArgumentError(
            "phylopic_thumbnail_grid: `nrows` must be positive. Got $nrows."
        ))
    end

    if n == 0
        cols = isnothing(ncols) ? 1 : Int(ncols)
        rows = isnothing(nrows) ? 1 : Int(nrows)
        return (cols, rows)
    end

    if !isnothing(ncols) && !isnothing(nrows)
        ncols * nrows ≥ n || throw(ArgumentError(
            "phylopic_thumbnail_grid: grid with ncols = $ncols and nrows = $nrows " *
            "cannot accommodate $n taxa."
        ))
        return (Int(ncols), Int(nrows))
    elseif !isnothing(ncols)
        cols = Int(ncols)
        rows = cld(n, cols)
        return (cols, rows)
    elseif !isnothing(nrows)
        rows = Int(nrows)
        cols = cld(n, rows)
        return (cols, rows)
    else
        cols = min(DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS, max(1, ceil(Int, sqrt(n))))
        rows = cld(n, cols)
        return (cols, rows)
    end
end

"""
    _thumbnail_grid_positions(
        n::Integer,
        ncols::Integer,
        nrows::Integer;
        cell_width::Real,
        cell_height::Real,
        glyph_y_in_row::Real = Float64(cell_height) / 2.0,
    ) -> Vector{Tuple{Float64, Float64}}

Return the `(x, y)` glyph-centre coordinates for `n` thumbnail cells laid out
in a row-major grid.

`cell_height` controls the row spacing (distance between row baselines).
`glyph_y_in_row` is the distance from a row's bottom edge to the glyph centre;
it defaults to `cell_height / 2` (centred glyph).  Pass a larger value (e.g.
`eff_cell_height - 0.5 * nominal_cell_height`) to push the glyph toward the top
of an expanded row, keeping label space below.
"""
function _thumbnail_grid_positions(
    n::Integer,
    ncols::Integer,
    nrows::Integer;
    cell_width::Real,
    cell_height::Real,
    glyph_y_in_row::Real = Float64(cell_height) / 2.0,
)::Vector{Tuple{Float64, Float64}}
    positions = Vector{Tuple{Float64, Float64}}(undef, n)
    for i in 1:n
        row_index = cld(i, ncols)
        col_index = ((i - 1) % ncols) + 1
        x = (Float64(col_index) - 0.5) * Float64(cell_width)
        y = Float64(nrows - row_index) * Float64(cell_height) + Float64(glyph_y_in_row)
        positions[i] = (x, y)
    end
    return positions
end

"""
    _thumbnail_grid_axis_limits(
        ncols::Integer,
        nrows::Integer;
        cell_width::Real,
        cell_height::Real,
    ) -> NTuple{4, Float64}

Return `(xmin, xmax, ymin, ymax)` covering the full thumbnail grid.
"""
function _thumbnail_grid_axis_limits(
    ncols::Integer,
    nrows::Integer;
    cell_width::Real,
    cell_height::Real,
)::NTuple{4, Float64}
    xmin = 0.0
    xmax = Float64(ncols) * Float64(cell_width)
    ymin = 0.0
    ymax = Float64(nrows) * Float64(cell_height)
    return (xmin, xmax, ymin, ymax)
end

"""
    _thumbnail_label_position(
        x::Real,
        y::Real;
        cell_height::Real,
        glyph_fraction::Real,
        label_gap::Real,
    ) -> Tuple{Float64, Float64}

Return the label anchor position beneath a thumbnail centred at `(x, y)`.
"""
function _thumbnail_label_position(
    x::Real,
    y::Real;
    cell_height::Real,
    glyph_fraction::Real,
    label_gap::Real,
)::Tuple{Float64, Float64}
    glyph_half_height = Float64(cell_height) * Float64(glyph_fraction) / 2
    label_y = Float64(y) - glyph_half_height - Float64(label_gap)
    return (Float64(x), label_y)
end

"""
    _draw_thumbnail_placeholder!(
        ax::Makie.Axis,
        x::Real,
        y::Real;
        glyph_size::Real,
    ) -> Nothing

Draw a placeholder rectangle for a missing thumbnail.
"""
function _draw_thumbnail_placeholder!(
    ax::Makie.Axis,
    x::Real,
    y::Real;
    glyph_size::Real,
)::Nothing
    x_lo, x_hi, y_lo, y_hi = _compute_image_bbox(
        x,
        y,
        1,
        1;
        glyph_size = glyph_size,
        aspect = :stretch,
        placement = :center,
        xoffset = 0.0,
        yoffset = 0.0,
    )
    Makie.poly!(
        ax,
        Makie.Rect2f(x_lo, y_lo, x_hi - x_lo, y_hi - y_lo);
        color = (:lightgray, 0.5),
        strokecolor = :gray,
        strokewidth = 0.75,
    )
    return nothing
end

# ---------------------------------------------------------------------------
# Image selection and download helpers
# ---------------------------------------------------------------------------

"""
    _apply_image_selector(
        pool::AbstractVector{PhyloPicDB.PhyloPicImage},
        image_selector,
    ) -> Vector{PhyloPicDB.PhyloPicImage}

Apply `image_selector` to `pool` and always return a
`Vector{PhyloPicDB.PhyloPicImage}`.

This is a pure function — no I/O, no network calls.

| `image_selector` | Result |
|---|---|
| `nothing` | All images in `pool` |
| `:first` | `[pool[1]]`, or `[]` if empty |
| `Int n` | `[pool[n]]`, or `[]` if out of bounds |
| Callable `f` | `f(pool)`; must return `AbstractVector{PhyloPicDB.PhyloPicImage}` |

Callable results that are a single `PhyloPicDB.PhyloPicImage` are coerced to a
1-element vector as a convenience.  Any other return type yields `[]`.
"""
function _apply_image_selector(
    pool::AbstractVector{PhyloPicDB.PhyloPicImage},
    image_selector,
)::Vector{PhyloPicDB.PhyloPicImage}
    isnothing(image_selector) && return collect(pool)
    if image_selector === :first
        return isempty(pool) ? PhyloPicDB.PhyloPicImage[] : [pool[1]]
    end
    if image_selector isa Int
        n = image_selector
        return (1 ≤ n ≤ length(pool)) ? [pool[n]] : PhyloPicDB.PhyloPicImage[]
    end
    # Callable — must return AbstractVector{PhyloPicImage}.
    result = image_selector(pool)
    result isa AbstractVector && return collect(PhyloPicDB.PhyloPicImage, result)
    # Coerce single-image return defensively.
    result isa PhyloPicDB.PhyloPicImage && return [result]
    return PhyloPicDB.PhyloPicImage[]
end

"""
    _select_image_url(
        img::PhyloPicDB.PhyloPicImage,
        image_rendering::Symbol,
    ) -> Union{String, Missing}

Return the URL for `img` corresponding to `image_rendering`.

| `image_rendering` | `PhyloPicImage` field | Format |
|---|---|---|
| `:thumbnail`   | `thumbnail_url`   | PNG; square thumbnail, largest available (default) |
| `:raster`      | `raster_url`      | PNG; full-resolution, largest available |
| `:og_image`    | `og_image_url`    | PNG; Open Graph social-media preview |
| `:vector`      | `vector_url`      | SVG; black silhouette on transparent — requires SVG-capable `FileIO` plugin |
| `:source_file` | `source_file_url` | SVG or raster — format matches the original upload |

Returns `missing` when the selected field is absent on `img`.
Throws `ArgumentError` for unrecognised symbols.
"""
function _select_image_url(
    img::PhyloPicDB.PhyloPicImage,
    image_rendering::Symbol,
)::Union{String, Missing}
    image_rendering === :thumbnail   && return img.thumbnail_url
    image_rendering === :raster      && return img.raster_url
    image_rendering === :og_image    && return img.og_image_url
    image_rendering === :vector      && return img.vector_url
    image_rendering === :source_file && return img.source_file_url
    throw(ArgumentError(
        "_select_image_url: unknown `image_rendering` value `:$image_rendering`. " *
        "Valid values: $(join(string.(':', PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS), ", "))."
    ))
end

"""
    _download_image(
        img::PhyloPicDB.PhyloPicImage,
        label::AbstractString;
        image_rendering::Symbol = :thumbnail,
    ) -> Union{Matrix{RGBA{N0f8}}, Nothing}

Download and decode the image for `img` selected by `image_rendering`.

Returns `nothing` when the URL for the selected rendering is `missing` or the
download fails.  Download failures are logged via `@warn` with `label`
included for diagnostics.

See [`_select_image_url`](@ref) for the full `image_rendering` symbol table.
"""
function _download_image(
    img::PhyloPicDB.PhyloPicImage,
    label::AbstractString;
    image_rendering::Symbol = :thumbnail,
)::Union{Matrix{RGBA{N0f8}}, Nothing}
    url = _select_image_url(img, image_rendering)
    ismissing(url) && return nothing
    try
        return _load_phylopic_image(url)
    catch err
        @warn "phylopic_thumbnail_grid: could not load image for \"$label\"" exception = err
        return nothing
    end
end

# ---------------------------------------------------------------------------
# Grid position helpers for non-flat layouts
# ---------------------------------------------------------------------------

"""
    _rows_grid_positions(
        group_sizes::AbstractVector{<:Integer};
        cell_width::Real,
        cell_height::Real,
    ) -> Tuple{Vector{Tuple{Float64,Float64}}, Int, Int}

Return `(positions, total_rows, total_cols)` for a rows layout where each
non-empty taxon group occupies exactly one row, images placed left to right
with no wrapping.

`total_rows` = number of non-empty groups.
`total_cols` = size of the largest group (grid is as wide as the widest row).
"""
function _rows_grid_positions(
    group_sizes::AbstractVector{<:Integer};
    cell_width::Real,
    cell_height::Real,
    glyph_y_in_row::Real = Float64(cell_height) / 2.0,
)::Tuple{Vector{Tuple{Float64, Float64}}, Int, Int}
    non_empty  = [g for g in group_sizes if g > 0]
    total_rows = length(non_empty)
    total_cols = isempty(non_empty) ? 1 : maximum(non_empty)
    positions  = Tuple{Float64, Float64}[]
    row_idx    = 0
    for g in group_sizes
        g == 0 && continue
        for j in 1:g
            x = (Float64(j) - 0.5) * Float64(cell_width)
            y = Float64(total_rows - 1 - row_idx) * Float64(cell_height) + Float64(glyph_y_in_row)
            push!(positions, (x, y))
        end
        row_idx += 1
    end
    return positions, max(total_rows, 1), max(total_cols, 1)
end

"""
    _grouped_grid_total_rows(
        group_sizes::AbstractVector{<:Integer},
        ncols::Integer,
    ) -> Int

Return the total number of grid rows required for a grouped layout where each
non-empty group starts on a fresh row and wraps at `ncols`.
"""
function _grouped_grid_total_rows(
    group_sizes::AbstractVector{<:Integer},
    ncols::Integer,
)::Int
    return sum(cld(g, ncols) for g in group_sizes if g > 0; init = 0)
end

"""
    _grouped_grid_positions(
        group_sizes::AbstractVector{<:Integer},
        ncols::Integer;
        cell_width::Real,
        cell_height::Real,
    ) -> Vector{Tuple{Float64, Float64}}

Return `(x, y)` centre coordinates for a grouped layout where each non-empty
group (taxon) starts on a fresh row.

Within a group, cells are placed left to right and wrap at `ncols`.  A new
group always begins at the leftmost column of the next available row below the
preceding group.
"""
function _grouped_grid_positions(
    group_sizes::AbstractVector{<:Integer},
    ncols::Integer;
    cell_width::Real,
    cell_height::Real,
    glyph_y_in_row::Real = Float64(cell_height) / 2.0,
)::Vector{Tuple{Float64, Float64}}
    total_rows = _grouped_grid_total_rows(group_sizes, ncols)
    positions  = Tuple{Float64, Float64}[]
    row_offset = 0
    for g in group_sizes
        g == 0 && continue
        for j in 1:g
            group_row = cld(j, ncols) - 1
            col_idx   = ((j - 1) % ncols) + 1
            global_r  = row_offset + group_row
            x = (Float64(col_idx) - 0.5) * Float64(cell_width)
            y = Float64(total_rows - 1 - global_r) * Float64(cell_height) + Float64(glyph_y_in_row)
            push!(positions, (x, y))
        end
        row_offset += cld(g, ncols)
    end
    return positions
end

# ---------------------------------------------------------------------------
# Label building helpers
# ---------------------------------------------------------------------------

"""
    _extract_image_field(
        field::Symbol,
        taxon_name::AbstractString,
        k::Int,
        img::PhyloPicDB.PhyloPicImage,
    ) -> Union{String, Missing, Nothing}

Extract a single label field from the grid-cell context.

Virtual fields are computed from the taxon name and image index:
- `:taxon_name` — `taxon_name` (the caller-supplied taxon string)
- `:index`      — `string(k)`

Struct fields mapped directly from `img`:
- `:node_name` — `img.node_name` (preferred name of the node at
  `specific_node_uuid`; `nothing` when not enriched)

All other recognised symbols map directly to the corresponding field of `img`
(see [`ALLFIELDS_IMAGE_LABEL`](@ref) for the full list).  Unrecognised symbols
throw an `ArgumentError`.
"""
function _extract_image_field(
    field::Symbol,
    taxon_name::AbstractString,
    k::Int,
    img::PhyloPicDB.PhyloPicImage,
)::Union{String, Missing, Nothing}
    field === :taxon_name         && return String(taxon_name)
    field === :index              && return string(k)
    field === :node_name          && return img.node_name
    field === :uuid               && return img.uuid
    field === :thumbnail_url      && return img.thumbnail_url
    field === :vector_url         && return img.vector_url
    field === :raster_url         && return img.raster_url
    field === :source_file_url    && return img.source_file_url
    field === :license            && return img.license
    field === :license_url        && return img.license_url
    field === :attribution        && return img.attribution
    field === :contributor        && return img.contributor_href
    field === :specific_node_uuid && return img.specific_node_uuid
    field === :general_node_uuid  && return img.general_node_uuid
    throw(ArgumentError(
        "_extract_image_field: unknown field symbol :$field. " *
        "Valid field symbols: $(join(string.(':', ALLFIELDS_IMAGE_LABEL), ", ")). " *
        "Preset symbols handled by _build_label: :ALLFIELDS, :BASICFIELDS."
    ))
end

"""
    _join_fields(
        fields::AbstractVector{Symbol},
        taxon_name::AbstractString,
        k::Int,
        img::PhyloPicDB.PhyloPicImage,
        sep::AbstractString,
    ) -> String

Collect the values of `fields` for the given cell context, drop entries that
are `missing`, `nothing`, or empty strings, and join the survivors with `sep`.

Calls [`_extract_image_field`](@ref) per symbol; unknown symbols propagate its
`ArgumentError`.
"""
function _join_fields(
    fields::AbstractVector{Symbol},
    taxon_name::AbstractString,
    k::Int,
    img::PhyloPicDB.PhyloPicImage,
    sep::AbstractString,
)::String
    vals = (_extract_image_field(f, taxon_name, k, img) for f in fields)
    parts = String[v::String for v in vals if v isa String && !isempty(v)]
    return join(parts, sep)
end

"""
    _build_label(
        taxon_name::AbstractString,
        k::Int,
        is_multi::Bool,
        img::PhyloPicDB.PhyloPicImage,
        image_label,
        labeljoin::AbstractString,
    ) -> String

Generate the display label for a single grid cell.

## Dispatch on `image_label`

| `image_label` | Label |
|---|---|
| `nothing` | `"taxon"` (single) or `"taxon [k]"` (multi-image group) |
| `:ALLFIELDS` | All fields in [`ALLFIELDS_IMAGE_LABEL`](@ref), joined with `labeljoin`; `missing`/`nothing`/empty omitted |
| `:BASICFIELDS` (default) | `:index`, `:node_name`, `:taxon_name` joined with `labeljoin` |
| Any other `Symbol` | Corresponding image field from [`_extract_image_field`](@ref); falls back to default if `missing`/`nothing` |
| `AbstractVector{Symbol}` | Listed fields joined with `labeljoin`; `missing`/`nothing`/empty omitted |
| Callable `f` | `f(taxon_name, k, img)` — must return a `String` |

`labeljoin` is only applied for vector and preset-expansion cases (`:ALLFIELDS`,
`:BASICFIELDS`, `AbstractVector{Symbol}`); single-symbol and `nothing` cases
produce a single string.  Unrecognized symbols throw `ArgumentError`.
"""
function _build_label(
    taxon_name::AbstractString,
    k::Int,
    is_multi::Bool,
    img::PhyloPicDB.PhyloPicImage,
    image_label,
    labeljoin::AbstractString,
)::String
    isnothing(image_label) && return is_multi ? "$(taxon_name) [$k]" : String(taxon_name)
    if image_label isa Symbol
        image_label === :ALLFIELDS   && return _join_fields(ALLFIELDS_IMAGE_LABEL,  taxon_name, k, img, labeljoin)
        image_label === :BASICFIELDS && return _join_fields(BASICFIELDS_IMAGE_LABEL, taxon_name, k, img, labeljoin)
        # Single structural field — fall back to default if absent.
        val = _extract_image_field(image_label, taxon_name, k, img)
        (ismissing(val) || isnothing(val)) && return is_multi ? "$(taxon_name) [$k]" : String(taxon_name)
        return String(val)
    end
    image_label isa AbstractVector && return _join_fields(image_label, taxon_name, k, img, labeljoin)
    # Callable
    return String(image_label(taxon_name, k, img))
end

# ---------------------------------------------------------------------------
# Generic low-level rendering API
# ---------------------------------------------------------------------------

"""
    phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        cell_images::AbstractVector,
        labels::AbstractVector{<:AbstractString},
        group_sizes::AbstractVector{<:Integer};
        ncols::Union{Integer, Nothing} = nothing,
        nrows::Union{Integer, Nothing} = nothing,
        cell_width::Real = DEFAULT_THUMBNAIL_GRID_CELL_WIDTH,
        cell_height::Real = DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT,
        glyph_fraction::Real = DEFAULT_THUMBNAIL_GRID_GLYPH_FRACTION,
        label_gap::Real = DEFAULT_THUMBNAIL_GRID_LABEL_GAP,
        label_fontsize::Real = DEFAULT_THUMBNAIL_GRID_FONT_SIZE,
        title::Union{AbstractString, Nothing} = nothing,
        title_gap::Real = DEFAULT_THUMBNAIL_GRID_TITLE_GAP,
        on_missing::Symbol = :skip,
        image_interpolate::Bool = true,
        image_layout::Symbol = :blocks,
        label_lines::Union{Int, Nothing} = nothing,
    ) -> Nothing

Render a gallery of PhyloPic silhouettes into the existing Makie `Axis` `ax`
from pre-built cell data.

This is the generic rendering entry point.  It accepts pre-resolved image
matrices, labels, and group sizes; it does not perform any taxon-name
resolution or image fetching.  For the PBDB-specific entry point that takes
taxon names, use `PaleobiologyDB.PhyloPicPBDB.phylopic_thumbnail_grid!`.

## Arguments

- `ax`: Target Makie axis.
- `cell_images`: Flat vector of image matrices (or `nothing` for missing
  images), one per cell.
- `labels`: Display label string for each cell.
- `group_sizes`: Number of cells per taxon group (in input order).  Used to
  determine layout boundaries.  May all be 1 for flat grids.

## Layout keywords

- `ncols`, `nrows`: Explicit grid dimensions.  Supply either, both, or neither.
- `cell_width`, `cell_height`: Nominal cell size in axis data units.
- `glyph_fraction`: Fraction of `cell_height` allocated to the image.
- `label_gap`: Vertical gap between image and text label.
- `label_fontsize`: Font size for cell labels.
- `label_lines`: Override the automatic line-count used to expand cell height
  for multi-line labels.  `nothing` (default) detects the maximum number of
  `'\\n'`-delimited lines across all built labels.
- `title`: Optional axis title.
- `title_gap`: Additional vertical padding reserved for the title.
- `image_layout`: How to arrange cells.
  - `:blocks` (default) — each group starts a new row and wraps at `ncols`.
  - `:rows` — each non-empty group occupies exactly one row.
  - `:flat` — single row-major grid ignoring group boundaries.
- `image_interpolate`: Whether to interpolate pixels when rendering images.

## Missing-image policy

- `on_missing = :skip` (default): skip cells whose image is `nothing`.
- `on_missing = :placeholder`: draw a placeholder rectangle for `nothing` cells.
- `on_missing = :error`: throw when any cell image is `nothing`.

## Returns

`Nothing`.  The plot is added to `ax` by side effect.
"""
function phylopic_thumbnail_grid!(
    ax::Makie.Axis,
    cell_images::AbstractVector,
    labels::AbstractVector{<:AbstractString},
    group_sizes::AbstractVector{<:Integer};
    ncols::Union{Integer, Nothing} = nothing,
    nrows::Union{Integer, Nothing} = nothing,
    cell_width::Real = DEFAULT_THUMBNAIL_GRID_CELL_WIDTH,
    cell_height::Real = DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT,
    glyph_fraction::Real = DEFAULT_THUMBNAIL_GRID_GLYPH_FRACTION,
    label_gap::Real = DEFAULT_THUMBNAIL_GRID_LABEL_GAP,
    label_fontsize::Real = DEFAULT_THUMBNAIL_GRID_FONT_SIZE,
    title::Union{AbstractString, Nothing} = nothing,
    title_gap::Real = DEFAULT_THUMBNAIL_GRID_TITLE_GAP,
    on_missing::Symbol = :skip,
    image_interpolate::Bool = true,
    image_layout::Symbol = :blocks,
    label_lines::Union{Int, Nothing} = nothing,
)::Nothing
    cell_width > 0 || throw(ArgumentError(
        "phylopic_thumbnail_grid!: `cell_width` must be positive. Got $cell_width."
    ))
    cell_height > 0 || throw(ArgumentError(
        "phylopic_thumbnail_grid!: `cell_height` must be positive. Got $cell_height."
    ))
    0 < glyph_fraction < 1 || throw(ArgumentError(
        "phylopic_thumbnail_grid!: `glyph_fraction` must lie strictly between 0 and 1. " *
        "Got $glyph_fraction."
    ))
    label_gap ≥ 0 || throw(ArgumentError(
        "phylopic_thumbnail_grid!: `label_gap` must be non-negative. Got $label_gap."
    ))
    label_fontsize > 0 || throw(ArgumentError(
        "phylopic_thumbnail_grid!: `label_fontsize` must be positive. Got $label_fontsize."
    ))
    title_gap ≥ 0 || throw(ArgumentError(
        "phylopic_thumbnail_grid!: `title_gap` must be non-negative. Got $title_gap."
    ))
    on_missing ∈ VALID_ON_MISSING || throw(ArgumentError(
        "phylopic_thumbnail_grid!: unknown `on_missing` value `$on_missing`. " *
        "Valid values: $(join(VALID_ON_MISSING, ", "))."
    ))
    image_layout ∈ VALID_IMAGE_LAYOUTS || throw(ArgumentError(
        "phylopic_thumbnail_grid!: unknown `image_layout` value `$image_layout`. " *
        "Valid values: $(join(VALID_IMAGE_LAYOUTS, ", "))."
    ))

    total_cells = length(cell_images)

    # Compute effective cell height to accommodate multi-line labels.
    # slls = data-unit height allocated to one label line by the default geometry:
    #   slls = 0.5 * cell_height * (1 - glyph_fraction) - label_gap
    # For N label lines the cell needs to be taller by (N-1)*slls so that all
    # lines fit below the glyph.  The glyph is shifted to the top of the expanded
    # cell (glyph_y_in_row = eff_cell_height - 0.5*cell_height), keeping the same
    # headroom above the glyph as in the standard layout.
    auto_lines = isempty(labels) ? 1 :
        maximum(count('\n', lbl) + 1 for lbl in labels)
    n_label_lines   = isnothing(label_lines) ? auto_lines : max(1, Int(label_lines))
    slls            = Float64(cell_height) * (1.0 - Float64(glyph_fraction)) / 2.0 -
                      Float64(label_gap)
    eff_cell_height = Float64(cell_height) +
                      Float64(n_label_lines - 1) * max(0.0, slls)
    # Distance from a row's bottom edge to the glyph centre (top-biased placement).
    glyph_y_in_row  = eff_cell_height - 0.5 * Float64(cell_height)

    # Compute cell positions and grid dimensions according to layout.
    local positions::Vector{Tuple{Float64, Float64}}
    cols, rows = if image_layout === :flat
        c, r = _infer_thumbnail_grid_shape(total_cells; ncols = ncols, nrows = nrows)
        positions = _thumbnail_grid_positions(total_cells, c, r;
            cell_width, cell_height = eff_cell_height, glyph_y_in_row)
        c, r
    elseif image_layout === :blocks
        bc = isnothing(ncols) ? DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS : Int(ncols)
        positions = _grouped_grid_positions(group_sizes, bc;
            cell_width, cell_height = eff_cell_height, glyph_y_in_row)
        bc, max(_grouped_grid_total_rows(group_sizes, bc), 1)
    else  # :rows
        pos, r, c = _rows_grid_positions(group_sizes;
            cell_width, cell_height = eff_cell_height, glyph_y_in_row)
        positions = pos
        c, r
    end

    glyph_size = Float64(cell_height) * Float64(glyph_fraction) / 2

    for i in 1:total_cells
        x, y  = positions[i]
        img   = cell_images[i]
        label = labels[i]

        if isnothing(img)
            if on_missing === :error
                throw(ErrorException(
                    "phylopic_thumbnail_grid!: missing thumbnail for \"$label\"."
                ))
            elseif on_missing === :placeholder
                _draw_thumbnail_placeholder!(ax, x, y; glyph_size = glyph_size)
            end
        else
            h_px, w_px = size(img)
            x_lo, x_hi, y_lo, y_hi = _compute_image_bbox(
                x,
                y,
                w_px,
                h_px;
                glyph_size = glyph_size,
                aspect = :preserve,
                placement = :center,
                xoffset = 0.0,
                yoffset = 0.0,
            )
            Makie.image!(
                ax,
                (x_lo, x_hi),
                (y_lo, y_hi),
                rotr90(img);
                interpolate = image_interpolate,
            )
        end

        label_x, label_y = _thumbnail_label_position(
            x,
            y;
            cell_height = cell_height,
            glyph_fraction = glyph_fraction,
            label_gap = label_gap,
        )
        Makie.text!(
            ax,
            label;
            position = (label_x, label_y),
            align = (:center, :top),
            fontsize = label_fontsize,
        )
    end

    xmin, xmax, ymin, ymax = _thumbnail_grid_axis_limits(
        cols,
        rows;
        cell_width  = cell_width,
        cell_height = eff_cell_height,
    )
    Makie.xlims!(ax, xmin, xmax)
    Makie.ylims!(ax, ymin, ymax)

    Makie.hidedecorations!(ax)
    Makie.hidespines!(ax)
    ax.title = isnothing(title) ? "" : String(title)
    ax.titlegap = Float64(label_fontsize) * Float64(title_gap)

    return nothing
end

"""
    phylopic_thumbnail_grid(
        cell_images::AbstractVector,
        labels::AbstractVector{<:AbstractString},
        group_sizes::AbstractVector{<:Integer};
        figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
        axis = NamedTuple(),
        ncols::Union{Integer, Nothing} = nothing,
        kwargs...,
    ) -> Makie.Figure

Create a new figure containing a thumbnail gallery from pre-built cell data.

The initial figure size is estimated from `DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS`
(width) and cell count (height).  After the bang variant places all images both
dimensions are corrected from the actual axis limits.  Pass `figure_size` to
fix both dimensions and bypass the auto-resize.

See [`phylopic_thumbnail_grid!`](@ref) for keyword documentation.

Returns the created `Makie.Figure`.
"""
function phylopic_thumbnail_grid(
    cell_images::AbstractVector,
    labels::AbstractVector{<:AbstractString},
    group_sizes::AbstractVector{<:Integer};
    figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
    axis = NamedTuple(),
    ncols::Union{Integer, Nothing} = nothing,
    kwargs...,
)::Makie.Figure
    init_cols = isnothing(ncols) ? DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS : Int(ncols)
    init_rows = max(length(cell_images), 1)

    init_fig_size = if isnothing(figure_size)
        (
            init_cols * DEFAULT_THUMBNAIL_GRID_CELL_WIDTH_PX  + DEFAULT_THUMBNAIL_GRID_FIGURE_MARGIN_PX,
            init_rows * DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT_PX + DEFAULT_THUMBNAIL_GRID_FIGURE_MARGIN_PX,
        )
    else
        figure_size
    end

    fig = Makie.Figure(size = init_fig_size)
    ax  = Makie.Axis(fig[1, 1]; axis...)
    phylopic_thumbnail_grid!(ax, cell_images, labels, group_sizes; ncols, kwargs...)

    if isnothing(figure_size)
        xhi = Float64(ax.limits[][1][2])
        yhi = Float64(ax.limits[][2][2])
        px_per_w = Float64(DEFAULT_THUMBNAIL_GRID_CELL_WIDTH_PX)  / DEFAULT_THUMBNAIL_GRID_CELL_WIDTH
        px_per_h = Float64(DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT_PX) / DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT
        new_w = round(Int, xhi * px_per_w) + DEFAULT_THUMBNAIL_GRID_FIGURE_MARGIN_PX
        new_h = round(Int, yhi * px_per_h) + DEFAULT_THUMBNAIL_GRID_FIGURE_MARGIN_PX
        Makie.resize!(fig, new_w, new_h)
    end

    return fig
end
