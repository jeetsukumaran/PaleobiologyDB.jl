# ---------------------------------------------------------------------------
# PhyloPicMakie — thumbnail grid rendering
#
# Provides a gallery-style view of PhyloPic thumbnails paired with taxon names.
# The bang variant draws into an existing axis; the non-bang variant builds a
# new Figure/Axis pair with sensible large-screen defaults.
# ---------------------------------------------------------------------------

import Makie
import PhyloPicDB
using PaleobiologyDB.Taxonomy: phylopic_images, phylopic_node

const DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS = 4
const DEFAULT_THUMBNAIL_GRID_CELL_WIDTH = 1.0
const DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT = 1.6
const DEFAULT_THUMBNAIL_GRID_GLYPH_FRACTION = 0.55
const DEFAULT_THUMBNAIL_GRID_LABEL_GAP = 0.10
const DEFAULT_THUMBNAIL_GRID_FONT_SIZE = 18.0
const DEFAULT_THUMBNAIL_GRID_FIGURE_MARGIN_PX = 80
const DEFAULT_THUMBNAIL_GRID_CELL_WIDTH_PX = 320
const DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT_PX = 260
const DEFAULT_THUMBNAIL_GRID_TITLE_GAP = 0.12

"""
Valid `image_filter` symbols for the thumbnail grid.
"""
const VALID_IMAGE_FILTERS = (:primary, :clade, :node)

"""
Valid `image_layout` symbols for the thumbnail grid.
"""
const VALID_IMAGE_LAYOUTS = (:flat, :grouped)

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
    ) -> Vector{Tuple{Float64, Float64}}

Return the `(x, y)` centre coordinates for `n` thumbnail cells laid out in a
row-major grid.
"""
function _thumbnail_grid_positions(
    n::Integer,
    ncols::Integer,
    nrows::Integer;
    cell_width::Real,
    cell_height::Real,
)::Vector{Tuple{Float64, Float64}}
    positions = Vector{Tuple{Float64, Float64}}(undef, n)
    for i in 1:n
        row_index = cld(i, ncols)
        col_index = ((i - 1) % ncols) + 1
        x = (Float64(col_index) - 0.5) * Float64(cell_width)
        y = (Float64(nrows - row_index) + 0.5) * Float64(cell_height)
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
# Image resolution for the thumbnail grid
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
    _fetch_taxon_image_pool(
        name::AbstractString,
        image_filter::Symbol,
        image_max_pages::Union{Int, Nothing},
    ) -> Vector{PhyloPicDB.PhyloPicImage}

Fetch the raw image pool for a single taxon name from the PhyloPic API.

Returns an empty vector for blank names, unresolvable taxa, or any error.

- `:primary` — resolves `name` to a PhyloPic node via the PBDB pipeline and
  returns `[primary_image]` (1-element vector).
- `:clade` / `:node` — returns all images from
  [`PaleobiologyDB.Taxonomy.phylopic_images`](@ref).
"""
function _fetch_taxon_image_pool(
    name::AbstractString,
    image_filter::Symbol,
    image_max_pages::Union{Int, Nothing},
)::Vector{PhyloPicDB.PhyloPicImage}
    isempty(strip(name)) && return PhyloPicDB.PhyloPicImage[]
    if image_filter === :primary
        node = phylopic_node(name)
        isnothing(node) && return PhyloPicDB.PhyloPicImage[]
        img = PhyloPicDB.primary_image(node.uuid)
        return isnothing(img) ? PhyloPicDB.PhyloPicImage[] : [img]
    end
    return phylopic_images(name; filter = image_filter, max_pages = image_max_pages)
end

"""
    _download_thumbnail(
        img::PhyloPicDB.PhyloPicImage,
        label::AbstractString,
    ) -> Union{Matrix{RGBA{N0f8}}, Nothing}

Download and decode the thumbnail for `img`.

Returns `nothing` when `img.thumbnail_url` is `missing` or the download fails.
Download failures are logged via `@warn` with `label` included for diagnostics.
"""
function _download_thumbnail(
    img::PhyloPicDB.PhyloPicImage,
    label::AbstractString,
)::Union{Matrix{RGBA{N0f8}}, Nothing}
    ismissing(img.thumbnail_url) && return nothing
    try
        return _load_phylopic_image(img.thumbnail_url)
    catch err
        @warn "phylopic_thumbnail_grid: could not load thumbnail for \"$label\"" exception = err
        return nothing
    end
end

"""
    _build_grid_cells(
        taxon::AbstractVector{<:AbstractString},
        image_filter::Symbol,
        image_selector,
        image_max_pages::Union{Int, Nothing},
    ) -> Tuple{Vector{String}, Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}, Vector{Int}}

Build the flat cell list for the thumbnail grid.

Returns three parallel arrays:
- `labels` — display label for each cell.
- `cell_images` — decoded thumbnail matrix or `nothing` per cell.
- `group_sizes` — number of cells contributed by each taxon (in input order).

Labels are the taxon name for single-image groups and `"name [k]"` for
multi-image groups (where `k` is the 1-based image index within the group).

Taxa that produce no images (empty name, unresolvable, or filtered to empty) contribute
a `group_sizes` entry of `0` and no cells.
"""
function _build_grid_cells(
    taxon::AbstractVector{<:AbstractString},
    image_filter::Symbol,
    image_selector,
    image_max_pages::Union{Int, Nothing},
)::Tuple{
    Vector{String},
    Vector{Union{Matrix{RGBA{N0f8}}, Nothing}},
    Vector{Int},
}
    labels      = String[]
    cell_images = Union{Matrix{RGBA{N0f8}}, Nothing}[]
    group_sizes = Int[]

    for name in taxon
        s        = string(name)
        pool     = _fetch_taxon_image_pool(s, image_filter, image_max_pages)
        selected = _apply_image_selector(pool, image_selector)
        count    = length(selected)
        push!(group_sizes, count)
        multi = count > 1
        for (k, img) in enumerate(selected)
            lbl = multi ? "$s [$k]" : s
            push!(labels, lbl)
            push!(cell_images, _download_thumbnail(img, lbl))
        end
    end

    return (labels, cell_images, group_sizes)
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
            y = (Float64(total_rows - 1 - global_r) + 0.5) * Float64(cell_height)
            push!(positions, (x, y))
        end
        row_offset += cld(g, ncols)
    end
    return positions
end

"""
    phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        taxon::AbstractVector{<:AbstractString};
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
        image_filter::Symbol = :primary,
        image_selector = nothing,
        image_max_pages::Union{Int, Nothing} = nothing,
        image_layout::Symbol = :grouped,
    ) -> Nothing

Render a gallery of PhyloPic thumbnail silhouettes into the existing Makie
`Axis` `ax`.

Each taxon in `taxon` contributes one or more cells to the grid depending on
`image_filter` and `image_selector`.  With the defaults (`image_filter =
:primary`, `image_selector = nothing`) each taxon produces exactly one cell —
the same behaviour as before this feature was added.

## Arguments

- `ax`: Target Makie axis.
- `taxon`: Taxon names to resolve via the PBDB → PhyloPic pipeline.

## Layout keywords

- `ncols`, `nrows`: Explicit grid dimensions.  Supply either, both, or neither.
- `cell_width`, `cell_height`: Cell size in axis data units.
- `glyph_fraction`: Fraction of `cell_height` allocated to the image.
- `label_gap`: Vertical gap between thumbnail and text label.
- `label_fontsize`: Font size for cell labels.
- `title`: Optional axis title drawn above the grid.
- `title_gap`: Additional vertical padding reserved for the title.

## Image selection

- `image_filter`: Which pool of images to fetch per taxon.
  - `:primary` (default) — designated primary image; 1 per taxon.
  - `:clade` — all images for the node and its descendants.
  - `:node` — images tagged directly to this node.
- `image_selector`: How to narrow the fetched pool.  Every selector produces a
  `Vector{PhyloPicImage}`; single-image selectors produce a 1-element vector.
  - `nothing` (default) — keep all images in the pool.
  - `:first` — first image only → `[pool[1]]`.
  - `Int n` — *n*-th image → `[pool[n]]`, or `[]` if out of bounds.
  - Callable `f` — `f(pool)` must return an `AbstractVector{PhyloPicImage}`.
- `image_max_pages`: Pagination limit for `:clade`/`:node` queries (~30 images
  per page).  `nothing` fetches all pages.  Ignored for `:primary`.
- `image_layout`: How to arrange cells when a taxon contributes more than one
  image.
  - `:grouped` (default) — each taxon's images start a new row; wraps at
    `ncols` within the group.
  - `:flat` — single row-major grid ignoring taxon boundaries.

## Missing-image policy

- `on_missing = :skip` (default): skip cells whose thumbnail download failed.
- `on_missing = :placeholder`: draw a placeholder rectangle for failed cells.
- `on_missing = :error`: throw when any selected image has no downloadable thumbnail.

Taxon names that cannot be resolved (blank names, PBDB lookup failure, no
images in the requested pool) contribute no cells.  The `on_missing` policy
applies only to images that were selected but whose thumbnail could not be
downloaded.

## Returns

`Nothing`.  The plot is added to `ax` by side effect.
"""
function phylopic_thumbnail_grid!(
    ax::Makie.Axis,
    taxon::AbstractVector{<:AbstractString};
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
    image_filter::Symbol = :primary,
    image_selector = nothing,
    image_max_pages::Union{Int, Nothing} = nothing,
    image_layout::Symbol = :grouped,
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
    image_filter ∈ VALID_IMAGE_FILTERS || throw(ArgumentError(
        "phylopic_thumbnail_grid!: unknown `image_filter` value `$image_filter`. " *
        "Valid values: $(join(VALID_IMAGE_FILTERS, ", "))."
    ))
    image_layout ∈ VALID_IMAGE_LAYOUTS || throw(ArgumentError(
        "phylopic_thumbnail_grid!: unknown `image_layout` value `$image_layout`. " *
        "Valid values: $(join(VALID_IMAGE_LAYOUTS, ", "))."
    ))

    # Build the flat cell list across all taxa.
    cell_labels, cell_images, group_sizes =
        _build_grid_cells(taxon, image_filter, image_selector, image_max_pages)
    total_cells = length(cell_labels)

    # Determine grid geometry.
    cols, rows = _infer_thumbnail_grid_shape(total_cells; ncols = ncols, nrows = nrows)

    # Compute cell positions according to layout.
    positions = if image_layout === :grouped
        grouped_rows = _grouped_grid_total_rows(group_sizes, cols)
        rows = max(grouped_rows, 1)
        _grouped_grid_positions(group_sizes, cols;
            cell_width = cell_width, cell_height = cell_height)
    else  # :flat
        _thumbnail_grid_positions(total_cells, cols, rows;
            cell_width = cell_width, cell_height = cell_height)
    end

    glyph_size = Float64(cell_height) * Float64(glyph_fraction) / 2

    for i in 1:total_cells
        x, y  = positions[i]
        img   = cell_images[i]
        label = cell_labels[i]

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
        cell_width = cell_width,
        cell_height = cell_height,
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
        taxon::AbstractVector{<:AbstractString};
        figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
        axis = NamedTuple(),
        ncols::Union{Integer, Nothing} = nothing,
        nrows::Union{Integer, Nothing} = nothing,
        image_filter::Symbol = :primary,
        image_selector = nothing,
        image_max_pages::Union{Int, Nothing} = nothing,
        image_layout::Symbol = :grouped,
        kwargs...,
    ) -> Makie.Figure

Create a new figure containing a thumbnail-grid gallery for `taxon`.

The figure size is inferred from the grid shape using large-screen defaults and
bounded width, so larger galleries generally grow downward instead of becoming
arbitrarily wide.  Pass `figure_size` to override the inferred size.  Any
entries of the `axis` named tuple are forwarded to the `Axis` constructor.

See [`phylopic_thumbnail_grid!`](@ref) for full documentation of
`image_filter`, `image_selector`, `image_max_pages`, and `image_layout`.

Returns the created `Makie.Figure`.
"""
function phylopic_thumbnail_grid(
    taxon::AbstractVector{<:AbstractString};
    figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
    axis = NamedTuple(),
    ncols::Union{Integer, Nothing} = nothing,
    nrows::Union{Integer, Nothing} = nothing,
    image_filter::Symbol = :primary,
    image_selector = nothing,
    image_max_pages::Union{Int, Nothing} = nothing,
    image_layout::Symbol = :grouped,
    kwargs...,
)::Makie.Figure
    cols, rows = _infer_thumbnail_grid_shape(length(taxon); ncols = ncols, nrows = nrows)

    resolved_figure_size = if isnothing(figure_size)
        (
            cols * DEFAULT_THUMBNAIL_GRID_CELL_WIDTH_PX + DEFAULT_THUMBNAIL_GRID_FIGURE_MARGIN_PX,
            rows * DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT_PX + DEFAULT_THUMBNAIL_GRID_FIGURE_MARGIN_PX,
        )
    else
        figure_size
    end

    fig = Makie.Figure(size = resolved_figure_size)
    ax = Makie.Axis(fig[1, 1]; axis...)
    phylopic_thumbnail_grid!(
        ax,
        taxon;
        ncols = cols,
        nrows = rows,
        image_filter = image_filter,
        image_selector = image_selector,
        image_max_pages = image_max_pages,
        image_layout = image_layout,
        kwargs...,
    )
    return fig
end
