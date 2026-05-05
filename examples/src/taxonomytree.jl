using CairoMakie
using PaleobiologyDB
using PaleobiologyDB.TaxonomyMakie: taxonomytreeplot

PaleobiologyDB.set_autocaching!(true)

fig, ax, plt = taxonomytreeplot(                                   # <1>
    "Elephantidae";                                                # <2>
    leaf_rank                = "genus",                           # <3>
    strict_leaf_rank         = true,                              # <4>
    ladderize                = false,                             # <5>
    row_spacing              = 2.0,                               # <6>
    branch_color             = :black,                            # <7>
    branch_linewidth         = 1.5,                               # <7>
    show_nodes               = true,                              # <8>
    show_unifurcation_nodes  = true,                              # <9>
    node_color               = :black,                            # <8>
    node_size                = 5,                                 # <8>
    color_by_rank            = false,                             # <10>
    rank_palette             = nothing,                           # <11>
    show_leaf_labels         = true,                              # <12>
    leaf_label_fontsize      = 9,                                 # <12>
    leaf_label_color         = :black,                            # <12>
    leaf_label_xoffset       = 0.1,                               # <12>
    leaf_label_yoffset       = 0.0,                               # <12>
    showinternal             = false,                             # <13>
    internal_fontsize        = 7,                                 # <13>
    internal_color           = :gray40,                           # <13>
    show_phylopic            = true,                              # <14>
    phylopic_glyph_size      = 1.0,                               # <15>
    phylopic_align           = true,                              # <16>
    phylopic_xoffset         = 0.65,                              # <17>
    phylopic_yoffset         = 0.3,                               # <17>
    phylopic_on_missing      = :skip,                             # <18>
    phylopic_aspect          = :preserve,                         # <19>
    phylopic_image_rendering = :thumbnail,                        # <20>
    show_rank_ticks          = true,                              # <21>
    figure_kwargs            = (;),                               # <22>
    axis_kwargs              = (; title = "Elephantidae genera"),  # <23>
)

fig

# 1. Standalone call: builds `Figure` + `Axis` and returns a `FigureAxisPlot`.
# 2. PBDB root taxon name; `taxon_subtree` is called internally to fetch the hierarchy.
# 3. Prune the subtree at this rank; nodes at exactly `leaf_rank` become leaves.
# 4. `true` excludes orphaned finer-ranked taxa; `false` keeps them as extra leaves.
# 5. Sort each node's children by ascending subtree leaf count before layout (asymmetric spread).
# 6. Vertical gap between consecutive leaf rows in data units.
# 7. Branch line colour and width (used when `color_by_rank = false`).
# 8. Circular marker at every vertex; colour and size (used when `color_by_rank = false`).
# 9. `false` suppresses markers at single-child (pass-through) nodes; branches are still drawn.
# 10. Colour branches and nodes by taxonomic rank using the built-in `_RANK_COLORS` cycle.
# 11. `Dict{String,Any}` overriding specific rank colours; `nothing` uses the built-in cycle.
# 12. Text label to the right of each leaf: font size, colour, and x/y offset in data units.
# 13. Labels at internal (non-leaf) nodes; hidden by default to reduce clutter.
# 14. Fetch and render a PhyloPic silhouette beside each leaf label.
# 15. Half-height of each silhouette in data units (total rendered height = 2 × `phylopic_glyph_size`).
# 16. `true` aligns all silhouettes to a single right-hand column; `false` places each immediately after its label.
# 17. Additional rightward and vertical offset beyond the label anchor, in data units.
# 18. Policy when no PhyloPic image is found: `:skip` omits, `:placeholder` draws a stub, `:error` throws.
# 19. `:preserve` keeps the original image aspect ratio; `:stretch` renders as a square.
# 20. Which PhyloPic image URL to fetch: `:thumbnail`, `:raster`, `:og_image`, `:vector`, `:source_file`.
# 21. Label the x-axis with rank names at their dendrogram x-depth positions.
# 22. Extra keyword arguments forwarded verbatim to `Makie.Figure(; ...)`.
# 23. Extra keyword arguments forwarded verbatim to `Makie.Axis(; ...)`.
