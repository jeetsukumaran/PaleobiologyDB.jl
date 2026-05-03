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

output_path = abspath(get(ARGS, 1, "taxonomytree.png"))
save(output_path, fig)
println("Saved taxonomy tree example to $(output_path)")
