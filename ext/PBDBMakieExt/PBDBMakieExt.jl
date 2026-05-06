"""
    PBDBMakieExt

Package extension for PaleobiologyDB.jl that activates when Makie is loaded.
Provides the concrete tree-visualization methods and the PBDB-PhyloPic bridge
for the public declarations owned by `PaleobiologyDB.PBDBMakie`.
"""
module PBDBMakieExt

import Makie
import PhyloPicMakie
using Makie: @recipe, Attributes
import Graphs

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

acquire_phylopic(args...; kwargs...) = PhyloPic.acquire_phylopic(args...; kwargs...)
augment_phylopic(args...; kwargs...) = PhyloPic.augment_phylopic(args...; kwargs...)
augment_phylopic!(args...; kwargs...) = PhyloPic.augment_phylopic!(args...; kwargs...)
augment_phylopic_ranges(args...; kwargs...) = PhyloPic.augment_phylopic_ranges(args...; kwargs...)
augment_phylopic_ranges!(args...; kwargs...) = PhyloPic.augment_phylopic_ranges!(args...; kwargs...)
phylopic_images_dataframe(args...; kwargs...) = PhyloPic.phylopic_images_dataframe(args...; kwargs...)
phylopic_node(args...; kwargs...) = PhyloPic.phylopic_node(args...; kwargs...)
phylopic_images(args...; kwargs...) = PhyloPic.phylopic_images(args...; kwargs...)
pbdb_phylopic_grid(args...; kwargs...) = PhyloPic.pbdb_phylopic_grid(args...; kwargs...)
pbdb_phylopic_grid!(args...; kwargs...) = PhyloPic.pbdb_phylopic_grid!(args...; kwargs...)

include("_layout.jl")
include("_leaf_overlay.jl")
include("_recipe.jl")
include("_augment.jl")

end # module PBDBMakieExt
