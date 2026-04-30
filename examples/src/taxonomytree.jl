using PaleobiologyDB.DataCaches: set_autocaching!
using PaleobiologyDB.TaxonomyMakie: taxonomytreeplot 
using CairoMakie

set_autocaching!(true)

fig, ax, plt = taxonomytreeplot(
    "Ursidae"; 
    leaf_rank = "species",
    show_phylopic = true
)
fig
