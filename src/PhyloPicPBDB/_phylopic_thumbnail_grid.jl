# ---------------------------------------------------------------------------
# PhyloPicPBDB — thumbnail grid: PBDB name-resolution bridge
#
# This file contains only the PBDB-specific parts of the thumbnail grid:
# resolving taxon names → PhyloPic node UUIDs via phylopic_node, and
# thin delegation wrappers that forward to the PhyloPic-native API in
# PhyloPicMakie.
#
# All generic image fetching, grid geometry, label building, image selection,
# and rendering live in PhyloPicMakie and are accessed via PhyloPicMakie.*.
#
# Call graph:
#
#   phylopic_thumbnail_grid! / phylopic_thumbnail_grid (vector API)
#   phylopic_thumbnail_grid! / phylopic_thumbnail_grid (table API)
#   phylopic_thumbnail_grid! / phylopic_thumbnail_grid (single-string API)
#       └─► map taxon names → PhyloPic node UUIDs via phylopic_node
#           └─► PhyloPicMakie.phylopic_thumbnail_grid!(ax, node_uuids; ...)
#                   node_labels = taxon names (passed through as display labels)
#
# Makie, PhyloPicMakie, and phylopic_node are all in scope from the
# enclosing PhyloPicPBDB module (phylopic.jl).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Internal: PBDB name → UUID mapping
# ---------------------------------------------------------------------------

"""
    _pbdb_names_to_uuids(taxon::AbstractVector{<:AbstractString})
        -> Tuple{Vector{Union{String, Nothing}}, Vector{String}}

Resolve a vector of PBDB taxon name strings to PhyloPic node UUIDs.

Returns two parallel vectors of the same length as `taxon`:
- `node_uuids`: PhyloPic node UUID string or `nothing` for names that could
  not be resolved.
- `taxon_labels`: the original taxon name strings, used as display labels.

Each unique non-empty name is resolved once via
[`PaleobiologyDB.Taxonomy.phylopic_node`](@ref) (cached via `autocache`).
"""
function _pbdb_names_to_uuids(
        taxon::AbstractVector{<:AbstractString},
    )::Tuple{Vector{Union{String, Nothing}}, Vector{String}}
    unique_names = unique(s for s in taxon if !isempty(strip(s)))
    uuid_cache = Dict{String, Union{String, Nothing}}()
    for name in unique_names
        node = phylopic_node(name)
        uuid_cache[name] = isnothing(node) ? nothing : node.uuid
    end

    node_uuids = Vector{Union{String, Nothing}}(undef, length(taxon))
    taxon_labels = Vector{String}(undef, length(taxon))
    for (i, name) in enumerate(taxon)
        s = string(name)
        node_uuids[i] = isempty(strip(s)) ? nothing : get(uuid_cache, s, nothing)
        taxon_labels[i] = s
    end
    return (node_uuids, taxon_labels)
end

# ---------------------------------------------------------------------------
# Public: vector API (PBDB taxon-name entry points)
# ---------------------------------------------------------------------------

"""
    phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        taxon::AbstractVector{<:AbstractString};
        ncols::Union{Integer, Nothing} = nothing,
        nrows::Union{Integer, Nothing} = nothing,
        cell_width::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_CELL_WIDTH,
        cell_height::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT,
        glyph_fraction::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_GLYPH_FRACTION,
        label_gap::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_LABEL_GAP,
        label_fontsize::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_FONT_SIZE,
        title::Union{AbstractString, Nothing} = nothing,
        title_gap::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_TITLE_GAP,
        on_missing::Symbol = :skip,
        image_interpolate::Bool = true,
        image_filter::Symbol = :clade,
        image_selector = nothing,
        image_max_pages::Union{Int, Nothing} = nothing,
        image_layout::Symbol = :blocks,
        image_rendering::Symbol = :thumbnail,
        image_label = :BASICFIELDS,
        labeljoin::AbstractString = "\\n",
        label_lines::Union{Int, Nothing} = nothing,
    ) -> Nothing

Render a gallery of PhyloPic silhouettes into the existing Makie `Axis` `ax`.

Each taxon in `taxon` contributes one or more cells to the grid depending on
`image_filter` and `image_selector`.  With `image_filter = :primary` each
taxon produces exactly one cell; with the default `image_filter = :clade` a
taxon may produce multiple cells (one per image in its clade).

## Arguments

- `ax`: Target Makie axis.
- `taxon`: PBDB taxon names to resolve via the PBDB → PhyloPic pipeline.

## Layout keywords

- `ncols`, `nrows`: Explicit grid dimensions.  Supply either, both, or neither.
- `cell_width`, `cell_height`: Nominal cell size in axis data units.
- `glyph_fraction`: Fraction of `cell_height` allocated to the image.
- `label_gap`: Vertical gap between image and text label.
- `label_fontsize`: Font size for cell labels.
- `label_lines`: Override the automatic line-count for multi-line labels.
- `title`: Optional axis title.
- `title_gap`: Additional vertical padding reserved for the title.

## Image selection and rendering

- `image_filter`: Which pool of images to fetch per taxon.
  - `:clade` (default) — all images for the node and its descendants.
  - `:primary` — designated primary image; 1 per taxon.
  - `:node` — images tagged directly to this node.
- `image_selector`: How to narrow the fetched pool; see
  `PhyloPicMakie.phylopic_thumbnail_grid!` for details.
- `image_max_pages`: Pagination limit for `:clade`/`:node` queries.
- `image_rendering`: Which URL to fetch for each selected image.  Default
  `:thumbnail`.
- `image_layout`: `:blocks` (default), `:rows`, or `:flat`.
- `image_label`: Cell caption format.  Default `:BASICFIELDS`.
- `labeljoin`: Field separator for multi-field label presets.  Default `"\\n"`.

## Missing-image policy

- `on_missing = :skip` (default): skip cells with no downloadable image.
- `on_missing = :placeholder`: draw a placeholder for failed cells.
- `on_missing = :error`: throw when any selected image has no URL.

## Returns

`Nothing`.
"""
function phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        taxon::AbstractVector{<:AbstractString};
        ncols::Union{Integer, Nothing} = nothing,
        nrows::Union{Integer, Nothing} = nothing,
        cell_width::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_CELL_WIDTH,
        cell_height::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_CELL_HEIGHT,
        glyph_fraction::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_GLYPH_FRACTION,
        label_gap::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_LABEL_GAP,
        label_fontsize::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_FONT_SIZE,
        title::Union{AbstractString, Nothing} = nothing,
        title_gap::Real = PhyloPicMakie.DEFAULT_THUMBNAIL_GRID_TITLE_GAP,
        on_missing::Symbol = :skip,
        image_interpolate::Bool = true,
        image_filter::Symbol = :clade,
        image_selector = nothing,
        image_max_pages::Union{Int, Nothing} = nothing,
        image_layout::Symbol = :blocks,
        image_rendering::Symbol = :thumbnail,
        image_label = :BASICFIELDS,
        labeljoin::AbstractString = "\n",
        label_lines::Union{Int, Nothing} = nothing,
    )::Nothing
    node_uuids, taxon_labels = _pbdb_names_to_uuids(taxon)
    return PhyloPicMakie.phylopic_thumbnail_grid!(
        ax,
        node_uuids;
        node_labels = taxon_labels,
        ncols = ncols,
        nrows = nrows,
        cell_width = cell_width,
        cell_height = cell_height,
        glyph_fraction = glyph_fraction,
        label_gap = label_gap,
        label_fontsize = label_fontsize,
        title = title,
        title_gap = title_gap,
        on_missing = on_missing,
        image_interpolate = image_interpolate,
        image_filter = image_filter,
        image_selector = image_selector,
        image_max_pages = image_max_pages,
        image_layout = image_layout,
        image_rendering = image_rendering,
        image_label = image_label,
        labeljoin = labeljoin,
        label_lines = label_lines,
    )
end

"""
    phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        taxon_name::AbstractString;
        kwargs...,
    ) -> Nothing

Single-taxon convenience wrapper.  Equivalent to
`phylopic_thumbnail_grid!(ax, [taxon_name]; kwargs...)`.

See [`phylopic_thumbnail_grid!`](@ref) for full keyword documentation.
"""
function phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        taxon_name::AbstractString;
        kwargs...,
    )::Nothing
    return phylopic_thumbnail_grid!(ax, [taxon_name]; kwargs...)
end

# ---------------------------------------------------------------------------
# Public: table API
# ---------------------------------------------------------------------------

"""
    phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        table;
        taxon,
        kwargs...,
    ) -> Nothing

Table-oriented variant of [`phylopic_thumbnail_grid!`](@ref).

Extracts the taxon column from any Tables.jl-compatible source (e.g. a
`DataFrame`) and forwards to the vector API.

- `taxon`: column selector for taxon names (Symbol, String, or Integer).
- All remaining keyword arguments are forwarded to the vector API.
"""
function phylopic_thumbnail_grid!(
        ax::Makie.Axis,
        table;
        taxon,
        kwargs...,
    )::Nothing
    taxa = PhyloPicMakie._extract_column(table, taxon)
    return phylopic_thumbnail_grid!(ax, collect(String, string.(taxa)); kwargs...)
end

# ---------------------------------------------------------------------------
# Public: factory variants (non-bang)
# ---------------------------------------------------------------------------

"""
    phylopic_thumbnail_grid(
        taxon::AbstractVector{<:AbstractString};
        figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
        axis = NamedTuple(),
        ncols::Union{Integer, Nothing} = nothing,
        nrows::Union{Integer, Nothing} = nothing,
        image_filter::Symbol = :clade,
        image_selector = nothing,
        image_max_pages::Union{Int, Nothing} = nothing,
        image_layout::Symbol = :blocks,
        image_rendering::Symbol = :thumbnail,
        image_label = :BASICFIELDS,
        labeljoin::AbstractString = "\\n",
        label_lines::Union{Int, Nothing} = nothing,
        kwargs...,
    ) -> Makie.Figure

Create a new figure containing a silhouette-grid gallery for `taxon`.

The initial figure size is estimated from `DEFAULT_THUMBNAIL_GRID_MAX_COLUMNS`
(width) and `length(taxon)` (height).  After all images are placed both
dimensions are corrected from the actual axis limits so that cell proportions
remain consistent.  Pass `figure_size` to fix both dimensions and bypass
the auto-resize.

See [`phylopic_thumbnail_grid!`](@ref) for full documentation.

Returns the created `Makie.Figure`.
"""
function phylopic_thumbnail_grid(
        taxon::AbstractVector{<:AbstractString};
        figure_size::Union{Tuple{<:Integer, <:Integer}, Nothing} = nothing,
        axis = NamedTuple(),
        ncols::Union{Integer, Nothing} = nothing,
        nrows::Union{Integer, Nothing} = nothing,
        image_filter::Symbol = :clade,
        image_selector = nothing,
        image_max_pages::Union{Int, Nothing} = nothing,
        image_layout::Symbol = :blocks,
        image_rendering::Symbol = :thumbnail,
        image_label = :BASICFIELDS,
        labeljoin::AbstractString = "\n",
        label_lines::Union{Int, Nothing} = nothing,
        kwargs...,
    )::Makie.Figure
    node_uuids, taxon_labels = _pbdb_names_to_uuids(taxon)
    return PhyloPicMakie.phylopic_thumbnail_grid(
        node_uuids;
        figure_size = figure_size,
        axis = axis,
        ncols = ncols,
        nrows = nrows,
        node_labels = taxon_labels,
        image_filter = image_filter,
        image_selector = image_selector,
        image_max_pages = image_max_pages,
        image_layout = image_layout,
        image_rendering = image_rendering,
        image_label = image_label,
        labeljoin = labeljoin,
        label_lines = label_lines,
        kwargs...,
    )
end

"""
    phylopic_thumbnail_grid(
        taxon_name::AbstractString;
        kwargs...,
    ) -> Makie.Figure

Single-taxon convenience wrapper.  Equivalent to
`phylopic_thumbnail_grid([taxon_name]; kwargs...)`.

See [`phylopic_thumbnail_grid`](@ref) for full keyword documentation.
"""
function phylopic_thumbnail_grid(
        taxon_name::AbstractString;
        kwargs...,
    )::Makie.Figure
    return phylopic_thumbnail_grid([taxon_name]; kwargs...)
end

"""
    phylopic_thumbnail_grid(
        table;
        taxon,
        kwargs...,
    ) -> Makie.Figure

Table-oriented factory variant.  Extracts `taxon` column and calls the
vector factory.
"""
function phylopic_thumbnail_grid(
        table;
        taxon,
        kwargs...,
    )::Makie.Figure
    taxa = PhyloPicMakie._extract_column(table, taxon)
    return phylopic_thumbnail_grid(collect(String, string.(taxa)); kwargs...)
end
