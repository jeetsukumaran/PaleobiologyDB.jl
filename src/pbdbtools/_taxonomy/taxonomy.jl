module Taxonomy

using CSV, DataFrames, Downloads, HTTP, JSON3
import Graphs

import ..pbdb_taxon
import ..pbdb_taxa

include("_taxonomy_resolution.jl")
include("_taxonomy_namevalidation.jl")
include("_taxonomy_augment.jl")
include("_taxonomy_queries.jl")
include("_taxonomy.jl")       # drop_unqualified_taxa (depends on the others above)
include("_taxonomygraphs.jl") # TaxonNode, TaxonTree, taxon_subtree (depends on queries)
end
