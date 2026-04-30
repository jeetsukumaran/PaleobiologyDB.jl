# Set up data caching
using PaleobiologyDB.DataCaches: set_autocaching!

# A Makie back-end, here "CairoMakie" needs to be 
# loaded in the environment for `PaleobiologyDB.TaxonomyMakie`
# to be available
using CairoMakie 

# Load the taxonomy visualizier
using PaleobiologyDB.TaxonomyMakie: taxonomytreeplot 

# Save/re-use local copies of query results 
# instead of re-running repeated queries live
set_autocaching!(true)

# Visualize the taxonomy
fig, ax, plt = taxonomytreeplot(
    "Elephantidae"; 
    leaf_rank = "genus",
    show_phylopic = true
)
fig
