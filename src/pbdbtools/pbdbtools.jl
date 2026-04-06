module Taxonomy

using CSV, DataFrames, Downloads

import ..pbdb_taxon

include("_scratchstore.jl")
include("_taxonomy.jl")

export taxon_occursin, contains_taxon

end
