# test/taxonomy_graphs.jl
# Tests for PaleobiologyDB.Taxonomy graph construction functions:
#   taxon_subtree, root_taxon, leaf_taxa, taxa_at_rank,
#   and the TaxonNode / TaxonTree structs.
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
    TaxonNode, TaxonTree

# ---------------------------------------------------------------------------
# Re-use the same mock injection helpers from taxonomy_queries.jl
# (the Refs are already bound as _NAME_IDX_REF, _NO_IDX_REF, _CHILDREN_IDX_REF
# at module scope in that file — reuse them here)
# ---------------------------------------------------------------------------

@testset "TaxonNode and TaxonTree structs" begin
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

        @test t isa TaxonTree
        @test Graphs.nv(t.graph) == 10
        @test Graphs.ne(t.graph) == 9
        @test t.root == 1

        r = root_taxon(t)
        @test r.name == "Carnivora"
        @test r.rank == "order"
        @test ismissing(r.parent_id)

        # All 10 taxon names should be present
        all_names = Set(n.name for n in t.taxa)
        @test all_names == Set([
            "Carnivora", "Canidae", "Felidae",
            "Canis", "Vulpes", "Felis",
            "Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
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

    @testset "leaf_rank = genus → 6 nodes" begin
        t = taxon_subtree("Carnivora"; leaf_rank = "genus")

        @test Graphs.nv(t.graph) == 6
        @test Graphs.ne(t.graph) == 5

        names = Set(n.name for n in t.taxa)
        @test names == Set(["Carnivora", "Canidae", "Felidae", "Canis", "Vulpes", "Felis"])

        leaves = leaf_taxa(t)
        @test [n.name for n in leaves] == ["Canis", "Felis", "Vulpes"]
        @test all(n.rank == "genus" for n in leaves)
    end

    @testset "leaf_rank = species → same as full subtree" begin
        t = taxon_subtree("Carnivora"; leaf_rank = "species")

        @test Graphs.nv(t.graph) == 10
        @test Graphs.ne(t.graph) == 9

        leaves = leaf_taxa(t)
        @test all(n.rank == "species" for n in leaves)
        @test Set(n.name for n in leaves) == Set([
            "Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
        ])
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

        @test t isa TaxonTree
        @test Graphs.nv(t.graph) == 1
        @test Graphs.ne(t.graph) == 0
        @test length(t.taxa) == 1
        @test t.taxa[1].name == "INVALID_TAXON_XYZ"
    end

    @testset "bad leaf_rank → ArgumentError" begin
        @test_throws ArgumentError taxon_subtree("Carnivora"; leaf_rank = "NOTARANK")
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

    @testset "full subtree leaves are species" begin
        t = taxon_subtree("Carnivora")
        leaves = leaf_taxa(t)
        @test leaves isa Vector{TaxonNode}
        @test length(leaves) == 4
        @test [n.name for n in leaves] == sort([
            "Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
        ])
        @test all(n.rank == "species" for n in leaves)
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
        @test [n.name for n in genera] == ["Canis", "Felis", "Vulpes"]
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
    @test Graphs.nv(g) == 10
    @test Graphs.ne(g) == 9
    @test Graphs.is_directed(g)

    # Root (vertex 1) should have outgoing edges (children) and no incoming edges
    @test length(Graphs.outneighbors(g, t.root)) == 2   # Canidae + Felidae
    @test isempty(Graphs.inneighbors(g, t.root))

    # Leaf vertices should have no outgoing edges
    for v in Graphs.vertices(g)
        if isempty(Graphs.outneighbors(g, v))
            @test t.taxa[v].rank == "species"
        end
    end

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
