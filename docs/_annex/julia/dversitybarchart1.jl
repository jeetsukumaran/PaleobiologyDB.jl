using CairoMakie, FileIO, Downloads, DataFrames
using PaleobiologyDB, PaleobiologyDB.Taxonomy

df = pbdb_occurrences(base_name = "Ceratopsia", interval = "Cretaceous",
                      show = "full", limit = 500)
df2 = augment_taxonomy(df)

# Occurrence counts per genus
counts = sort(
    combine(groupby(dropmissing(df2, :taxonomy_genus), :taxonomy_genus),
            nrow => :n),
    :n; rev = true
)
top = first(counts, 6)

# PhyloPic images for the top genera
pics = acquire_phylopic(
    DataFrame(g = top.taxonomy_genus), :g, "phylopic_"
)

fig = Figure(size = (700, 500))
ax  = Axis(fig[1, 1],
    xticks         = (1:nrow(top), top.taxonomy_genus),
    xticklabelrotation = π / 4,
    ylabel         = "Occurrence count",
    title          = "Most common Cretaceous ceratopsian genera",
)

for (i, (n, thumb)) in enumerate(zip(top.n, pics.phylopic_thumbnail))
    barplot!(ax, [i], [n]; color = (:steelblue, 0.7))
    if !ismissing(thumb)
        img = load(Downloads.download(thumb))
        w   = size(img, 2) / size(img, 1)
        h   = n * 0.25                        # image height = 25 % of bar
        image!(ax, [i - w * h / 2, i + w * h / 2], [n * 0.02, n * 0.02 + h],
               rotr90(img); interpolate = true)
    end
end

display(fig)
