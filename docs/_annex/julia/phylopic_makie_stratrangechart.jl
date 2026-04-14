# phylopic_makie_stratrangechart.jl
#
# Stratigraphic range chart with PhyloPic silhouettes using the
# PaleobiologyDB.PhyloPicMakie extension.
#
# Requirements:
#   pkg> add PaleobiologyDB CairoMakie

using PaleobiologyDB
using PaleobiologyDB.PhyloPicPBDB
using CairoMakie

# ── Data ──────────────────────────────────────────────────────────────────────

taxa = [
    "Tyrannosaurus",
    "Triceratops",
    "Ankylosaurus",
    "Pachycephalosaurus",
    "Edmontosaurus",
]
first_app = [68.0, 68.0, 70.0, 74.0, 76.0]   # first appearance (Ma)
last_app  = [66.0, 66.0, 66.0, 66.0, 66.0]   # last appearance (Ma)

# ── Figure ────────────────────────────────────────────────────────────────────

fig = Figure(size = (800, 420))
ax  = Axis(
    fig[1, 1];
    xlabel          = "Age (Ma)",
    title           = "Latest Cretaceous taxa — stratigraphic ranges",
    xreversed       = true,
    yticks          = (1:length(taxa), taxa),
    yticklabelsize  = 13,
)

# Draw range bars
for (i, (fa, la)) in enumerate(zip(first_app, last_app))
    lines!(ax, [fa, la], [i, i]; linewidth = 6, color = :gray30)
end

# Overlay PhyloPic silhouettes at first appearance
augment_phylopic_ranges!(
    ax,
    first_app,
    last_app,
    collect(1.0:length(taxa));
    taxon      = taxa,
    at         = :start,
    glyph_size = 0.38,
    placement  = :center,
)

xlims!(ax, 78, 64)
display(fig)
save("cretaceous_ranges_phylopic.png", fig)
