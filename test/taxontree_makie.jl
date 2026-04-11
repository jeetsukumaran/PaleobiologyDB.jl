# test/taxontree_makie.jl
# Tests for PaleobiologyDB.TaxonTreeMakie extension.
#
# Structure:
#   1. Mock tree construction (shared fixture)
#   2. Offline / pure-function tests — layout logic (extension must be loaded
#      to access internals, but no rendering is performed)
#   3. Recipe smoke tests — exercise taxontreeplot and taxontreeplot!
#      (gated on CairoMakie availability)
#
# CairoMakie is in test/Project.toml and is available in the standard test
# suite.  The _EXT_AVAILABLE guard provides a graceful skip path in
# environments where it is absent.

using Test
using PaleobiologyDB
using PaleobiologyDB.Taxonomy: TaxonTree, TaxonNode
import Graphs

# ---------------------------------------------------------------------------
# Trigger extension
# ---------------------------------------------------------------------------

const _CAIRO_TTM_AVAILABLE = !isnothing(Base.find_package("CairoMakie"))

if _CAIRO_TTM_AVAILABLE
    @eval using CairoMakie
    @eval using PaleobiologyDB.TaxonTreeMakie
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
    TaxonTree(g, taxa, vertex_of, 1)
end

# Single-node placeholder tree (mimics taxon_subtree("INVALID"))
function _mock_single_node_tree()
    g = Graphs.SimpleDiGraph(1)
    taxa = [TaxonNode("INVALID", "", 0, missing, missing)]
    TaxonTree(g, taxa, Dict(0 => 1), 1)
end

# ---------------------------------------------------------------------------
# 1. Offline / pure-function tests
# ---------------------------------------------------------------------------

if _CAIRO_TTM_AVAILABLE
    # Access internals through the extension module
    const _rd_fn   = PaleobiologyDB.TaxonTreeMakie._rank_depth
    const _layout  = PaleobiologyDB.TaxonTreeMakie._compute_dendrogram_layout
    const _segpairs = PaleobiologyDB.TaxonTreeMakie._dendrogram_segment_pairs

    @testset "TaxonTreeMakie — _rank_depth" begin

        @testset "known ranks" begin
            @test _rd_fn("kingdom")    == 0
            @test _rd_fn("phylum")     == 1
            @test _rd_fn("order")      == 8
            @test _rd_fn("family")     == 12
            @test _rd_fn("genus")      == 16
            @test _rd_fn("species")    == 17
            @test _rd_fn("subspecies") == 18
        end

        @testset "unknown / empty ranks return -1" begin
            @test _rd_fn("")              == -1
            @test _rd_fn("unranked")      == -1
            @test _rd_fn("unranked clade") == -1
            @test _rd_fn("GENUS")         == -1   # case-sensitive
        end
    end

    @testset "TaxonTreeMakie — _compute_dendrogram_layout" begin
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

    @testset "TaxonTreeMakie — _compute_dendrogram_layout ladderize" begin
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

    @testset "TaxonTreeMakie — _compute_dendrogram_layout single-node tree" begin
        tree = _mock_single_node_tree()
        xs, ys = _layout(tree)

        @test length(xs) == 1
        @test length(ys) == 1
        @test xs[1] == 0.0    # unknown rank → falls back to 0.0 (root)
        @test ys[1] == 1.0    # single leaf → y = 1
    end

    @testset "TaxonTreeMakie — _dendrogram_segment_pairs" begin
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

else
    @info "CairoMakie not available — skipping TaxonTreeMakie offline layout tests"
end

# ---------------------------------------------------------------------------
# 2. Recipe smoke tests
# ---------------------------------------------------------------------------

if _CAIRO_TTM_AVAILABLE
    @testset "TaxonTreeMakie — taxontreeplot smoke" begin
        tree = _mock_carnivora_tree()

        @testset "taxontreeplot returns (Figure, Axis, TaxonTreePlot)" begin
            fig, ax, p = taxontreeplot(tree)
            @test fig isa CairoMakie.Figure
            @test ax  isa CairoMakie.Axis
            @test p   isa TaxonTreePlot
        end

        @testset "showtips = false does not error" begin
            @test_nowarn taxontreeplot(tree; showtips = false)
        end

        @testset "color_by_rank = true does not error" begin
            @test_nowarn taxontreeplot(tree; color_by_rank = true)
        end

        @testset "ladderize = true does not error" begin
            @test_nowarn taxontreeplot(tree; ladderize = true)
        end

        @testset "showinternal = true does not error" begin
            @test_nowarn taxontreeplot(tree; showinternal = true)
        end

        @testset "show_rank_ticks = false skips axis tick setup" begin
            @test_nowarn taxontreeplot(tree; show_rank_ticks = false)
        end

        @testset "color_by_rank with rank_palette does not error" begin
            palette = Dict("order" => :red, "family" => :blue, "genus" => :green)
            @test_nowarn taxontreeplot(tree; color_by_rank = true, rank_palette = palette)
        end
    end

    @testset "TaxonTreeMakie — taxontreeplot! into existing axis" begin
        tree = _mock_carnivora_tree()
        fig  = CairoMakie.Figure()
        ax   = CairoMakie.Axis(fig[1, 1])

        p = taxontreeplot!(ax, tree; showtips = true, ladderize = true)
        @test p isa TaxonTreePlot

        # set_rank_axis_ticks! must run without error
        @test_nowarn set_rank_axis_ticks!(ax, tree)
    end

    @testset "TaxonTreeMakie — single-node tree (placeholder)" begin
        tree = _mock_single_node_tree()
        @test_nowarn taxontreeplot(tree)
    end

    @testset "TaxonTreeMakie — set_rank_axis_ticks!" begin
        tree = _mock_carnivora_tree()
        fig, ax, _p = taxontreeplot(tree; show_rank_ticks = false)
        set_rank_axis_ticks!(ax, tree)
        # Axis ticks should now reflect the three ranks present (order, family, genus)
        tick_positions, tick_labels = ax.xticks[]
        @test "order"  ∈ tick_labels
        @test "family" ∈ tick_labels
        @test "genus"  ∈ tick_labels
    end

else
    @info "CairoMakie not available — skipping TaxonTreeMakie recipe smoke tests"
end
