# test/taxonomy_queries_hierarchy.jl
# Tests for PaleobiologyDB.Taxonomy hierarchy-traversal query functions:
#   child_taxa, parent_taxa, contains_taxon
#
# Depends on mock hierarchy helpers (_inject_mock_hierarchy!, _clear_mock_hierarchy!,
# _mock_augmented_df, _mock_original_df) defined in taxonomy_queries_basic.jl.
# Include taxonomy_queries_basic.jl before this file in runtests.jl.
#
# Live tests (gated on ENV["PBDB_LIVE"]="1") exercise the real snapshot.

# ---------------------------------------------------------------------------
# child_taxa — offline (mock hierarchy)
# ---------------------------------------------------------------------------

@testset "child_taxa — offline mock" begin
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
        # Amphicyon is a genus directly under Carnivora (no family intermediate)
        @test Set(result) == Set(["Canis", "Vulpes", "Felis", "Amphicyon"])
    end

    @testset "species children of order" begin
        result = _ls_children("Carnivora", "species")
        # "Carnivora incertae sedis" is a species directly under Carnivora
        expected = Set(["Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
                        "Carnivora incertae sedis"])
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
            "Amphicyon", "Carnivora incertae sedis",
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
# parent_taxa — offline (mock hierarchy)
# ---------------------------------------------------------------------------

@testset "parent_taxa — offline mock" begin
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

@testset "child_taxa — live snapshot" begin
    if !LIVE
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

@testset "parent_taxa — live snapshot" begin
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

# ---------------------------------------------------------------------------
# contains_taxon — offline
# ---------------------------------------------------------------------------

const _contains = PaleobiologyDB.Taxonomy.contains_taxon

@testset "contains_taxon 2-arg — DataFrame first, pattern second" begin
    df = _mock_augmented_df()

    @testset "Regex — multi-column search" begin
        result = _contains(df, r"Canis")
        @test result isa Vector{Bool}
        @test length(result) == nrow(df)
        @test result[1]  == true  # Row 1: Canis in taxonomy_genus and accepted_name
        @test result[2]  == false # Row 2: Vulpes, not Canis
        @test result[3]  == false # Row 3: Felis, not Canis
    end

    @testset "String — exact match" begin
        result = _contains(df, "Canis")
        @test result[1]  == true  # taxonomy_genus = "Canis"
        @test result[2]  == false # taxonomy_genus = "Vulpes"
    end

    @testset "Vector{String} AND" begin
        result = _contains(df, ["Canis", "Carnivora"])
        @test result[1]  == true  # Has both Canis and Carnivora
        @test result[2]  == false # Has Carnivora but not Canis
    end

    @testset "Vector{String} OR" begin
        result = _contains(df, ["Canis", "Vulpes"]; combine=any)
        @test result[1]  == true  # Has Canis
        @test result[2]  == true  # Has Vulpes
        @test result[3]  == false # Has neither
    end

    @testset "Vector{Regex} AND" begin
        result = _contains(df, [r"Canis", r"idae"])
        @test result[1]  == true  # Has "Canis" in taxonomy_genus and "idae" in taxonomy_family (Canidae)
        @test result[2]  == false # Has "idae" in taxonomy_family but not "Canis"
    end

    @testset "Vector{Regex} OR" begin
        result = _contains(df, [r"^Canis", r"^Vulpes"]; combine=any)
        @test result[1]  == true  # Matches Canis
        @test result[2]  == true  # Matches Vulpes
        @test result[3]  == false # Matches neither
    end

    @testset "autoaugment behavior" begin
        df_orig = _mock_original_df()
        result = _contains(df_orig, "Canis"; autoaugment=false)
        @test result isa Vector{Bool}
        @test result[1] == true
    end
end

@testset "contains_taxon 1-arg — ByRow predicates" begin
    df = _mock_augmented_df()

    @testset "Regex ByRow" begin
        result = subset(df, :taxonomy_genus => _contains(r"anis"))
        @test nrow(result) >= 1
    end

    @testset "String ByRow" begin
        result = subset(df, :taxonomy_genus => _contains("Canis"))
        @test nrow(result) == 1
    end

    @testset "Vector{String} OR ByRow" begin
        result = subset(df, :taxonomy_genus => _contains(["Canis", "Vulpes"]; combine=any))
        @test nrow(result) >= 2
    end

    @testset "Vector{Regex} AND on composite column" begin
        result = subset(df, :taxonomy_clades => _contains([r"Carnivora", r"lupus"]))
        @test nrow(result) >= 1
    end

    @testset "Vector{Regex} OR on composite column" begin
        result = subset(df, :taxonomy_clades => _contains([r"Canidae", r"Felidae"]; combine=any))
        @test nrow(result) >= 2
    end
end

@testset "contains_taxon equivalence with taxon_occursin" begin
    df = _mock_augmented_df()
    @test _taxon_in("Canis", df) == _contains(df, "Canis")
    @test _taxon_in(["Canis", "Vulpes"], df; combine=any) == _contains(df, ["Canis", "Vulpes"]; combine=any)
    @test _taxon_in(r"ana", df) == _contains(df, r"ana")
end
