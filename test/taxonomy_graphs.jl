# test/taxonomy_graphs.jl
# Tests for PaleobiologyDB.Taxonomy graph construction functions:
#   taxon_subtree, root_taxon, leaf_taxa, taxa_at_rank,
#   and the TaxonNode / TaxonomyTree structs.
#
# Offline tests inject the same small mock Carnivora hierarchy used by
# taxonomy_queries.jl (indices accessed via the shared module-level Refs).
# No network access is required.
#
# Mock tree:
#
#   Carnivora (order, #1)
#   ├── Canidae (family, #2)
#   │   ├── Canis (genus, #4)
#   │   │   ├── Canis lupus (species, #7)
#   │   │   └── Canis aureus (species, #8)
#   │   └── Vulpes (genus, #5)
#   │       └── Vulpes vulpes (species, #9)
#   └── Felidae (family, #3)
#       └── Felis (genus, #6)
#           └── Felis catus (species, #10)
#
# Live tests (gated on ENV["PBDB_LIVE"]="1") exercise the real snapshot.

using Test
import Graphs
using PaleobiologyDB
using PaleobiologyDB.Taxonomy: taxon_subtree, root_taxon, leaf_taxa, taxa_at_rank,
    TaxonNode, TaxonomyTree

# ---------------------------------------------------------------------------
# Re-use the same mock injection helpers from taxonomy_queries.jl
# (the Refs are already bound as _NAME_IDX_REF, _NO_IDX_REF, _CHILDREN_IDX_REF
# at module scope in that file — reuse them here)
# ---------------------------------------------------------------------------

@testset "TaxonNode and TaxonomyTree structs" begin
    @testset "TaxonNode constructor" begin
        n = TaxonNode("Canis", "genus", 41045, 41045, 2)
        @test n.name        == "Canis"
        @test n.rank        == "genus"
        @test n.pbdb_id     == 41045
        @test n.accepted_id == 41045
        @test n.parent_id   == 2
        @test n isa TaxonNode
    end

    @testset "TaxonNode missing parent_id (root)" begin
        n = TaxonNode("Carnivora", "order", 1, 1, missing)
        @test ismissing(n.parent_id)
        @test n.accepted_id == 1
    end
end

# ---------------------------------------------------------------------------
# taxon_subtree — offline mock hierarchy
# ---------------------------------------------------------------------------

@testset "taxon_subtree — offline mock" begin
    _inject_mock_hierarchy!()

    @testset "full subtree (no leaf_rank)" begin
        t = taxon_subtree("Carnivora")

        @test t isa TaxonomyTree
        @test Graphs.nv(t.graph) == 12
        @test Graphs.ne(t.graph) == 11
        @test t.root == 1

        r = root_taxon(t)
        @test r.name == "Carnivora"
        @test r.rank == "order"
        @test ismissing(r.parent_id)

        # All 12 taxon names should be present (including rank-skipping nodes)
        all_names = Set(n.name for n in t.taxa)
        @test all_names == Set([
            "Carnivora", "Canidae", "Felidae",
            "Canis", "Vulpes", "Felis",
            "Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
            "Amphicyon", "Carnivora incertae sedis",
        ])

        # vertex_of maps each pbdb_id to a valid vertex
        for n in t.taxa
            n.pbdb_id == 0 && continue   # placeholder node guard
            @test haskey(t.vertex_of, n.pbdb_id)
            v = t.vertex_of[n.pbdb_id]
            @test 1 <= v <= Graphs.nv(t.graph)
            @test t.taxa[v].pbdb_id == n.pbdb_id
        end
    end

    @testset "leaf_rank = family → 3 nodes" begin
        t = taxon_subtree("Carnivora"; leaf_rank = "family")

        @test Graphs.nv(t.graph) == 3
        @test Graphs.ne(t.graph) == 2

        names = Set(n.name for n in t.taxa)
        @test names == Set(["Carnivora", "Canidae", "Felidae"])

        leaves = leaf_taxa(t)
        @test length(leaves) == 2
        @test [n.name for n in leaves] == ["Canidae", "Felidae"]   # sorted
        @test all(n.rank == "family" for n in leaves)
    end

    @testset "leaf_rank = genus → 7 nodes (strict default)" begin
        # Amphicyon (genus, #11) is directly under Carnivora (order) and is at
        # exactly leaf_rank, so it IS collected as a leaf.
        # Carnivora incertae sedis (species) is finer than genus → excluded.
        t = taxon_subtree("Carnivora"; leaf_rank = "genus")

        @test Graphs.nv(t.graph) == 7
        @test Graphs.ne(t.graph) == 6

        names = Set(n.name for n in t.taxa)
        @test names == Set(["Carnivora", "Canidae", "Felidae", "Canis", "Vulpes", "Felis", "Amphicyon"])

        leaves = leaf_taxa(t)
        @test [n.name for n in leaves] == ["Amphicyon", "Canis", "Felis", "Vulpes"]
        @test all(n.rank == "genus" for n in leaves)
    end

    @testset "leaf_rank = species → same as full subtree" begin
        # Carnivora incertae sedis (species, #12) is at exactly leaf_rank,
        # so it IS collected as a leaf.  Amphicyon (genus, #11) is coarser
        # than species so it is treated as an interior node and recurse is
        # attempted; but it has no children in the mock, so it ends up as a
        # leaf in the graph despite having rank "genus".
        # The full tree is 12 nodes / 11 edges.
        t = taxon_subtree("Carnivora"; leaf_rank = "species")

        @test Graphs.nv(t.graph) == 12
        @test Graphs.ne(t.graph) == 11

        leaves = leaf_taxa(t)
        # All 5 species are leaves
        @test Set(n.name for n in leaves if n.rank == "species") ==
              Set(["Canis lupus", "Canis aureus", "Vulpes vulpes",
                   "Felis catus", "Carnivora incertae sedis"])
        # Amphicyon (genus, no children) also appears as a leaf
        @test any(n.name == "Amphicyon" && n.rank == "genus" for n in leaves)
    end

    @testset "rooted at a non-root node" begin
        t = taxon_subtree("Canidae"; leaf_rank = "genus")

        @test Graphs.nv(t.graph) == 3
        @test Graphs.ne(t.graph) == 2

        r = root_taxon(t)
        @test r.name == "Canidae"
        @test r.rank == "family"

        leaves = leaf_taxa(t)
        @test [n.name for n in leaves] == ["Canis", "Vulpes"]
    end

    @testset "unknown taxon → single-node placeholder tree" begin
        t = taxon_subtree("INVALID_TAXON_XYZ")

        @test t isa TaxonomyTree
        @test Graphs.nv(t.graph) == 1
        @test Graphs.ne(t.graph) == 0
        @test length(t.taxa) == 1
        @test t.taxa[1].name == "INVALID_TAXON_XYZ"
    end

    @testset "bad leaf_rank → ArgumentError" begin
        @test_throws ArgumentError taxon_subtree("Carnivora"; leaf_rank = "NOTARANK")
    end

    @testset "strict_leaf_rank=true (default): orphaned genus/species excluded" begin
        # Amphicyon (genus, #11) and Carnivora incertae sedis (species, #12)
        # are direct children of Carnivora (order) — finer than family → excluded
        t = taxon_subtree("Carnivora"; leaf_rank = "family")
        names = Set(n.name for n in t.taxa)
        @test "Amphicyon" ∉ names
        @test "Carnivora incertae sedis" ∉ names
        # Tree has exactly 3 nodes: Carnivora + Canidae + Felidae
        @test Graphs.nv(t.graph) == 3
        @test Graphs.ne(t.graph) == 2
    end

    @testset "strict_leaf_rank=false: orphaned genus/species included as leaves" begin
        t = taxon_subtree("Carnivora"; leaf_rank = "family", strict_leaf_rank = false)
        names = Set(n.name for n in t.taxa)
        @test "Amphicyon" ∈ names
        @test "Carnivora incertae sedis" ∈ names
        # 5 nodes: Carnivora + Canidae + Felidae + Amphicyon + incertae sedis
        @test Graphs.nv(t.graph) == 5
        # Amphicyon and incertae sedis are leaves (no children collected under them)
        amphicyon_v = t.vertex_of[11]
        @test isempty(Graphs.outneighbors(t.graph, amphicyon_v))
    end

    @testset "strict_leaf_rank=true: leaf_taxa are exclusively at leaf_rank" begin
        t = taxon_subtree("Carnivora"; leaf_rank = "family")
        leaves = leaf_taxa(t)
        @test all(n.rank == "family" for n in leaves)
        @test [n.name for n in leaves] == ["Canidae", "Felidae"]
    end

    @testset "strict_leaf_rank=false: leaf_taxa may include finer ranks" begin
        t = taxon_subtree("Carnivora"; leaf_rank = "family", strict_leaf_rank = false)
        leaves = leaf_taxa(t)
        leaf_ranks = Set(n.rank for n in leaves)
        # Amphicyon (genus) and incertae sedis (species) are leaves
        @test "genus" ∈ leaf_ranks
        @test "species" ∈ leaf_ranks
    end

    _clear_mock_hierarchy!()
end

# ---------------------------------------------------------------------------
# root_taxon
# ---------------------------------------------------------------------------

@testset "root_taxon — offline mock" begin
    _inject_mock_hierarchy!()

    t = taxon_subtree("Carnivora")
    r = root_taxon(t)

    @test r isa TaxonNode
    @test r.name        == "Carnivora"
    @test r.rank        == "order"
    @test r.pbdb_id     == 1
    @test r.accepted_id == 1   # Carnivora is accepted: accepted_no == orig_no
    @test ismissing(r.parent_id)

    _clear_mock_hierarchy!()
end

# ---------------------------------------------------------------------------
# leaf_taxa
# ---------------------------------------------------------------------------

@testset "leaf_taxa — offline mock" begin
    _inject_mock_hierarchy!()

    @testset "full subtree leaves — no leaf_rank" begin
        # Without a leaf_rank filter, leaves are all nodes with no children.
        # Amphicyon (#11) has no children → genus leaf.
        # Carnivora incertae sedis (#12) has no children → species leaf.
        t = taxon_subtree("Carnivora")
        leaves = leaf_taxa(t)
        @test leaves isa Vector{TaxonNode}
        @test length(leaves) == 6
        @test Set(n.name for n in leaves) == Set([
            "Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
            "Amphicyon", "Carnivora incertae sedis",
        ])
    end

    @testset "leaf_rank=family → families are leaves, sorted" begin
        t = taxon_subtree("Carnivora"; leaf_rank = "family")
        leaves = leaf_taxa(t)
        @test [n.name for n in leaves] == ["Canidae", "Felidae"]
    end

    @testset "single-node tree → root is its own leaf" begin
        t = taxon_subtree("Felis catus")   # species — no children
        leaves = leaf_taxa(t)
        @test length(leaves) == 1
        @test leaves[1].name == "Felis catus"
    end

    _clear_mock_hierarchy!()
end

# ---------------------------------------------------------------------------
# taxa_at_rank
# ---------------------------------------------------------------------------

@testset "taxa_at_rank — offline mock" begin
    _inject_mock_hierarchy!()

    t = taxon_subtree("Carnivora")

    @testset "genera in full Carnivora subtree" begin
        genera = taxa_at_rank(t, "genus")
        @test genera isa Vector{TaxonNode}
        @test [n.name for n in genera] == ["Amphicyon", "Canis", "Felis", "Vulpes"]
        @test all(n.rank == "genus" for n in genera)
    end

    @testset "families in full Carnivora subtree" begin
        families = taxa_at_rank(t, "family")
        @test [n.name for n in families] == ["Canidae", "Felidae"]
    end

    @testset "order in full Carnivora subtree" begin
        orders = taxa_at_rank(t, "order")
        @test length(orders) == 1
        @test orders[1].name == "Carnivora"
    end

    @testset "absent rank → empty vector" begin
        @test taxa_at_rank(t, "phylum") == TaxonNode[]
    end

    @testset "bad rank → ArgumentError" begin
        @test_throws ArgumentError taxa_at_rank(t, "NOTARANK")
    end

    _clear_mock_hierarchy!()
end

# ---------------------------------------------------------------------------
# Graphs.jl interoperability
# ---------------------------------------------------------------------------

@testset "Graphs.jl interop — offline mock" begin
    _inject_mock_hierarchy!()

    t = taxon_subtree("Carnivora")
    g = t.graph

    @test g isa Graphs.SimpleDiGraph{Int}
    @test Graphs.nv(g) == 12
    @test Graphs.ne(g) == 11
    @test Graphs.is_directed(g)

    # Root (vertex 1) should have outgoing edges (children) and no incoming edges
    @test length(Graphs.outneighbors(g, t.root)) == 4   # Canidae + Felidae + Amphicyon + incertae sedis
    @test isempty(Graphs.inneighbors(g, t.root))

    # Leaf vertices should have no outgoing edges; leaves are species or Amphicyon (genus)
    leaf_names = Set(t.taxa[v].name for v in Graphs.vertices(g) if isempty(Graphs.outneighbors(g, v)))
    @test leaf_names == Set([
        "Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
        "Amphicyon", "Carnivora incertae sedis",
    ])

    _clear_mock_hierarchy!()
end

# ---------------------------------------------------------------------------
# Live tests — real PBDB snapshot (gated on PBDB_LIVE)
# ---------------------------------------------------------------------------

@testset "taxon_subtree — live (requires PBDB_LIVE=1)" begin
    if !LIVE
        @info "Live taxonomy graph tests disabled. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    @testset "Carnivora full subtree is large" begin
        t = taxon_subtree("Carnivora")
        @test Graphs.nv(t.graph) > 100
        @test root_taxon(t).name == "Carnivora"
        @test root_taxon(t).rank == "order"
    end

    @testset "Carnivora leaf_rank=family" begin
        # strict_leaf_rank=true (default) guarantees all leaves are exactly
        # at "family" rank; orphaned genera/species are excluded.
        t = taxon_subtree("Carnivora"; leaf_rank = "family")
        leaves = leaf_taxa(t)
        @test all(n.rank == "family" for n in leaves)
        @test any(n.name == "Canidae" for n in leaves)
        @test any(n.name == "Felidae" for n in leaves)
    end

    @testset "Canidae genus-level subtree" begin
        t = taxon_subtree("Canidae"; leaf_rank = "genus")
        leaves = leaf_taxa(t)
        @test all(n.rank == "genus" for n in leaves)
        @test any(n.name == "Canis" for n in leaves)
    end
end
