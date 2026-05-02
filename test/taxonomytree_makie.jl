# test/taxonomytree_makie.jl
# Tests for PaleobiologyDB.TaxonomyTreeMakie extension.
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

# ---------------------------------------------------------------------------
# Trigger extension
# ---------------------------------------------------------------------------

const _CAIRO_TTM_AVAILABLE = !isnothing(Base.find_package("CairoMakie"))

if _CAIRO_TTM_AVAILABLE
    @eval using CairoMakie
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
    const _plan_leaf_tip_overlay = PaleobiologyDB.TaxonomyMakie._plan_leaf_tip_phylopic_overlay
    const _plan_leaf_label_overlay = PaleobiologyDB.TaxonomyMakie._plan_leaf_label_phylopic_overlay
    const _augment_leaf_overlay = PaleobiologyDB.TaxonomyMakie._augment_leaf_phylopic!
    const _LeafOverlayPlan = PaleobiologyDB.TaxonomyMakie._LeafOverlayPlan
    const _TEST_GLYPH = fill(Makie.RGBA{Makie.N0f8}(0, 0, 0, 1), 16, 32)

    _materialize_tree_overlay!(fig) = CairoMakie.Makie.update_state_before_display!(fig)

    function _leaf_text_plots!(ax, tree, xs, ys; tip_xoffset = 0.1, tip_yoffset = 0.0)
        leaves = _leaf_positions_fn(tree, xs, ys)
        text_plots = Any[]
        sizehint!(text_plots, length(leaves.vertices))
        for i in eachindex(leaves.vertices)
            push!(
                text_plots,
                Makie.text!(
                    ax,
                    Makie.Point2f(
                        leaves.x[i] + Float64(tip_xoffset),
                        leaves.y[i] + Float64(tip_yoffset),
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

    @testset "TaxonomyTreeMakie — _rank_depth" begin

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

    @testset "TaxonomyTreeMakie — _compute_dendrogram_layout" begin
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

    @testset "TaxonomyTreeMakie — _compute_dendrogram_layout ladderize" begin
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

    @testset "TaxonomyTreeMakie — _compute_dendrogram_layout single-node tree" begin
        tree = _mock_single_node_tree()
        xs, ys = _layout(tree)

        @test length(xs) == 1
        @test length(ys) == 1
        @test xs[1] == 0.0    # unknown rank → falls back to 0.0 (root)
        @test ys[1] == 1.0    # single leaf → y = 1
    end

    @testset "TaxonomyTreeMakie — _dendrogram_segment_pairs" begin
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

    @testset "TaxonomyTreeMakie — leaf overlay planning" begin
        tree = _mock_carnivora_tree()
        xs, ys = _layout(tree)

        leaves = _leaf_positions_fn(tree, xs, ys)
        @test leaves == tip_positions(tree, xs, ys)

        plan = _plan_leaf_tip_overlay(
            tree,
            xs,
            ys;
            anchor = :tip_label_origin,
            tip_xoffset = 0.25,
            align = true,
        )
        @test plan.leaf_names == leaves.names
        @test length(plan.anchor_positions) == length(leaves.vertices)
        @test all(pos -> pos[1] ≈ maximum(leaves.x .+ 0.25), plan.anchor_positions)
        @test [pos[2] for pos in plan.anchor_positions] ≈ leaves.y
    end

    @testset "TaxonomyTreeMakie — shared label-aware overlay reacts to relimit and resize" begin
        tree = _mock_carnivora_tree()
        xs, ys = _layout(tree)

        fig = Figure(size = (600, 400))
        ax = Axis(fig[1, 1])
        xlims!(ax, 0, 20)
        ylims!(ax, 0, 8)

        leaves, leaf_text_plots = _leaf_text_plots!(ax, tree, xs, ys; tip_xoffset = 0.1)
        plan = _plan_leaf_label_overlay(
            ax,
            tree,
            xs,
            ys;
            leaf_text_plots = leaf_text_plots,
            tip_xoffset = 0.1,
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

    @testset "TaxonomyTreeMakie — tree overlay missing-image policy uses shared adapter" begin
        fig = Figure()
        ax = Axis(fig[1, 1])
        plan = _LeafOverlayPlan(
            [1],
            [""],
            [Makie.Point2f(1.0f0, 1.0f0)],
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
    @info "CairoMakie not available — skipping TaxonomyTreeMakie offline layout tests"
end

# ---------------------------------------------------------------------------
# 2. Recipe smoke tests
# ---------------------------------------------------------------------------

if _CAIRO_TTM_AVAILABLE
    if LIVE
        @testset "TaxonomyTreeMakie — taxonomytreeplot smoke" begin
            tree = _mock_carnivora_tree()

            @testset "taxonomytreeplot returns FigureAxisPlot" begin
                result = taxonomytreeplot(tree)
                @test result isa Makie.FigureAxisPlot
                fig, ax, plt = result
                @test fig isa CairoMakie.Figure
                @test ax  isa CairoMakie.Axis
                @test plt isa TaxonomyTreePlot
            end

            @testset "showtips = false does not error" begin
                @test_nowarn taxonomytreeplot(tree; showtips = false)
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

        @testset "TaxonomyTreeMakie — taxonomytreeplot! into existing axis" begin
            tree = _mock_carnivora_tree()
            fig  = CairoMakie.Figure()
            ax   = CairoMakie.Axis(fig[1, 1])

            p = taxonomytreeplot!(ax, tree; showtips = true, ladderize = true)
            @test p isa TaxonomyTreePlot

            # set_rank_axis_ticks! must run without error
            @test_nowarn set_rank_axis_ticks!(ax, tree)
        end

        @testset "TaxonomyTreeMakie — single-node tree (placeholder)" begin
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

    @testset "TaxonomyTreeMakie — PhyloPic silhouette attributes (offline)" begin
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

    @testset "TaxonomyTreeMakie — PhyloPic silhouettes (live)" begin
        if !LIVE
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

    if LIVE
        @testset "TaxonomyTreeMakie — set_rank_axis_ticks!" begin
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
    @info "CairoMakie not available — skipping TaxonomyTreeMakie recipe smoke tests"
end
