# Package extension for PaleobiologyDB.jl that activates when Makie is loaded.
# It provides the concrete tree-visualization methods and the PBDB-PhyloPic
# bridge for the public declarations owned by `PaleobiologyDB.PBDBMakie`.
module PBDBMakieExt

import Makie
import PhyloPicMakie
using Makie: @recipe, Attributes
import Graphs
import DataFrames

using PaleobiologyDB
using PaleobiologyDB.Taxonomy: TaxonomyTree, TaxonNode, taxon_subtree

import PaleobiologyDB.PBDBMakie
import PaleobiologyDB.PBDBMakie:
    taxonomytreeplot, taxonomytreeplot!, set_rank_axis_ticks!,
    leaf_positions, augment_leaf_phylopic!,
    acquire_phylopic, augment_phylopic, augment_phylopic!,
    augment_phylopic_ranges, augment_phylopic_ranges!,
    phylopic_images_dataframe, phylopic_node, phylopic_images,
    pbdb_phylopic_grid, pbdb_phylopic_grid!

include("PhyloPic/src/PhyloPic.jl")
using .PhyloPic

@doc (@doc PhyloPic.acquire_phylopic(::AbstractString)) function acquire_phylopic(
        taxon_name::AbstractString,
        fieldname_prefix::AbstractString = "phylopic_";
        image_selector = :primary,
        kwargs...,
    )::NamedTuple
    return PhyloPic.acquire_phylopic(
        taxon_name,
        fieldname_prefix;
        image_selector = image_selector,
        kwargs...,
    )
end

@doc (@doc PhyloPic.acquire_phylopic(::DataFrames.AbstractDataFrame)) function acquire_phylopic(
        df::DataFrames.AbstractDataFrame,
        taxon_field::Symbol = :accepted_name,
        fieldname_prefix::AbstractString = "phylopic_";
        image_selector = :primary,
        kwargs...,
    )::DataFrames.DataFrame
    return PhyloPic.acquire_phylopic(
        df,
        taxon_field,
        fieldname_prefix;
        image_selector = image_selector,
        kwargs...,
    )
end

@doc (@doc PhyloPic.augment_phylopic(::DataFrames.AbstractDataFrame)) function augment_phylopic(
        df::DataFrames.AbstractDataFrame,
        taxon_field::Symbol = :accepted_name,
        fieldname_prefix::AbstractString = "phylopic_";
        kwargs...,
    )::DataFrames.DataFrame
    return PhyloPic.augment_phylopic(df, taxon_field, fieldname_prefix; kwargs...)
end

@doc (@doc PhyloPic.augment_phylopic(::Makie.Axis, ::AbstractVector{<:Real}, ::AbstractVector{<:Real})) function augment_phylopic(
        ax::Makie.Axis,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        kwargs...,
    )::Nothing
    return PhyloPic.augment_phylopic(ax, x, y; kwargs...)
end

@doc (@doc PhyloPic.augment_phylopic(::Makie.Axis, ::Any)) function augment_phylopic(
        ax::Makie.Axis,
        table;
        kwargs...,
    )::Nothing
    return PhyloPic.augment_phylopic(ax, table; kwargs...)
end

@doc (@doc PhyloPic.augment_phylopic!(::Makie.Axis, ::AbstractVector{<:Real}, ::AbstractVector{<:Real})) function augment_phylopic!(
        ax::Makie.Axis,
        x::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        kwargs...,
    )::Nothing
    return PhyloPic.augment_phylopic!(ax, x, y; kwargs...)
end

@doc (@doc PhyloPic.augment_phylopic!(::Makie.Axis, ::Any)) function augment_phylopic!(
        ax::Makie.Axis,
        table;
        kwargs...,
    )::Nothing
    return PhyloPic.augment_phylopic!(ax, table; kwargs...)
end

@doc (@doc PhyloPic.augment_phylopic_ranges(::Makie.Axis, ::AbstractVector{<:Real}, ::AbstractVector{<:Real}, ::AbstractVector{<:Real})) function augment_phylopic_ranges(
        ax::Makie.Axis,
        xstart::AbstractVector{<:Real},
        xstop::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        kwargs...,
    )::Nothing
    return PhyloPic.augment_phylopic_ranges(ax, xstart, xstop, y; kwargs...)
end

@doc (@doc PhyloPic.augment_phylopic_ranges(::Makie.Axis, ::Any)) function augment_phylopic_ranges(
        ax::Makie.Axis,
        table;
        kwargs...,
    )::Nothing
    return PhyloPic.augment_phylopic_ranges(ax, table; kwargs...)
end

@doc (@doc PhyloPic.augment_phylopic_ranges!(::Makie.Axis, ::AbstractVector{<:Real}, ::AbstractVector{<:Real}, ::AbstractVector{<:Real})) function augment_phylopic_ranges!(
        ax::Makie.Axis,
        xstart::AbstractVector{<:Real},
        xstop::AbstractVector{<:Real},
        y::AbstractVector{<:Real};
        kwargs...,
    )::Nothing
    return PhyloPic.augment_phylopic_ranges!(ax, xstart, xstop, y; kwargs...)
end

@doc (@doc PhyloPic.augment_phylopic_ranges!(::Makie.Axis, ::Any)) function augment_phylopic_ranges!(
        ax::Makie.Axis,
        table;
        kwargs...,
    )::Nothing
    return PhyloPic.augment_phylopic_ranges!(ax, table; kwargs...)
end

@doc (@doc PhyloPic.phylopic_images_dataframe(::AbstractString)) function phylopic_images_dataframe(
        taxon_name::AbstractString,
        fieldname_prefix::AbstractString = "phylopic_";
        filter::Symbol = :clade,
        max_pages::Union{Int, Nothing} = nothing,
    )::DataFrames.DataFrame
    return PhyloPic.phylopic_images_dataframe(
        taxon_name,
        fieldname_prefix;
        filter = filter,
        max_pages = max_pages,
    )
end

@doc (@doc PhyloPic.phylopic_node(::AbstractString)) function phylopic_node(
        taxon_name::AbstractString;
        build::Union{Int, Nothing} = nothing,
    )::Union{PhyloPic.PhyloPicDB.PhyloPicNode, Nothing}
    return PhyloPic.phylopic_node(taxon_name; build = build)
end

@doc (@doc PhyloPic.phylopic_images(::AbstractString)) function phylopic_images(
        taxon_name::AbstractString;
        build::Union{Int, Nothing} = nothing,
        filter::Symbol = :clade,
        max_pages::Union{Int, Nothing} = nothing,
    )::Vector{PhyloPic.PhyloPicDB.PhyloPicImage}
    return PhyloPic.phylopic_images(
        taxon_name;
        build = build,
        filter = filter,
        max_pages = max_pages,
    )
end

"""
    pbdb_phylopic_grid!(
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
`image_filter` and `image_selector`. With `image_filter = :primary` each
taxon produces exactly one cell; with the default `image_filter = :clade` a
taxon may produce multiple cells.

## Arguments

- `ax`: Target Makie axis.
- `taxon`: PBDB taxon names to resolve via the PBDB-to-PhyloPic pipeline.

## Layout keywords

- `ncols`, `nrows`: Explicit grid dimensions. Supply either, both, or neither.
- `cell_width`, `cell_height`: Nominal cell size in axis data units.
- `glyph_fraction`: Fraction of `cell_height` allocated to the image.
- `label_gap`: Vertical gap between image and text label.
- `label_fontsize`: Font size for cell labels.
- `label_lines`: Override the automatic line count for multi-line labels.
- `title`: Optional axis title.
- `title_gap`: Additional vertical padding reserved for the title.

## Image selection and rendering

- `image_filter`: Which pool of images to fetch per taxon.
- `image_selector`: How to narrow the fetched pool; see
  `PhyloPicMakie.phylopic_thumbnail_grid!` for details.
- `image_max_pages`: Pagination limit for `:clade` and `:node` queries.
- `image_rendering`: Which URL to fetch for each selected image. Default
  `:thumbnail`.
- `image_layout`: `:blocks` (default), `:rows`, or `:flat`.
- `image_label`: Cell caption format. Default `:BASICFIELDS`.
- `labeljoin`: Field separator for multi-field label presets. Default `"\\n"`.

## Missing-image policy

- `on_missing = :skip` (default): skip cells with no downloadable image.
- `on_missing = :placeholder`: draw a placeholder for failed cells.
- `on_missing = :error`: throw when any selected image has no URL.

## Returns

`Nothing`.
"""
function pbdb_phylopic_grid!(
        ax::Makie.Axis,
        taxon::AbstractVector{<:AbstractString};
        kwargs...,
    )::Nothing
    return PhyloPic.pbdb_phylopic_grid!(ax, taxon; kwargs...)
end

"""
    pbdb_phylopic_grid!(
        ax::Makie.Axis,
        taxon_name::AbstractString;
        kwargs...,
    ) -> Nothing

Single-taxon convenience wrapper. Equivalent to
`pbdb_phylopic_grid!(ax, [taxon_name]; kwargs...)`.

See [`pbdb_phylopic_grid!`](@ref) for full keyword documentation.
"""
function pbdb_phylopic_grid!(
        ax::Makie.Axis,
        taxon_name::AbstractString;
        kwargs...,
    )::Nothing
    return PhyloPic.pbdb_phylopic_grid!(ax, taxon_name; kwargs...)
end

"""
    pbdb_phylopic_grid!(
        ax::Makie.Axis,
        table;
        taxon,
        kwargs...,
    ) -> Nothing

Table-oriented variant of [`pbdb_phylopic_grid!`](@ref).

Extracts the taxon column from any Tables.jl-compatible source and forwards to
the vector API.

- `taxon`: Column selector for taxon names (`Symbol`, `String`, or `Integer`).
- All remaining keyword arguments are forwarded to the vector API.
"""
function pbdb_phylopic_grid!(
        ax::Makie.Axis,
        table;
        taxon,
        kwargs...,
    )::Nothing
    return PhyloPic.pbdb_phylopic_grid!(ax, table; taxon = taxon, kwargs...)
end

"""
    pbdb_phylopic_grid(
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

The initial figure size is estimated from the thumbnail-grid defaults and the
number of taxa. After all images are placed, both dimensions are corrected
from the actual axis limits so that cell proportions remain consistent. Pass
`figure_size` to fix both dimensions and bypass the auto-resize.

See [`pbdb_phylopic_grid!`](@ref) for keyword documentation.

Returns the created `Makie.Figure`.
"""
function pbdb_phylopic_grid(
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
    return PhyloPic.pbdb_phylopic_grid(
        taxon;
        figure_size = figure_size,
        axis = axis,
        ncols = ncols,
        nrows = nrows,
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
    pbdb_phylopic_grid(
        taxon_name::AbstractString;
        kwargs...,
    ) -> Makie.Figure

Single-taxon convenience wrapper. Equivalent to
`pbdb_phylopic_grid([taxon_name]; kwargs...)`.

See [`pbdb_phylopic_grid`](@ref) for full keyword documentation.
"""
function pbdb_phylopic_grid(
        taxon_name::AbstractString;
        kwargs...,
    )::Makie.Figure
    return PhyloPic.pbdb_phylopic_grid(taxon_name; kwargs...)
end

"""
    pbdb_phylopic_grid(
        table;
        taxon,
        kwargs...,
    ) -> Makie.Figure

Table-oriented factory variant. Extracts the `taxon` column and calls the
vector factory.
"""
function pbdb_phylopic_grid(
        table;
        taxon,
        kwargs...,
    )::Makie.Figure
    return PhyloPic.pbdb_phylopic_grid(table; taxon = taxon, kwargs...)
end

include("_layout.jl")
include("_leaf_overlay.jl")
include("_recipe.jl")
include("_augment.jl")

end # module PBDBMakieExt
