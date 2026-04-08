using CairoMakie, FileIO, Downloads
using PaleobiologyDB, PaleobiologyDB.Taxonomy

# Data

taxa = [
    "Tyrannosaurus",
    "Triceratops",
    "Ankylosaurus",
    "Pachycephalosaurus",
    "Edmontosaurus",
]
first_app = [68.0, 68.0, 70.0, 74.0, 76.0]   # first appearance (Ma)
last_app  = [66.0, 66.0, 66.0, 66.0, 66.0]   # last appearance (Ma)

# PhyloPic images

pics = [acquire_phylopic(t) for t in taxa]

# Plot

fig = Figure(size = (800, 420))
ax = Axis(
    fig[1, 1],
    xlabel = "Age (Ma)",
    title = "Latest Cretaceous taxa - stratigraphic ranges",
    yreversed = false,
    xreversed = true,
    yticks = (1:length(taxa), taxa),
    yticklabelsize = 13,
)

img_half_height = 0.38

for (i, (fa, la, rec)) in enumerate(zip(first_app, last_app, pics))
    lines!(ax, [fa, la], [i, i]; linewidth = 6, color = :gray30)

    if !ismissing(rec.phylopic_thumbnail)
        img = load(Downloads.download(rec.phylopic_thumbnail))
        w = size(img, 2) / size(img, 1)
        dx = img_half_height * w

        image!(
            ax,
            (fa - dx, fa + dx),
            (i - img_half_height, i + img_half_height),
            rotr90(img);
            interpolate = true,
        )
    end
end

xlims!(ax, 78, 64)
fig