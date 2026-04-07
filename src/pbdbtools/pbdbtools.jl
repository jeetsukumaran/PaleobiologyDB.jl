module Taxonomy

using CSV, DataFrames, Downloads, HTTP, JSON3

import ..pbdb_taxon
import ..pbdb_taxa

include("_scratchstore.jl")
include("_taxonomy.jl")

export taxon_occursin, contains_taxon,
    acquire_phylopic, augment_phylopic

end
