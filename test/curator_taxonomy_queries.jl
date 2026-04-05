# test/curator_taxonomy_queries.jl
# Tests for PaleobiologyDB.DataCurator taxonomy tree-query functions:
#   ls_child_taxa, ls_parent_taxa
#
# Offline tests inject a small mock hierarchy directly into the module-level
# Refs so no network access is required.
#
# The mock tree (Carnivora subtree):
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
using DataFrames
using PaleobiologyDB

const _ls_children = PaleobiologyDB.DataCurator.ls_child_taxa
const _ls_parents  = PaleobiologyDB.DataCurator.ls_parent_taxa

# ---------------------------------------------------------------------------
# Helpers: inject and clear mock hierarchy indices
# ---------------------------------------------------------------------------

const _NAME_IDX_REF     = PaleobiologyDB.DataCurator._TAXA_HIERARCHY_NAME_INDEX
const _NO_IDX_REF       = PaleobiologyDB.DataCurator._TAXA_HIERARCHY_NO_INDEX
const _CHILDREN_IDX_REF = PaleobiologyDB.DataCurator._TAXA_CHILDREN_INDEX
const _TaxonInfo        = PaleobiologyDB.DataCurator._TaxonInfo

function _inject_mock_hierarchy!()
    name_to_no = Dict{String, Int}(
        "Carnivora"   => 1,
        "Canidae"     => 2,
        "Felidae"     => 3,
        "Canis"       => 4,
        "Vulpes"      => 5,
        "Felis"       => 6,
        "Canis lupus" => 7,
        "Canis aureus"=> 8,
        "Vulpes vulpes"=>9,
        "Felis catus" => 10,
    )

    no_to_info = Dict{Int, _TaxonInfo}(
        1  => (name = "Carnivora",    rank = "order",   parent_no = missing),
        2  => (name = "Canidae",      rank = "family",  parent_no = 1),
        3  => (name = "Felidae",      rank = "family",  parent_no = 1),
        4  => (name = "Canis",        rank = "genus",   parent_no = 2),
        5  => (name = "Vulpes",       rank = "genus",   parent_no = 2),
        6  => (name = "Felis",        rank = "genus",   parent_no = 3),
        7  => (name = "Canis lupus",  rank = "species", parent_no = 4),
        8  => (name = "Canis aureus", rank = "species", parent_no = 4),
        9  => (name = "Vulpes vulpes",rank = "species", parent_no = 5),
        10 => (name = "Felis catus",  rank = "species", parent_no = 6),
    )

    children = Dict{Int, Vector{Int}}(
        1 => [2, 3],
        2 => [4, 5],
        3 => [6],
        4 => [7, 8],
        5 => [9],
        6 => [10],
    )

    _NAME_IDX_REF[]     = name_to_no
    _NO_IDX_REF[]       = no_to_info
    _CHILDREN_IDX_REF[] = children
end

function _clear_mock_hierarchy!()
    _NAME_IDX_REF[]     = nothing
    _NO_IDX_REF[]       = nothing
    _CHILDREN_IDX_REF[] = nothing
end

# ---------------------------------------------------------------------------
# ls_child_taxa — offline (mock hierarchy)
# ---------------------------------------------------------------------------

@testset "ls_child_taxa — offline mock" begin
    _inject_mock_hierarchy!()

    # Direct children at the requested rank
    @testset "family children of order" begin
        result = _ls_children("Carnivora", "family")
        @test result isa Vector{String}
        @test Set(result) == Set(["Canidae", "Felidae"])
    end

    @testset "genus children of family" begin
        result = _ls_children("Canidae", "genus")
        @test Set(result) == Set(["Canis", "Vulpes"])
    end

    @testset "genus children spanning two families" begin
        result = _ls_children("Carnivora", "genus")
        @test Set(result) == Set(["Canis", "Vulpes", "Felis"])
    end

    @testset "species children of order" begin
        result = _ls_children("Carnivora", "species")
        expected = Set(["Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus"])
        @test Set(result) == expected
    end

    @testset "species children of genus" begin
        result = _ls_children("Canis", "species")
        @test Set(result) == Set(["Canis lupus", "Canis aureus"])
    end

    @testset "leaf node has no children at finer rank" begin
        @test _ls_children("Canis lupus", "species") == String[]
        @test _ls_children("Canis lupus", "genus")   == String[]
    end

    @testset "rank coarser than all children → empty" begin
        # Carnivora is order; requesting order-level descendants of Carnivora
        # yields nothing (its children are families, which are finer than order)
        @test _ls_children("Carnivora", "order") == String[]
    end

    @testset "no rank filter — all descendants" begin
        result = _ls_children("Carnivora", nothing)
        @test Set(result) == Set([
            "Canidae", "Felidae",
            "Canis", "Vulpes", "Felis",
            "Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
        ])
    end

    @testset "no rank filter — subtree" begin
        result = _ls_children("Canidae")  # default nothing
        @test Set(result) == Set(["Canis", "Vulpes", "Canis lupus", "Canis aureus", "Vulpes vulpes"])
    end

    @testset "result is sorted" begin
        result = _ls_children("Carnivora", "family")
        @test result == sort(result)
    end

    @testset "unknown taxon name → empty" begin
        @test _ls_children("INVALID_NAME", "genus") == String[]
        @test _ls_children("", "family")            == String[]
    end

    @testset "unknown rank → ArgumentError" begin
        @test_throws ArgumentError _ls_children("Carnivora", "BOGUS_RANK")
    end

    _clear_mock_hierarchy!()
end

# ---------------------------------------------------------------------------
# ls_parent_taxa — offline (mock hierarchy)
# ---------------------------------------------------------------------------

@testset "ls_parent_taxa — offline mock" begin
    _inject_mock_hierarchy!()

    @testset "all ancestors — species" begin
        result = _ls_parents("Canis lupus", nothing)
        # child → root order
        @test result == ["Canis", "Canidae", "Carnivora"]
    end

    @testset "all ancestors — genus" begin
        result = _ls_parents("Canis", nothing)
        @test result == ["Canidae", "Carnivora"]
    end

    @testset "all ancestors — default nothing" begin
        result = _ls_parents("Vulpes vulpes")  # default nothing
        @test result == ["Vulpes", "Canidae", "Carnivora"]
    end

    @testset "filtered by rank — family" begin
        @test _ls_parents("Canis", "family") == ["Canidae"]
        @test _ls_parents("Canis lupus", "family") == ["Canidae"]
    end

    @testset "filtered by rank — order" begin
        @test _ls_parents("Canis", "order") == ["Carnivora"]
        @test _ls_parents("Felis catus", "order") == ["Carnivora"]
    end

    @testset "rank not present in ancestor chain → empty" begin
        # Mock tree has no class; asking for class ancestors gives nothing
        @test _ls_parents("Canis", "class") == String[]
    end

    @testset "root node has no parents" begin
        @test _ls_parents("Carnivora", nothing) == String[]
        @test _ls_parents("Carnivora", "order") == String[]
    end

    @testset "unknown taxon name → empty" begin
        @test _ls_parents("INVALID_NAME", "family") == String[]
        @test _ls_parents("", nothing)               == String[]
    end

    @testset "unknown rank → ArgumentError" begin
        @test_throws ArgumentError _ls_parents("Canis", "BOGUS_RANK")
    end

    _clear_mock_hierarchy!()
end

# ---------------------------------------------------------------------------
# Live tests — require ENV["PBDB_LIVE"]="1"  (LIVE constant from runtests.jl)
# ---------------------------------------------------------------------------

@testset "ls_child_taxa — live snapshot" begin
    if !LIVE
        @info "Live taxonomy-query tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    families = _ls_children("Carnivora", "family")
    @test families isa Vector{String}
    @test "Canidae" in families
    @test "Felidae" in families

    genera = _ls_children("Canidae", "genus")
    @test "Canis" in genera
    @test "Vulpes" in genera

    # Leaf node at requested rank returns empty
    @test _ls_children("INVALID_TAXON_NAME_XYZ", "genus") == String[]
end

@testset "ls_parent_taxa — live snapshot" begin
    if !LIVE
        return
    end

    parents = _ls_parents("Canis", nothing)
    @test parents isa Vector{String}
    @test "Canidae" in parents
    @test "Carnivora" in parents

    family = _ls_parents("Canis", "family")
    @test family == ["Canidae"]

    @test _ls_parents("INVALID_TAXON_NAME_XYZ", "family") == String[]
end
