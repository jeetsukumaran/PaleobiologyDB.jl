using CairoMakie
using PaleobiologyDB.TaxonomyMakie: pbdb_phylopic_grid

fig, ax, plt = taxonomytreeplot(
    "Canis"; 
    leaf_rank = "species",
    show_phylopic = true
)
fig
