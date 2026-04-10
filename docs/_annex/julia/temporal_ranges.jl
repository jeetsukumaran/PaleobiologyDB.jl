using PaleobiologyDB
using CairoMakie, FileIO
using PaleobiologyDB.PhyloPicMakie

function plot_taxon_temporal_ranges(
    taxa::Vector{String},
    first_app::Vector{<:Real},
    last_app::Vector{<:Real};
    fig_size = (800, 420),
    xlabel = "Age (Ma)",
    xreversed = true,
    yticklabelsize = 13,
    line_width = 6,
    line_color = :gray30,
    glyph_at = :start,
    glyph_size = 0.38,
    glyph_placement = :center,
    xlims = (nothing, nothing),
)

    fig = Figure()

    ax = Axis(
        fig[1, 1];
        xlabel = xlabel,
        xreversed = xreversed,
        yticks = (1:length(taxa), taxa),
        yticklabelsize = yticklabelsize,
    )

    for (i, (fa, la)) in enumerate(zip(first_app, last_app))
        lines!(ax, [fa, la], [i, i];
            linewidth = line_width,
            color = line_color
        )
    end

    augment_phylopic_ranges!(
        ax,
        first_app,
        last_app,
        collect(1.0:length(taxa));
        taxon = taxa,
        at = glyph_at,
        glyph_size = glyph_size,
        placement = glyph_placement,
    )

    if xlims != (nothing, nothing)
        xlims!(ax, xlims...)
    end

    display(fig)
    return fig
end

taxa      = ["Tyrannosaurus", "Triceratops", "Ankylosaurus",
             "Pachycephalosaurus", "Edmontosaurus"]
first_app = [68.0, 68.0, 70.0, 74.0, 76.0]
last_app  = [66.0, 66.0, 66.0, 66.0, 66.0]

fig = plot_taxon_temporal_ranges(
    taxa,
    first_app,
    last_app;
    fig_size = (800, 420),
    xlabel = "Age (Ma)",
    xreversed = true,
    yticklabelsize = 13,
    line_width = 6,
    line_color = :gray30,
    glyph_at = :start,
    glyph_size = 0.38,
    glyph_placement = :center,
    xlims = (nothing, nothing),
)
