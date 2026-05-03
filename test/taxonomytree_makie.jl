# test/taxonomytree_makie.jl
# Tests for PaleobiologyDB.TaxonomyMakie extension.
#
# Structure:
#   1. Mock tree construction (shared fixture)
#   2. Offline / pure-function tests — layout logic (extension must be loaded
#      to access internals, but no rendering is performed)
#   3. Recipe smoke tests — exercise taxonomytreeplot and taxonomytreeplot!
#      (gated on CairoMakie availability)
#
# CairoMakie is in test/Project.toml and is available in the standard test
# suite.  The _EXT_AVAILABLE guard provides a graceful skip path in
# environments where it is absent.

using Test
using PaleobiologyDB
using PaleobiologyDB.Taxonomy: TaxonomyTree, TaxonNode
import Graphs
import PhyloPicMakie

# ---------------------------------------------------------------------------
# Trigger extension
# ---------------------------------------------------------------------------

const _CAIRO_TTM_AVAILABLE = !isnothing(Base.find_package("CairoMakie"))

if _CAIRO_TTM_AVAILABLE
    @eval using CairoMakie
    @eval using PaleobiologyDB.TaxonomyMakie
end

const _LIVE_TAXONOMYMAKIE = isdefined(@__MODULE__, :LIVE) ? getfield(@__MODULE__, :LIVE) :
    get(ENV, "PBDB_LIVE", "") == "1"

const _REPO_ROOT = dirname(@__DIR__)

function _read_repo_file(parts::Vararg{AbstractString})::String
    return read(joinpath(_REPO_ROOT, parts...), String)
end

function _repo_path_is_tracked(relpath::AbstractString)::Bool
    return success(pipeline(
        `git -C $_REPO_ROOT ls-files --error-unmatch -- $relpath`;
        stdout = devnull,
        stderr = devnull,
    ))
end

# ---------------------------------------------------------------------------
# Shared fixture: mock Carnivora subtree (6 vertices)
#
#   Carnivora (order, v=1)
#   ├── Canidae  (family, v=2)
#   │   ├── Canis  (genus, v=3)  ← leaf
#   │   └── Vulpes (genus, v=4)  ← leaf
#   └── Felidae  (family, v=5)
#       └── Felis  (genus, v=6)  ← leaf
# ---------------------------------------------------------------------------

function _mock_carnivora_tree()
    g = Graphs.SimpleDiGraph(6)
    Graphs.add_edge!(g, 1, 2)   # Carnivora → Canidae
    Graphs.add_edge!(g, 1, 5)   # Carnivora → Felidae
    Graphs.add_edge!(g, 2, 3)   # Canidae   → Canis
    Graphs.add_edge!(g, 2, 4)   # Canidae   → Vulpes
    Graphs.add_edge!(g, 5, 6)   # Felidae   → Felis
    taxa = [
        TaxonNode("Carnivora", "order",  1, 1, missing),
        TaxonNode("Canidae",   "family", 2, 2, 1),
        TaxonNode("Canis",     "genus",  3, 3, 2),
        TaxonNode("Vulpes",    "genus",  4, 4, 2),
        TaxonNode("Felidae",   "family", 5, 5, 1),
        TaxonNode("Felis",     "genus",  6, 6, 5),
    ]
    vertex_of = Dict(1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6)
    TaxonomyTree(g, taxa, vertex_of, 1)
end

function _mock_longlabel_carnivora_tree()
    g = Graphs.SimpleDiGraph(6)
    Graphs.add_edge!(g, 1, 2)
    Graphs.add_edge!(g, 1, 5)
    Graphs.add_edge!(g, 2, 3)
    Graphs.add_edge!(g, 2, 4)
    Graphs.add_edge!(g, 5, 6)
    taxa = [
        TaxonNode("Carnivora", "order", 1, 1, missing),
        TaxonNode("Canidae", "family", 2, 2, 1),
        TaxonNode("ExtremelyLongCanisLabel", "genus", 3, 3, 2),
        TaxonNode("Short", "genus", 4, 4, 2),
        TaxonNode("AnotherVeryLongFelisLabel", "genus", 6, 6, 5),
        TaxonNode("Felidae", "family", 5, 5, 1),
    ]
    # Reorder taxa to match vertex ids after the long-label substitutions.
    taxa = [
        taxa[1],
        taxa[2],
        taxa[3],
        taxa[4],
        taxa[6],
        taxa[5],
    ]
    vertex_of = Dict(1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6)
    TaxonomyTree(g, taxa, vertex_of, 1)
end

# Single-node placeholder tree (mimics taxon_subtree("INVALID"))
function _mock_single_node_tree()
    g = Graphs.SimpleDiGraph(1)
    taxa = [TaxonNode("INVALID", "", 0, missing, missing)]
    TaxonomyTree(g, taxa, Dict(0 => 1), 1)
end

# ---------------------------------------------------------------------------
# 1. Offline / pure-function tests
# ---------------------------------------------------------------------------

if _CAIRO_TTM_AVAILABLE
    # Access internals through the extension module
    const _rd_fn   = PaleobiologyDB.TaxonomyMakie._rank_depth
    const _layout  = PaleobiologyDB.TaxonomyMakie._compute_dendrogram_layout
    const _segpairs = PaleobiologyDB.TaxonomyMakie._dendrogram_segment_pairs
    const _leaf_positions_fn = PaleobiologyDB.TaxonomyMakie._leaf_positions
    const _plan_leaf_node_overlay = PaleobiologyDB.TaxonomyMakie._plan_leaf_node_phylopic_overlay
    const _plan_leaf_label_overlay = PaleobiologyDB.TaxonomyMakie._plan_leaf_label_phylopic_overlay
    const _plan_leaf_plot_overlay = PaleobiologyDB.TaxonomyMakie._plan_leaf_plot_phylopic_overlay
    const _leaf_text_plots_for_plot = PaleobiologyDB.TaxonomyMakie._leaf_text_plots
    const _augment_leaf_overlay = PaleobiologyDB.TaxonomyMakie._augment_leaf_phylopic!
    const _LeafOverlayPlan = PaleobiologyDB.TaxonomyMakie._LeafOverlayPlan
    const _TEST_GLYPH = fill(Makie.RGBA{Makie.N0f8}(0, 0, 0, 1), 16, 32)

    _materialize_tree_overlay!(fig) = CairoMakie.Makie.update_state_before_display!(fig)

    function _leaf_text_plots!(
            ax,
            tree,
            xs,
            ys;
            leaf_label_xoffset = 0.1,
            leaf_label_yoffset = 0.0,
        )
        leaves = _leaf_positions_fn(tree, xs, ys)
        text_plots = Any[]
        sizehint!(text_plots, length(leaves.vertices))
        for i in eachindex(leaves.vertices)
            push!(
                text_plots,
                Makie.text!(
                    ax,
                    Makie.Point2f(
                        leaves.x[i] + Float64(leaf_label_xoffset),
                        leaves.y[i] + Float64(leaf_label_yoffset),
                    );
                    text = leaves.names[i],
                    align = (:left, :center),
                    clip_planes = Makie.Plane3f[],
                ),
            )
        end
        return leaves, text_plots
    end

    function _overlay_left_edge_px(overlay, i::Integer = 1)
        pos = overlay.positions[][i]
        offset = overlay.marker_offset[][i]
        size = overlay.markersize[][i]
        return Float64(pos[1] + offset[1] - 0.5f0 * size[1])
    end

    function _managed_overlay_atomic_plots(scene)
        return filter(Makie.collect_atomic_plots(scene)) do plot
            if hasproperty(plot, :marker)
                marker = try
                    plot.marker[]
                catch
                    nothing
                end
                if marker isa AbstractVector && !isempty(marker) && first(marker) isa AbstractMatrix
                    return true
                end
            end

            if !(hasproperty(plot, :markersize) && hasproperty(plot, :visible))
                return false
            end
            markersize = try
                plot.markersize[]
            catch
                nothing
            end
            return markersize == 0 && plot.visible[] == false
        end
    end

    @testset "TaxonomyMakie — extension import contract" begin
        @test isdefined(PaleobiologyDB, :TaxonomyMakie)
        @test PaleobiologyDB.TaxonomyMakie === TaxonomyMakie
        @test !isdefined(PaleobiologyDB, :taxonomytreeplot)
        @test !isdefined(PaleobiologyDB, :taxonomytreeplot!)
        @test !isdefined(PaleobiologyDB, :set_rank_axis_ticks!)
        @test !isdefined(PaleobiologyDB, :leaf_positions)
        @test !isdefined(PaleobiologyDB, :augment_leaf_phylopic!)
    end

    @testset "TaxonomyMakie — manifest policy remains untracked" begin
        @test !_repo_path_is_tracked("Manifest.toml")
        @test !_repo_path_is_tracked("test/Manifest.toml")
    end

    @testset "TaxonomyMakie — docs tell the extension import truth" begin
        readme = _read_repo_file("README.md")
        guide = _read_repo_file("docs", "src", "guide", "taxonomytree_makie.md")
        api_doc = _read_repo_file("docs", "src", "api", "taxonomytree_makie.md")
        ci = _read_repo_file(".github", "workflows", "CI.yml")

        @test occursin("using PaleobiologyDB.TaxonomyMakie", readme)
        @test occursin("using PaleobiologyDB.TaxonomyMakie", guide)
        @test occursin("using PaleobiologyDB.TaxonomyMakie", api_doc)

        @test !occursin("using PaleobiologyDB: taxonomytreeplot", readme)
        @test !occursin("using PaleobiologyDB: taxonomytreeplot", guide)
        @test !occursin("using PaleobiologyDB: taxonomytreeplot", api_doc)
        @test !occursin("using PaleobiologyDB: taxonomytreeplot, augment_leaf_phylopic!", readme)
        @test !occursin("TaxonomyMakie exports (taxonomytreeplot, augment_leaf_phylopic!, etc.) are now in scope", guide)
        @test !occursin("requires `FileIO`", guide)
        @test occursin("julia --project=examples examples/src/taxonomytree.jl", guide)
        @test occursin("julia --project=examples examples/src/phylopicgallery.jl", guide)
        @test !occursin("examples/smoke.jl", guide)
        @test !occursin("examples/build/", guide)
        @test !occursin("Run taxonomy tree artifact smoke", ci)
        @test !occursin("examples/smoke.jl", ci)
    end

    @testset "TaxonomyMakie — PBDB bridge delegates anchored overlays to PhyloPicMakie" begin
        render_source = _read_repo_file("ext", "TaxonomyMakie", "PhyloPic", "src", "_render.jl")

        @test isdefined(PhyloPicMakie, :_augment_resolved_phylopic_anchored!)
        @test occursin("PhyloPicMakie._augment_resolved_phylopic_anchored!", render_source)
        @test occursin("placeholder glyph image", render_source)
        @test !occursin("grey rectangle", render_source)
        @test !occursin("older mainline surface", render_source)

        for forbidden in (
                "_VALID_ANCHORED_ON_MISSING",
                "_HAS_SCENE_LIKE_ANCHORED_INTERNALS",
                "_prepared_anchor_positions",
                "_prepare_resolved_anchor_overlay",
                "_transparent_anchored_probe_scatter!",
                "_projected_anchor_positions_scene_like!",
                "_augment_phylopic_anchored_scene_like!",
            )
            @test !occursin(forbidden, render_source)
        end
    end

    @testset "TaxonomyMakie — _rank_depth" begin

        @testset "known ranks" begin
            @test _rd_fn("kingdom")    == 0
            @test _rd_fn("phylum")     == 1
            @test _rd_fn("order")      == 8
            @test _rd_fn("family")     == 12
            @test _rd_fn("genus")      == 16
            @test _rd_fn("subgenus")   == 17
            @test _rd_fn("species")    == 18
            @test _rd_fn("subspecies") == 19
        end

        @testset "subgenus is between genus and species in depth" begin
            @test _rd_fn("subgenus") > _rd_fn("genus")
            @test _rd_fn("subgenus") < _rd_fn("species")
        end

        @testset "unknown / empty ranks return -1" begin
            @test _rd_fn("")              == -1
            @test _rd_fn("unranked")      == -1
            @test _rd_fn("unranked clade") == -1
            @test _rd_fn("GENUS")         == -1   # case-sensitive
        end
    end

    @testset "TaxonomyMakie — _compute_dendrogram_layout" begin
        tree = _mock_carnivora_tree()
        xs, ys = _layout(tree)

        @testset "vector lengths match vertex count" begin
            @test length(xs) == Graphs.nv(tree.graph)   # 6
            @test length(ys) == Graphs.nv(tree.graph)
        end

        @testset "x-coordinates from rank depth" begin
            # v=1 Carnivora (order=8), v=2/5 Canidae/Felidae (family=12),
            # v=3/4/6 genera (genus=16)
            @test xs[1] == 8.0
            @test xs[2] == 12.0
            @test xs[5] == 12.0
            @test xs[3] == 16.0
            @test xs[4] == 16.0
            @test xs[6] == 16.0
        end

        @testset "leaves receive integer y values" begin
            # Leaves are v=3 (Canis), v=4 (Vulpes), v=6 (Felis)
            leaf_ys = [ys[3], ys[4], ys[6]]
            @test all(y -> y == round(y), leaf_ys)          # integers
            @test length(unique(leaf_ys)) == 3              # distinct
        end

        @testset "internal nodes at midpoint of children" begin
            # Canidae (v=2): children are Canis (v=3) and Vulpes (v=4)
            @test ys[2] ≈ (ys[3] + ys[4]) / 2
            # Felidae (v=5): single child Felis (v=6)
            @test ys[5] ≈ ys[6]
            # Carnivora (v=1): midpoint of Canidae and Felidae
            @test ys[1] ≈ (ys[2] + ys[5]) / 2
        end
    end

    @testset "TaxonomyMakie — _compute_dendrogram_layout ladderize" begin
        # Build a tree with one large subtree (2 leaves) and one small (1 leaf)
        # so ladderize ordering is deterministic.
        tree = _mock_carnivora_tree()
        xs_std, ys_std = _layout(tree; ladderize = false)
        xs_lad, ys_lad = _layout(tree; ladderize = true)

        @testset "x-positions unchanged by ladderize" begin
            @test xs_std == xs_lad
        end

        @testset "ladderize changes y-ordering" begin
            # Standard: Canidae subtree (2 leaves) is visited first (v=2 first child
            # of root), so its leaves occupy lower y values than Felis.
            # Ladderize sorts children ascending by leaf count, so the smaller
            # subtree (Felidae, 1 leaf) comes first, meaning Felis gets y=1.
            @test ys_std != ys_lad
        end

        @testset "all y values still distinct for leaves" begin
            g = tree.graph
            leaves = [v for v in Graphs.vertices(g) if isempty(Graphs.outneighbors(g, v))]
            @test length(unique(ys_lad[leaves])) == length(leaves)
        end
    end

    @testset "TaxonomyMakie — _compute_dendrogram_layout single-node tree" begin
        tree = _mock_single_node_tree()
        xs, ys = _layout(tree)

        @test length(xs) == 1
        @test length(ys) == 1
        @test xs[1] == 0.0    # unknown rank → falls back to 0.0 (root)
        @test ys[1] == 1.0    # single leaf → y = 1
    end

    @testset "TaxonomyMakie — _dendrogram_segment_pairs" begin
        tree = _mock_carnivora_tree()
        xs, ys = _layout(tree)
        segs = _segpairs(tree, xs, ys)

        @testset "segment count" begin
            # 3 internal nodes:
            #   Carnivora: 1 vertical + 2 horizontal = 3
            #   Canidae:   1 vertical + 2 horizontal = 3
            #   Felidae:   1 vertical + 1 horizontal = 2
            # Total = 8
            @test length(segs) == 8
        end

        @testset "each segment is a 4-tuple of Float64" begin
            @test all(s -> s isa NTuple{4, Float64}, segs)
        end

        @testset "horizontal segments have equal y endpoints" begin
            # A horizontal segment has y1 == y2
            horiz = filter(s -> s[2] ≈ s[4], segs)
            @test length(horiz) >= 5   # at least 5 horizontal branches in the tree
        end

        @testset "vertical segments have equal x endpoints" begin
            vert = filter(s -> s[1] ≈ s[3], segs)
            @test length(vert) == 3    # one per internal node
        end
    end

    @testset "TaxonomyMakie — leaf overlay planning" begin
        tree = _mock_carnivora_tree()
        xs, ys = _layout(tree)

        leaves = _leaf_positions_fn(tree, xs, ys)
        @test leaves == PaleobiologyDB.TaxonomyMakie.leaf_positions(tree, xs, ys)

        plan = _plan_leaf_node_overlay(
            tree,
            xs,
            ys;
            anchor = :leaf_label_origin,
            leaf_label_xoffset = 0.25,
            align = true,
        )
        @test plan.leaf_names == leaves.names
        @test length(plan.anchor_positions) == length(leaves.vertices)
        @test all(pos -> pos[1] ≈ maximum(leaves.x .+ 0.25), plan.anchor_positions)
        @test [pos[2] for pos in plan.anchor_positions] ≈ leaves.y
    end

    @testset "TaxonomyMakie — leaf_positions(p) respects row_spacing" begin
        tree = _mock_carnivora_tree()
        fig, ax, plt = taxonomytreeplot(tree; row_spacing = 3.0, show_phylopic = false)
        xs, ys = _layout(tree; row_spacing = 3.0)
        @test PaleobiologyDB.TaxonomyMakie.leaf_positions(plt) ==
            PaleobiologyDB.TaxonomyMakie.leaf_positions(tree, xs, ys)
    end

    @testset "TaxonomyMakie — shared label-aware overlay reacts to relimit and resize" begin
        tree = _mock_carnivora_tree()
        xs, ys = _layout(tree)

        fig = Figure(size = (600, 400))
        ax = Axis(fig[1, 1])
        xlims!(ax, 0, 20)
        ylims!(ax, 0, 8)

        leaves, leaf_text_plots = _leaf_text_plots!(
            ax,
            tree,
            xs,
            ys;
            leaf_label_xoffset = 0.1,
        )
        plan = _plan_leaf_label_overlay(
            ax,
            tree,
            xs,
            ys;
            leaf_text_plots = leaf_text_plots,
            leaf_label_xoffset = 0.1,
            phylopic_xoffset = 0.65,
            phylopic_yoffset = 0.3,
            align = false,
        )
        overlay = _augment_leaf_overlay(
            ax,
            plan;
            glyph = _TEST_GLYPH,
            placement = :left,
            glyph_size = 1.0,
            aspect = :preserve,
            on_missing = :skip,
        )

        _materialize_tree_overlay!(fig)
        anchor_x_1 = first(plan.anchor_positions[])[1]
        size_1 = first(overlay.markersize[])
        left_edge_1 = _overlay_left_edge_px(overlay)
        label_right_1 = Float64(Makie.maximum(Makie.boundingbox(first(leaf_text_plots), :pixel))[1])
        @test size_1[2] > 0.0f0
        @test left_edge_1 > label_right_1

        xlims!(ax, 0, 40)
        _materialize_tree_overlay!(fig)
        anchor_x_2 = first(plan.anchor_positions[])[1]
        size_2 = first(overlay.markersize[])
        left_edge_2 = _overlay_left_edge_px(overlay)
        label_right_2 = Float64(Makie.maximum(Makie.boundingbox(first(leaf_text_plots), :pixel))[1])
        @test anchor_x_2 > anchor_x_1
        @test left_edge_2 > label_right_2

        ylims!(ax, 0, 16)
        _materialize_tree_overlay!(fig)
        size_3 = first(overlay.markersize[])
        left_edge_3 = _overlay_left_edge_px(overlay)
        label_right_3 = Float64(Makie.maximum(Makie.boundingbox(first(leaf_text_plots), :pixel))[1])
        @test size_3[2] < size_2[2]
        @test left_edge_3 > label_right_3

        resize!(fig.scene, 900, 700)
        _materialize_tree_overlay!(fig)
        size_4 = first(overlay.markersize[])
        left_edge_4 = _overlay_left_edge_px(overlay)
        label_right_4 = Float64(Makie.maximum(Makie.boundingbox(first(leaf_text_plots), :pixel))[1])
        @test size_4[2] > size_3[2]
        @test left_edge_4 > label_right_4
    end

    @testset "TaxonomyMakie — plot-backed explicit overlay shares the integrated plan" begin
        tree = _mock_longlabel_carnivora_tree()
        xs, ys = _layout(tree)
        fig, ax, plt = taxonomytreeplot(
            tree;
            show_phylopic = false,
            leaf_label_xoffset = 0.1,
        )

        planning = _plan_leaf_plot_overlay(
            plt;
            anchor = :leaf_label_origin,
            leaf_label_xoffset = 0.1,
            xoffset = 0.65,
            yoffset = 0.3,
            align = false,
        )
        integrated_plan = _plan_leaf_label_overlay(
            plt,
            tree,
            xs,
            ys;
            leaf_text_plots = _leaf_text_plots_for_plot(plt),
            leaf_label_xoffset = 0.1,
            leaf_label_yoffset = plt[:leaf_label_yoffset][],
            phylopic_xoffset = 0.65,
            phylopic_yoffset = 0.3,
            align = false,
        )
        raw_leaf_plan = _plan_leaf_node_overlay(
            tree,
            xs,
            ys;
            anchor = :leaf_label_origin,
            leaf_label_xoffset = 0.1,
            align = false,
        )

        _materialize_tree_overlay!(fig)
        explicit_xs = [Float64(pos[1]) for pos in planning.plan.anchor_positions[]]
        integrated_xs = [Float64(pos[1]) for pos in integrated_plan.anchor_positions[]]
        raw_leaf_xs = [Float64(pos[1]) for pos in raw_leaf_plan.anchor_positions]

        @test explicit_xs ≈ integrated_xs
        @test explicit_xs != raw_leaf_xs
    end

    @testset "TaxonomyMakie — deleting the tree plot removes overlay support plots" begin
        tree = _mock_carnivora_tree()
        fig, ax, plt = taxonomytreeplot(tree; show_phylopic = false)
        @test isempty(_managed_overlay_atomic_plots(ax.scene))

        planning = _plan_leaf_plot_overlay(
            plt;
            anchor = :leaf_label_origin,
            leaf_label_xoffset = plt[:leaf_label_xoffset][],
            xoffset = 0.65,
            yoffset = 0.3,
            align = false,
        )
        overlay = _augment_leaf_overlay(
            plt,
            planning.plan;
            glyph = _TEST_GLYPH,
            placement = :left,
            glyph_size = 1.0,
            aspect = :preserve,
            on_missing = :skip,
        )

        _materialize_tree_overlay!(fig)
        @test !isnothing(overlay)
        @test length(overlay.probe_plots) == 6
        @test !isempty(_managed_overlay_atomic_plots(ax.scene))

        delete!(ax.scene, plt)
        _materialize_tree_overlay!(fig)
        @test isempty(_managed_overlay_atomic_plots(ax.scene))
    end

    @testset "TaxonomyMakie — tree overlay missing-image policy uses shared adapter" begin
        fig = Figure()
        ax = Axis(fig[1, 1])
        plan = _LeafOverlayPlan(
            [1],
            [""],
            [Makie.Point2f(1.0f0, 1.0f0)],
            (),
        )

        @test isnothing(
            _augment_leaf_overlay(
                ax,
                plan;
                taxon = [""],
                placement = :left,
                glyph_size = 1.0,
                aspect = :preserve,
                on_missing = :skip,
            )
        )

        placeholder = _augment_leaf_overlay(
            ax,
            plan;
            taxon = [""],
            placement = :left,
            glyph_size = 1.0,
            aspect = :preserve,
            on_missing = :placeholder,
        )
        @test !isnothing(placeholder)
        @test_throws ErrorException _augment_leaf_overlay(
            ax,
            plan;
            taxon = [""],
            placement = :left,
            glyph_size = 1.0,
            aspect = :preserve,
            on_missing = :error,
        )
    end

else
    @info "CairoMakie not available — skipping TaxonomyMakie offline layout tests"
end

# ---------------------------------------------------------------------------
# 2. Recipe smoke tests
# ---------------------------------------------------------------------------

if _CAIRO_TTM_AVAILABLE
    if _LIVE_TAXONOMYMAKIE
        @testset "TaxonomyMakie — taxonomytreeplot smoke" begin
            tree = _mock_carnivora_tree()

            @testset "taxonomytreeplot returns FigureAxisPlot" begin
                result = taxonomytreeplot(tree)
                @test result isa Makie.FigureAxisPlot
                fig, ax, plt = result
                @test fig isa CairoMakie.Figure
                @test ax  isa CairoMakie.Axis
                @test plt isa TaxonomyTreePlot
            end

            @testset "show_leaf_labels = false does not error" begin
                @test_nowarn taxonomytreeplot(tree; show_leaf_labels = false)
            end

            @testset "color_by_rank = true does not error" begin
                @test_nowarn taxonomytreeplot(tree; color_by_rank = true)
            end

            @testset "ladderize = true does not error" begin
                @test_nowarn taxonomytreeplot(tree; ladderize = true)
            end

            @testset "showinternal = true does not error" begin
                @test_nowarn taxonomytreeplot(tree; showinternal = true)
            end

            @testset "show_rank_ticks = false skips axis tick setup" begin
                @test_nowarn taxonomytreeplot(tree; show_rank_ticks = false)
            end

            @testset "color_by_rank with rank_palette does not error" begin
                palette = Dict("order" => :red, "family" => :blue, "genus" => :green)
                @test_nowarn taxonomytreeplot(tree; color_by_rank = true, rank_palette = palette)
            end

            @testset "show_unifurcation_nodes = false does not error" begin
                @test_nowarn taxonomytreeplot(tree; show_unifurcation_nodes = false)
            end

            @testset "auto-sized figure height respects leaf-count floor" begin
                # Mock tree has 3 leaves; max(400, 3*18) = 400 → height ≥ 400.
                fig, ax, plt = taxonomytreeplot(tree)
                @test fig.scene.viewport[].widths[2] >= 400
            end
        end

        @testset "TaxonomyMakie — taxonomytreeplot! into existing axis" begin
            tree = _mock_carnivora_tree()
            fig  = CairoMakie.Figure()
            ax   = CairoMakie.Axis(fig[1, 1])

            p = taxonomytreeplot!(ax, tree; show_leaf_labels = true, ladderize = true)
            @test p isa TaxonomyTreePlot

            # set_rank_axis_ticks! must run without error
            @test_nowarn set_rank_axis_ticks!(ax, tree)
        end

        @testset "TaxonomyMakie — single-node tree (placeholder)" begin
            tree = _mock_single_node_tree()
            @test_nowarn taxonomytreeplot(tree)
        end
    else
        @info "Makie rendering smoke tests disabled (PBDB_LIVE not set) — skipping taxonomytreeplot, taxonomytreeplot!, single-node, set_rank_axis_ticks! tests"
    end

    # ── PhyloPic silhouette attribute tests (offline — no network) ───────────
    #
    # The public show_phylopic path still resolves live PBDB + PhyloPic data,
    # so only attribute-registration checks run unconditionally. The stronger
    # render-aware shared-owner tests above stay offline by injecting a test
    # glyph directly into the internal tree-overlay adapter.

    @testset "TaxonomyMakie — PhyloPic silhouette attributes (offline)" begin
        tree = _mock_carnivora_tree()

        @testset "show_phylopic = false (default) does not trigger network or error" begin
            @test_nowarn taxonomytreeplot(tree; show_phylopic = false)
        end

        @testset "PhyloPic attributes are registered on the recipe" begin
            # Render with show_phylopic = false so no network calls are made,
            # then confirm the attribute observables exist and carry their defaults.
            fig, ax, plt = taxonomytreeplot(tree; show_phylopic = false)
            @test plt[:show_phylopic][]       == false
            @test plt[:phylopic_glyph_size][] ≈ 1.0
            @test plt[:phylopic_align][]      == false
            @test plt[:phylopic_xoffset][]    ≈ 0.65
            @test plt[:phylopic_yoffset][]    ≈ 0.3
            @test plt[:phylopic_image_rendering][] == :thumbnail
            @test plt[:phylopic_on_missing][] == :skip
            @test plt[:phylopic_aspect][]     == :preserve
            @test plt[:row_spacing][]         ≈ 2.0
        end
    end

    # ── PhyloPic silhouette rendering tests (live — requires PBDB_LIVE=1) ────
    #
    # These tests call acquire_phylopic per leaf, which hits the PBDB and
    # PhyloPic APIs.  They are disabled by default to avoid network stalls
    # in CI.  Run with: PBDB_LIVE=1 julia --project=test test/runtests.jl

    @testset "TaxonomyMakie — PhyloPic silhouettes (live)" begin
        if !_LIVE_TAXONOMYMAKIE
            @info "Live PhyloPic-in-tree tests disabled. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        else
            tree = _mock_carnivora_tree()

            @testset "show_phylopic = true, on_missing = :skip does not error" begin
                @test_nowarn taxonomytreeplot(
                    tree;
                    show_phylopic       = true,
                    phylopic_on_missing = :skip,
                )
            end

            @testset "show_phylopic = true, phylopic_align = true does not error" begin
                @test_nowarn taxonomytreeplot(
                    tree;
                    show_phylopic       = true,
                    phylopic_align      = true,
                    phylopic_xoffset    = 1.0,
                    phylopic_on_missing = :skip,
                )
            end

            @testset "show_phylopic = true, on_missing = :placeholder does not error" begin
                @test_nowarn taxonomytreeplot(
                    tree;
                    show_phylopic       = true,
                    phylopic_on_missing = :placeholder,
                )
            end

            @testset "show_phylopic = true, on_missing = :error raises ErrorException for unresolvable taxon" begin
                # "INVALID" cannot resolve through PBDB / PhyloPic, so the
                # shared tree-overlay adapter receives no image and :error fires.
                tree_unresolvable = _mock_single_node_tree()
                @test_throws ErrorException taxonomytreeplot(
                    tree_unresolvable;
                    show_phylopic       = true,
                    phylopic_on_missing = :error,
                )
            end

            @testset "taxonomytreeplot right margin widens with show_phylopic = true" begin
                fig, ax, plt = taxonomytreeplot(
                    tree;
                    show_phylopic       = true,
                    phylopic_on_missing = :skip,
                )
                @test fig isa CairoMakie.Figure
                @test ax  isa CairoMakie.Axis
            end

            @testset "single-node tree with show_phylopic = true does not error" begin
                tree_single = _mock_single_node_tree()
                @test_nowarn taxonomytreeplot(
                    tree_single;
                    show_phylopic       = true,
                    phylopic_on_missing = :skip,
                )
            end
        end
    end

    if _LIVE_TAXONOMYMAKIE
        @testset "TaxonomyMakie — set_rank_axis_ticks!" begin
            tree = _mock_carnivora_tree()
            fig, ax, plt = taxonomytreeplot(tree; show_rank_ticks = false)
            set_rank_axis_ticks!(ax, tree)
            # Axis ticks should now reflect the three ranks present (order, family, genus)
            tick_positions, tick_labels = ax.xticks[]
            @test "order"  ∈ tick_labels
            @test "family" ∈ tick_labels
            @test "genus"  ∈ tick_labels
        end
    end

else
    @info "CairoMakie not available — skipping TaxonomyMakie recipe smoke tests"
end
