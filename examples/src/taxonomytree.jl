module TaxonomyTreeExample

import CairoMakie
import Makie
using PaleobiologyDB.DataCaches: set_autocaching!
using PaleobiologyDB.Taxonomy: TaxonomyTree, TaxonNode, taxon_subtree
using PaleobiologyDB.TaxonomyMakie: augment_leaf_phylopic!, taxonomytreeplot
using Graphs: SimpleDiGraph, add_edge!

const EXAMPLES_ROOT::String = normpath(joinpath(@__DIR__, ".."))
const BUILD_ROOT::String = joinpath(EXAMPLES_ROOT, "build")

function ensure_build_dir(; output_dir::Union{Nothing, AbstractString} = nothing)::String
    target_dir = isnothing(output_dir) ? BUILD_ROOT : String(output_dir)
    mkpath(target_dir)
    return target_dir
end

function materialize!(fig::Makie.Figure)::Nothing
    CairoMakie.Makie.update_state_before_display!(fig)
    return nothing
end

function save_example(
        fig::Makie.Figure,
        stem::AbstractString;
        output_dir::Union{Nothing, AbstractString} = nothing,
    )::String
    target_dir = ensure_build_dir(; output_dir)
    materialize!(fig)
    output_path = joinpath(target_dir, string(stem, ".png"))
    CairoMakie.save(output_path, fig)
    return output_path
end

function _placeholder_tree()::TaxonomyTree
    graph = SimpleDiGraph(6)
    add_edge!(graph, 1, 2)
    add_edge!(graph, 1, 5)
    add_edge!(graph, 2, 3)
    add_edge!(graph, 2, 4)
    add_edge!(graph, 5, 6)

    taxa = [
        TaxonNode("Placeholder tree", "order", 1, 1, missing),
        TaxonNode("Deterministic branch", "family", 2, 2, 1),
        TaxonNode(" ", "genus", 3, 3, 2),
        TaxonNode("  ", "genus", 4, 4, 2),
        TaxonNode("Deterministic crown", "family", 5, 5, 1),
        TaxonNode("   ", "genus", 6, 6, 5),
    ]
    vertex_of = Dict(1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6)
    return TaxonomyTree(graph, taxa, vertex_of, 1)
end

function _live_tree()::TaxonomyTree
    set_autocaching!(true)
    return taxon_subtree("Elephantidae"; leaf_rank = "genus")
end

function _one_step_plot(
        tree::Union{AbstractString, TaxonomyTree};
        title::AbstractString,
        show_leaf_labels::Bool,
        phylopic_on_missing::Symbol,
    )::Makie.FigureAxisPlot
    return taxonomytreeplot(
        tree;
        show_leaf_labels = show_leaf_labels,
        show_phylopic = true,
        phylopic_on_missing = phylopic_on_missing,
        phylopic_glyph_size = 0.55,
        phylopic_xoffset = 0.55,
        row_spacing = 3.0,
        axis_kwargs = (; title = title),
        figure_kwargs = (; size = (1200, 720)),
    )
end

function _two_step_plot(
        tree::TaxonomyTree;
        title::AbstractString,
        show_leaf_labels::Bool,
        phylopic_on_missing::Symbol,
    )::Makie.FigureAxisPlot
    result = taxonomytreeplot(
        tree;
        show_leaf_labels = show_leaf_labels,
        show_phylopic = false,
        row_spacing = 3.0,
        axis_kwargs = (; title = title),
        figure_kwargs = (; size = (1200, 720)),
    )
    figure, axis, plot = result
    augment_leaf_phylopic!(
        axis,
        plot;
        align = true,
        xoffset = 0.65,
        yoffset = 0.15,
        glyph_size = 0.55,
        aspect = :preserve,
        on_missing = phylopic_on_missing,
    )
    return result
end

function render_live_one_step_artifact(;
        output_dir::Union{Nothing, AbstractString} = nothing,
    )::String
    fig, ax, plot = _one_step_plot(
        _live_tree();
        title = "Elephantidae with integrated PhyloPic overlays",
        show_leaf_labels = true,
        phylopic_on_missing = :skip,
    )
    return save_example(fig, "taxonomytree_one_step_live"; output_dir)
end

function render_live_two_step_artifact(;
        output_dir::Union{Nothing, AbstractString} = nothing,
    )::String
    fig, ax, plot = _two_step_plot(
        _live_tree();
        title = "Elephantidae with explicit two-step PhyloPic overlays",
        show_leaf_labels = true,
        phylopic_on_missing = :skip,
    )
    return save_example(fig, "taxonomytree_two_step_live"; output_dir)
end

function render_placeholder_one_step_artifact(;
        output_dir::Union{Nothing, AbstractString} = nothing,
    )::String
    fig, ax, plot = _one_step_plot(
        _placeholder_tree();
        title = "Deterministic integrated placeholder overlay artifact",
        show_leaf_labels = false,
        phylopic_on_missing = :placeholder,
    )
    return save_example(fig, "taxonomytree_one_step_placeholder"; output_dir)
end

function render_placeholder_two_step_artifact(;
        output_dir::Union{Nothing, AbstractString} = nothing,
    )::String
    fig, ax, plot = _two_step_plot(
        _placeholder_tree();
        title = "Deterministic explicit two-step placeholder overlay artifact",
        show_leaf_labels = false,
        phylopic_on_missing = :placeholder,
    )
    return save_example(fig, "taxonomytree_two_step_placeholder"; output_dir)
end

function live_artifact_main(; output_dir::Union{Nothing, AbstractString} = nothing)::Vector{String}
    return String[
        render_live_one_step_artifact(; output_dir),
        render_live_two_step_artifact(; output_dir),
    ]
end

function smoke_main(; output_dir::Union{Nothing, AbstractString} = nothing)::Vector{String}
    return String[
        render_placeholder_one_step_artifact(; output_dir),
        render_placeholder_two_step_artifact(; output_dir),
    ]
end

function main()::Makie.Figure
    fig, ax, plot = _one_step_plot(
        _live_tree();
        title = "Elephantidae taxonomy tree with PhyloPic overlays",
        show_leaf_labels = true,
        phylopic_on_missing = :skip,
    )
    return fig
end

if abspath(PROGRAM_FILE) == @__FILE__
    display(main())
end

end # module TaxonomyTreeExample
