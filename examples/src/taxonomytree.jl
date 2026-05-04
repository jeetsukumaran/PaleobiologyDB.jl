using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.TaxonomyMakie: taxonomytreeplot

PaleobiologyDB.set_autocaching!(true)

fig, ax, plt = taxonomytreeplot(
    "Elephantidae";
    leaf_rank = "genus",
    show_leaf_labels = true,
    show_phylopic = true,
    phylopic_align = true,
    phylopic_on_missing = :skip,
    axis_kwargs = (; title = "Elephantidae genera"),
)

fig
