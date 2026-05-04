using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.TaxonomyMakie: pbdb_phylopic_grid

PaleobiologyDB.set_autocaching!(true)

fig = pbdb_phylopic_grid(
    ["Felis", "Canis", "Panthera", "Lynx"];
    image_filter = :primary,
    ncols = 2,
)
fig
