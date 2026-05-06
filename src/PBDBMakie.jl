"""
    PBDBMakie

Unconditional compile-time submodule of `PaleobiologyDB`.

This submodule is always present, regardless of whether a Makie backend is
loaded. It declares the public API for taxonomy-tree visualization and the
PBDB-PhyloPic bridge without depending on Makie or any optional package.

When a Makie backend is loaded, the `PBDBMakieExt` extension adds concrete
method implementations to these declarations through normal Julia dispatch.
`TaxonomyTreePlot` is not declared here because Makie's `@recipe` macro
requires Makie to be loaded before that plot type can exist.
"""
module PBDBMakie

"""
Bridge object for the vendored `PhyloPic` submodule owned by `PBDBMakieExt`.
"""
struct _PhyloPicBridge end

"""
    Base.getindex(::_PhyloPicBridge) -> Union{Module, Nothing}

Resolve the vendored `PhyloPic` submodule from the loaded `PBDBMakieExt`
extension. Returns `nothing` until the extension is loaded.
"""
function Base.getindex(::_PhyloPicBridge)::Union{Module, Nothing}
    ext = Base.get_extension(parentmodule(@__MODULE__), :PBDBMakieExt)
    isnothing(ext) && return nothing
    return getproperty(ext, :PhyloPic)
end

const _PhyloPic = _PhyloPicBridge()

function taxonomytreeplot end
function taxonomytreeplot! end
function set_rank_axis_ticks! end
function leaf_positions end
function augment_leaf_phylopic! end
function acquire_phylopic end
function augment_phylopic end
function augment_phylopic! end
function augment_phylopic_ranges end
function augment_phylopic_ranges! end
function phylopic_images_dataframe end
function phylopic_node end
function phylopic_images end
function pbdb_phylopic_grid end
function pbdb_phylopic_grid! end

export taxonomytreeplot
export taxonomytreeplot!
export set_rank_axis_ticks!
export leaf_positions
export augment_leaf_phylopic!
export acquire_phylopic
export augment_phylopic
export augment_phylopic!
export augment_phylopic_ranges
export augment_phylopic_ranges!
export phylopic_images_dataframe
export phylopic_node
export phylopic_images
export pbdb_phylopic_grid
export pbdb_phylopic_grid!

end # module PBDBMakie
