module DataCurator

using CSV, DataFrames, Downloads

import ..pbdb_taxon

include("_scratchstore.jl")
include("_taxonomy.jl")

end
