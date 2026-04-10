# ---------------------------------------------------------------------------
# PhyloPicMakie — thumbnail grid rendering
#
# Provides a gallery-style view of PhyloPic thumbnails paired with taxon names.
# The bang variant draws into an existing axis; the non-bang variant builds a
# new Figure/Axis pair with sensible large-screen defaults.
# ---------------------------------------------------------------------------

import Makie

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
    ) -> Nothing

Render a gallery of PhyloPic thumbnail silhouettes, one per taxon, into the
existing Makie `Axis` `ax`.

Each taxon is displayed in its own cell with the silhouette centred in the
upper portion of the cell and the taxon name centred beneath it.  The layout
is row-major.  If neither `ncols` nor `nrows` is specified, a bounded-width
layout is inferred automatically so larger galleries tend to extend downward
rather than becoming excessively wide.

## Arguments

- `ax`: Target Makie axis.
- `taxon`: Taxon names to resolve via
  [`PaleobiologyDB.Taxonomy.acquire_phylopic`](@ref).

## Layout keywords

- `ncols`, `nrows`: Explicit grid dimensions.  Supply either, both, or neither.
- `cell_width`, `cell_height`: Cell size in axis data units.
- `glyph_fraction`: Fraction of `cell_height` allocated to the image height.
- `label_gap`: Vertical gap between thumbnail and text label.
- `label_fontsize`: Font size for taxon labels.
- `title`: Optional axis title drawn above the grid.
- `title_gap`: Additional vertical padding reserved for the title.

## Missing-image policy

- `on_missing = :skip`: leave the image area empty but still draw the taxon name.
- `on_missing = :placeholder`: draw a placeholder rectangle.
- `on_missing = :error`: throw if any thumbnail cannot be resolved.

## Returns

`Nothing`. The plot is added to `ax` by side effect.
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

    n = length(taxon)
    cols, rows = _infer_thumbnail_grid_shape(n; ncols = ncols, nrows = nrows)
    positions = _thumbnail_grid_positions(
        n,
        cols,
        rows;
        cell_width = cell_width,
        cell_height = cell_height,
    )
    images = _resolve_images(taxon, nothing, n)

    glyph_size = Float64(cell_height) * Float64(glyph_fraction) / 2

    for i in 1:n
        x, y = positions[i]
        img = images[i]

        if isnothing(img)
            if on_missing === :error
                throw(ErrorException(
                    "phylopic_thumbnail_grid!: missing image for taxon \"$(taxon[i])\"."
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
            string(taxon[i]);
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
        kwargs...,
    ) -> Makie.Figure

Create a new figure containing a thumbnail-grid gallery for `taxon`.

The figure size is inferred from the grid shape using large-screen defaults and
bounded width, so larger galleries generally grow downward instead of becoming
arbitrarily wide.  Pass `figure_size` to override the inferred size.  Any
entries of the `axis` named tuple are forwarded to the `Axis` constructor.

Returns the created `Makie.Figure`.
"""
function phylopic_thumbnail_grid(
    taxon::AbstractVector{<:AbstractString};
    figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
    axis = NamedTuple(),
    ncols::Union{Integer, Nothing} = nothing,
    nrows::Union{Integer, Nothing} = nothing,
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
        kwargs...,
    )
    return fig
end
