using CairoMakie
using PaleobiologyDB.TaxonomyMakie: pbdb_phylopic_grid

fig = pbdb_phylopic_grid(["Felis"])
fig