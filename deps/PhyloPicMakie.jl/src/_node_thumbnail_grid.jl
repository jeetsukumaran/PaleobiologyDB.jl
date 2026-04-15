# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

"""
Valid `image_filter` symbols for the PhyloPic-native thumbnail grid.
"""
const VALID_NODE_IMAGE_FILTERS = (:primary, :clade, :node)

# ---------------------------------------------------------------------------
# Internal: per-node image pool fetching
# ---------------------------------------------------------------------------

"""
    _fetch_node_image_pool(
        node_uuid::AbstractString,
        image_filter::Symbol,
        image_max_pages::Union{Int, Nothing},
    ) -> Vector{PhyloPicDB.PhyloPicImage}

Fetch the image pool for a single PhyloPic node UUID, with `node_name`
enriched on every image via [`PhyloPicDB.with_node_names`](@ref).

- `:primary` — returns a 1-element vector containing the primary image
  (via [`PhyloPicDB.primary_image`](@ref)), or an empty vector if none.
- `:clade` — returns all images for the node and its descendants via
  [`PhyloPicDB.clade_images`](@ref).
- `:node` — returns images tagged directly to the node via
  [`PhyloPicDB.node_images`](@ref).

Returns an empty vector for blank UUIDs or when no images are available.
"""
function _fetch_node_image_pool(
    node_uuid::AbstractString,
    image_filter::Symbol,
    image_max_pages::Union{Int, Nothing},
)::Vector{PhyloPicDB.PhyloPicImage}
    isempty(strip(node_uuid)) && return PhyloPicDB.PhyloPicImage[]
    pool = if image_filter === :primary
        img = PhyloPicDB.primary_image(node_uuid)
        isnothing(img) ? PhyloPicDB.PhyloPicImage[] : [img]
    elseif image_filter === :clade
        PhyloPicDB.clade_images(node_uuid; max_pages = image_max_pages, add_node_name = false)
    else  # :node
        PhyloPicDB.node_images(node_uuid; max_pages = image_max_pages, add_node_name = false)
    end
    return PhyloPicDB.with_node_names(pool)
end

"""
    _build_node_grid_cells(
        node_uuids::AbstractVector{<:Union{AbstractString, Nothing}},
        node_labels::AbstractVector{<:AbstractString},
        image_filter::Symbol,
        image_selector,
        image_max_pages::Union{Int, Nothing},
        image_label,
        labeljoin::AbstractString,
        image_rendering::Symbol,
    ) -> Tuple{Vector{String}, Vector{Union{Matrix{RGBA{N0f8}}, Nothing}}, Vector{Int}}

Build the flat cell list for the thumbnail grid from PhyloPic node UUIDs.

Returns three parallel arrays:
- `labels`      — display label for each cell.
- `cell_images` — decoded image matrix or `nothing` per cell.
- `group_sizes` — number of cells contributed by each node (in input order);
  `0` for `nothing` / blank UUID entries or nodes that yield no images.

`node_labels` provides the per-node display name forwarded to
[`_build_label`](@ref) as the `taxon_name` context argument.  Must have the
same length as `node_uuids`.

Image download is delegated to [`_download_image`](@ref); image selection
to [`_apply_image_selector`](@ref); label construction to
[`_build_label`](@ref).
"""
function _build_node_grid_cells(
    node_uuids::AbstractVector{<:Union{AbstractString, Nothing}},
    node_labels::AbstractVector{<:AbstractString},
    image_filter::Symbol,
    image_selector,
    image_max_pages::Union{Int, Nothing},
    image_label,
    labeljoin::AbstractString,
    image_rendering::Symbol,
)::Tuple{
    Vector{String},
    Vector{Union{Matrix{RGBA{N0f8}}, Nothing}},
    Vector{Int},
}
    length(node_uuids) == length(node_labels) || throw(ArgumentError(
        "_build_node_grid_cells: `node_uuids` and `node_labels` must have the same length."
    ))

    labels      = String[]
    cell_images = Union{Matrix{RGBA{N0f8}}, Nothing}[]
    group_sizes = Int[]

    for (uuid, name) in zip(node_uuids, node_labels)
        if isnothing(uuid) || isempty(strip(uuid))
            push!(group_sizes, 0)
            continue
        end
        pool     = _fetch_node_image_pool(uuid, image_filter, image_max_pages)
        selected = _apply_image_selector(pool, image_selector)
        count    = length(selected)
        push!(group_sizes, count)
        multi = count > 1
        for (k, img) in enumerate(selected)
            lbl = _build_label(name, k, multi, img, image_label, labeljoin)
            push!(labels, lbl)
            push!(cell_images, _download_image(img, lbl; image_rendering))
        end
    end

    return (labels, cell_images, group_sizes)
end

# ---------------------------------------------------------------------------
# Internal: default label resolution from node UUID
# ---------------------------------------------------------------------------

"""
    _resolve_node_labels(
        node_uuids::AbstractVector{<:Union{AbstractString, Nothing}},
    ) -> Vector{String}

Return a display label for each UUID by fetching the node's `preferred_name`.

Calls [`PhyloPicDB.fetch_node`](@ref) for each unique non-nothing UUID and
returns `preferred_name`.  Falls back to the UUID string itself when the
node cannot be fetched or has an empty `preferred_name`.  `nothing` entries
produce an empty string.
"""
function _resolve_node_labels(
    node_uuids::AbstractVector{<:Union{AbstractString, Nothing}},
)::Vector{String}
    map(node_uuids) do uuid
        isnothing(uuid) && return ""
        s = strip(uuid)
        isempty(s) && return ""
        node = PhyloPicDB.fetch_node(String(s))
        isnothing(node) && return String(s)
        isempty(node.preferred_name) ? String(s) : node.preferred_name
    end
end

# ---------------------------------------------------------------------------
# Public: vector UUID API
# ---------------------------------------------------------------------------

"""
    phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        node_uuids::AbstractVector{<:Union{AbstractString, Nothing}};
        node_labels::Union{AbstractVector{<:AbstractString}, Nothing} = nothing,
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
        image_layout::Symbol = :blocks,
        image_rendering::Symbol = :thumbnail,
        image_label = :BASICFIELDS,
        labeljoin::AbstractString = "\\n",
        label_lines::Union{Int, Nothing} = nothing,
    ) -> Nothing

Render a gallery of PhyloPic silhouettes into the existing Makie `Axis` `ax`,
resolved from PhyloPic node UUIDs.

This is the **PhyloPic-native** thumbnail gallery entry point.  For PBDB
taxon-name resolution use `PaleobiologyDB.PhyloPicPBDB.phylopic_thumbnail_grid!`.

## Arguments

- `ax`: Target Makie axis.
- `node_uuids`: PhyloPic node UUID strings.  `nothing` entries produce empty
  groups (no cells contributed, no rendering, group boundary preserved).

## Keywords

- `node_labels`: Display names used as the `taxon_name` context when
  building cell labels (one per UUID entry).  When `nothing` (default), the
  node's `preferred_name` is fetched via the API — pass explicit labels to
  avoid this round-trip (e.g. PBDB taxon names from PhyloPicPBDB).

For all other keywords (layout, image selection, label building, rendering)
see `PaleobiologyDB.PhyloPicPBDB.phylopic_thumbnail_grid!`.

## Image filter defaults

- `image_filter = :primary` (default here) — one image per node, no
  pagination.  Use `:clade` for all images in the node's clade.

## Returns

`Nothing`.

## Examples

```julia
using PhyloPicMakie, CairoMakie

fig = Figure()
ax  = Axis(fig[1, 1])
phylopic_thumbnail_grid!(
    ax,
    ["3c4b8687-2401-4e5b-afb5-19aa3e7e8b26",
     "7fb20e1a-3a19-4e8c-beb9-3e7ffb59c0cf"];
    image_filter = :primary,
    ncols = 2,
)
```
"""
function phylopic_thumbnail_grid!(
    ax::Makie.Axis,
    node_uuids::AbstractVector{<:Union{AbstractString, Nothing}};
    node_labels::Union{AbstractVector{<:AbstractString}, Nothing} = nothing,
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
    image_layout::Symbol = :blocks,
    image_rendering::Symbol = :thumbnail,
    image_label = :BASICFIELDS,
    labeljoin::AbstractString = "\n",
    label_lines::Union{Int, Nothing} = nothing,
)::Nothing
    image_filter ∈ VALID_NODE_IMAGE_FILTERS || throw(ArgumentError(
        "phylopic_thumbnail_grid!: unknown `image_filter` value `$image_filter`. " *
        "Valid values: $(join(VALID_NODE_IMAGE_FILTERS, ", "))."
    ))
    image_rendering ∈ PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS || throw(ArgumentError(
        "phylopic_thumbnail_grid!: unknown `image_rendering` value `:$image_rendering`. " *
        "Valid values: $(join(string.(':', PhyloPicDB.PHYLOPIC_IMAGE_RENDERINGS), ", "))."
    ))

    labels = if isnothing(node_labels)
        _resolve_node_labels(node_uuids)
    else
        length(node_labels) == length(node_uuids) || throw(ArgumentError(
            "phylopic_thumbnail_grid!: `node_labels` length ($(length(node_labels))) " *
            "must match `node_uuids` length ($(length(node_uuids)))."
        ))
        collect(String, node_labels)
    end

    cell_labels, cell_images, group_sizes = _build_node_grid_cells(
        node_uuids, labels, image_filter, image_selector, image_max_pages,
        image_label, labeljoin, image_rendering,
    )
    phylopic_thumbnail_grid!(
        ax, cell_images, cell_labels, group_sizes;
        ncols             = ncols,
        nrows             = nrows,
        cell_width        = cell_width,
        cell_height       = cell_height,
        glyph_fraction    = glyph_fraction,
        label_gap         = label_gap,
        label_fontsize    = label_fontsize,
        title             = title,
        title_gap         = title_gap,
        on_missing        = on_missing,
        image_interpolate = image_interpolate,
        image_layout      = image_layout,
        label_lines       = label_lines,
    )
end

"""
    phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        node_uuid::AbstractString;
        kwargs...,
    ) -> Nothing

Single-UUID convenience wrapper.  Equivalent to
`phylopic_thumbnail_grid!(ax, [node_uuid]; kwargs...)`.

See [`phylopic_thumbnail_grid!`](@ref) for full keyword documentation.
"""
function phylopic_thumbnail_grid!(
    ax::Makie.Axis,
    node_uuid::AbstractString;
    kwargs...,
)::Nothing
    phylopic_thumbnail_grid!(ax, [node_uuid]; kwargs...)
end

# ---------------------------------------------------------------------------
# Public: table API
# ---------------------------------------------------------------------------

"""
    phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        table;
        node_uuid,
        node_label = nothing,
        kwargs...,
    ) -> Nothing

Table-oriented variant of [`phylopic_thumbnail_grid!`](@ref).

Extracts the node UUID (and optionally node label) column from any
Tables.jl-compatible source and forwards to the vector API.

## Arguments

- `node_uuid`: column selector for node UUID strings (Symbol, String, or
  Integer).
- `node_label`: column selector for display labels, or `nothing` (default)
  to fetch `preferred_name` from the API.
- All remaining keyword arguments are forwarded to the vector API.
"""
function phylopic_thumbnail_grid!(
    ax::Makie.Axis,
    table;
    node_uuid,
    node_label = nothing,
    kwargs...,
)::Nothing
    uuids  = collect(Union{String, Nothing}, string.(_extract_column(table, node_uuid)))
    labels = isnothing(node_label) ? nothing :
        collect(String, string.(_extract_column(table, node_label)))
    phylopic_thumbnail_grid!(ax, uuids; node_labels = labels, kwargs...)
end

# ---------------------------------------------------------------------------
# Public: factory variants (non-bang)
# ---------------------------------------------------------------------------

"""
    phylopic_thumbnail_grid(
        node_uuids::AbstractVector{<:Union{AbstractString, Nothing}};
        figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
        axis = NamedTuple(),
        ncols::Union{Integer, Nothing} = nothing,
        nrows::Union{Integer, Nothing} = nothing,
        node_labels::Union{AbstractVector{<:AbstractString}, Nothing} = nothing,
        image_filter::Symbol = :primary,
        image_selector = nothing,
        image_max_pages::Union{Int, Nothing} = nothing,
        image_layout::Symbol = :blocks,
        image_rendering::Symbol = :thumbnail,
        image_label = :BASICFIELDS,
        labeljoin::AbstractString = "\\n",
        label_lines::Union{Int, Nothing} = nothing,
        kwargs...,
    ) -> Makie.Figure

Create a new figure containing a silhouette-grid gallery for `node_uuids`.

The initial figure size is estimated from `DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS`
(width) and `length(node_uuids)` (height).  After all images are placed both
dimensions are corrected from the actual axis limits so cell proportions
remain consistent.  Pass `figure_size` to fix both dimensions and bypass
auto-resize.  Entries of the `axis` named tuple are forwarded to the `Axis`
constructor.

See [`phylopic_thumbnail_grid!`](@ref) for full keyword documentation.

Returns the created `Makie.Figure`.

## Examples

```julia
using PhyloPicMakie, CairoMakie

fig = phylopic_thumbnail_grid(
    ["3c4b8687-2401-4e5b-afb5-19aa3e7e8b26",
     "7fb20e1a-3a19-4e8c-beb9-3e7ffb59c0cf"];
    image_filter = :primary,
    ncols        = 2,
)
```
"""
function phylopic_thumbnail_grid(
    node_uuids::AbstractVector{<:Union{AbstractString, Nothing}};
    figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
    axis = NamedTuple(),
    ncols::Union{Integer, Nothing} = nothing,
    nrows::Union{Integer, Nothing} = nothing,
    node_labels::Union{AbstractVector{<:AbstractString}, Nothing} = nothing,
    image_filter::Symbol = :primary,
    image_selector = nothing,
    image_max_pages::Union{Int, Nothing} = nothing,
    image_layout::Symbol = :blocks,
    image_rendering::Symbol = :thumbnail,
    image_label = :BASICFIELDS,
    labeljoin::AbstractString = "\n",
    label_lines::Union{Int, Nothing} = nothing,
    kwargs...,
)::Makie.Figure
    init_cols = isnothing(ncols) ? DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS : Int(ncols)
    init_rows = max(length(node_uuids), 1)

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
    phylopic_thumbnail_grid!(
        ax,
        node_uuids;
        node_labels     = node_labels,
        ncols           = ncols,
        nrows           = nrows,
        image_filter    = image_filter,
        image_selector  = image_selector,
        image_max_pages = image_max_pages,
        image_layout    = image_layout,
        image_rendering = image_rendering,
        image_label     = image_label,
        labeljoin       = labeljoin,
        label_lines     = label_lines,
        kwargs...,
    )

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

"""
    phylopic_thumbnail_grid(
        node_uuid::AbstractString;
        kwargs...,
    ) -> Makie.Figure

Single-UUID factory convenience wrapper.  Equivalent to
`phylopic_thumbnail_grid([node_uuid]; kwargs...)`.

See [`phylopic_thumbnail_grid`](@ref) for full keyword documentation.
"""
function phylopic_thumbnail_grid(
    node_uuid::AbstractString;
    kwargs...,
)::Makie.Figure
    phylopic_thumbnail_grid([node_uuid]; kwargs...)
end

"""
    phylopic_thumbnail_grid(
        table;
        node_uuid,
        node_label = nothing,
        kwargs...,
    ) -> Makie.Figure

Table-oriented factory variant.  Extracts the `node_uuid` column (and
optionally `node_label`) and calls the vector factory.

See [`phylopic_thumbnail_grid!`](@ref) for keyword documentation.
"""
function phylopic_thumbnail_grid(
    table;
    node_uuid,
    node_label = nothing,
    kwargs...,
)::Makie.Figure
    uuids  = collect(Union{String, Nothing}, string.(_extract_column(table, node_uuid)))
    labels = isnothing(node_label) ? nothing :
        collect(String, string.(_extract_column(table, node_label)))
    phylopic_thumbnail_grid(uuids; node_labels = labels, kwargs...)
end
