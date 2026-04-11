# test/taxonomy_resolution.jl
# Tests for PaleobiologyDB.Taxonomy.drop_unresolved_taxa

using Test
using DataFrames
using PaleobiologyDB

const _filter_res  = PaleobiologyDB.Taxonomy.drop_unresolved_taxa
const _filter_res! = PaleobiologyDB.Taxonomy.drop_unresolved_taxa!
const _rank_index  = PaleobiologyDB.Taxonomy._pbdb_rank_index
const _ranks_finer = PaleobiologyDB.Taxonomy._pbdb_ranks_at_or_finer_than
const RANK_HIERARCHY = PaleobiologyDB.Taxonomy.PBDB_RANK_HIERARCHY

# ---------------------------------------------------------------------------
# Local test-data helper
# ---------------------------------------------------------------------------

function _make_df(accepted_ranks; rank_col = nothing, rank_col_vals = nothing)
    n = length(accepted_ranks)
    df = DataFrame(
        occurrence_no = 1:n,
        accepted_rank = Vector{Union{Missing,String}}(accepted_ranks),
    )
    if !isnothing(rank_col) && !isnothing(rank_col_vals)
        df[!, rank_col] = Vector{Union{Missing,String}}(rank_col_vals)
    end
    df
end

# ---------------------------------------------------------------------------

@testset "Taxonomy.drop_unresolved_taxa" begin

    # -----------------------------------------------------------------------
    @testset "internal helpers" begin

        @testset "_pbdb_rank_index" begin
            @test _rank_index("subspecies") == 1
            @test _rank_index("species")    == 2
            @test _rank_index("subgenus")   == 3
            @test _rank_index("genus")      == 4
            @test _rank_index("kingdom")    == length(RANK_HIERARCHY)
            @test_throws ArgumentError _rank_index("bogus")
            @test_throws ArgumentError _rank_index("Domain")
        end

        @testset "_pbdb_ranks_at_or_finer_than" begin
            @test _ranks_finer("subspecies") == ["subspecies"]
            @test _ranks_finer("species")    == ["subspecies", "species"]
            @test _ranks_finer("subgenus")   == ["subspecies", "species", "subgenus"]
            @test _ranks_finer("genus")      == ["subspecies", "species", "subgenus", "genus"]
            # "family" is index 8 in the hierarchy (after subgenus was inserted)
            @test _ranks_finer("family") == RANK_HIERARCHY[1:8]
            # "kingdom" returns the full hierarchy
            @test _ranks_finer("kingdom") == RANK_HIERARCHY
            @test length(_ranks_finer("kingdom")) == 20
        end

        @testset "PBDB_RANK_HIERARCHY includes subgenus between species and genus" begin
            genus_idx    = findfirst(==("genus"),    RANK_HIERARCHY)
            subgenus_idx = findfirst(==("subgenus"), RANK_HIERARCHY)
            species_idx  = findfirst(==("species"),  RANK_HIERARCHY)
            @test !isnothing(subgenus_idx)
            @test subgenus_idx > species_idx   # subgenus is coarser than species
            @test subgenus_idx < genus_idx     # subgenus is finer than genus
        end

    end

    # -----------------------------------------------------------------------
    @testset "rank filtering — accepted_rank criterion" begin

        all_ranks_df = _make_df(RANK_HIERARCHY)  # one row per rank

        @testset "filter \"genus\"" begin
            result = _filter_res(all_ranks_df, "genus")
            @test result isa DataFrame
            @test nrow(result) == 4   # subspecies, species, subgenus, genus
            @test Set(result.accepted_rank) == Set(["subspecies", "species", "subgenus", "genus"])
        end

        @testset "filter \"species\"" begin
            result = _filter_res(all_ranks_df, "species")
            @test nrow(result) == 2
            @test Set(result.accepted_rank) == Set(["subspecies", "species"])
        end

        @testset "filter \"subspecies\" (most restrictive)" begin
            result = _filter_res(all_ranks_df, "subspecies")
            @test nrow(result) == 1
            @test result.accepted_rank[1] == "subspecies"
        end

        @testset "filter \"family\"" begin
            result = _filter_res(all_ranks_df, "family")
            @test nrow(result) == 8   # up to and including family (subgenus added)
            @test "family"    in result.accepted_rank
            @test "subgenus"  in result.accepted_rank
            @test "genus"     in result.accepted_rank
            @test !("superfamily" in result.accepted_rank)
            @test !("order"       in result.accepted_rank)
        end

        @testset "filter \"kingdom\" (most permissive)" begin
            result = _filter_res(all_ranks_df, "kingdom")
            @test nrow(result) == nrow(all_ranks_df)   # every rank passes
        end

        @testset "coarser-than-target ranks are dropped" begin
            df = _make_df(["genus", "order", "phylum", "species"])
            result = _filter_res(df, "genus")
            @test nrow(result) == 2
            @test Set(result.accepted_rank) == Set(["genus", "species"])
        end

    end

    # -----------------------------------------------------------------------
    @testset "missing accepted_rank is dropped" begin

        df = _make_df([missing, "genus", missing, "species", "order"])
        result = _filter_res(df, "genus")
        # missing rows dropped; "order" is coarser → also dropped
        @test nrow(result) == 2
        @test !any(ismissing, result.accepted_rank)
        @test Set(result.accepted_rank) == Set(["genus", "species"])

        # All missing → empty result
        df_all_missing = _make_df([missing, missing])
        @test nrow(_filter_res(df_all_missing, "genus")) == 0

    end

    # -----------------------------------------------------------------------
    @testset "named rank column criterion" begin

        @testset "genus column present" begin
            df = _make_df(
                ["genus",   "genus",  "genus",  "species", "species"],
                rank_col = :genus,
                rank_col_vals = ["Canis", "",      missing,  "Canis",   missing],
            )
            result = _filter_res(df, "genus")
            # Row 1: accepted_rank=genus, genus="Canis"       → kept
            # Row 2: accepted_rank=genus, genus=""            → dropped (empty)
            # Row 3: accepted_rank=genus, genus=missing       → dropped (missing)
            # Row 4: accepted_rank=species, genus="Canis"     → kept
            # Row 5: accepted_rank=species, genus=missing     → dropped (missing)
            @test nrow(result) == 2
            @test all(g -> g == "Canis", result.genus)
        end

        @testset "family column present" begin
            df = _make_df(
                ["family",  "species", "genus"],
                rank_col = :family,
                rank_col_vals = ["Canidae", missing, "Felidae"],
            )
            result = _filter_res(df, "family")
            # Row 1: accepted_rank=family, family="Canidae"   → kept
            # Row 2: accepted_rank=species, family=missing    → dropped
            # Row 3: accepted_rank=genus, family="Felidae"    → kept
            @test nrow(result) == 2
        end

        @testset "no named column — only accepted_rank criterion applies" begin
            df = _make_df(["genus", "species", "order"])   # no genus column
            result = _filter_res(df, "genus")
            @test nrow(result) == 2
            @test Set(result.accepted_rank) == Set(["genus", "species"])
        end

    end

    # -----------------------------------------------------------------------
    @testset "copy semantics (non-mutating)" begin

        df = _make_df(["genus", "order", "species"])
        original_nrow = nrow(df)
        original_ranks = copy(df.accepted_rank)

        result = _filter_res(df, "genus")

        # Input is unchanged
        @test nrow(df) == original_nrow
        @test df.accepted_rank == original_ranks

        # Returned object is a distinct DataFrame
        @test result !== df
        @test nrow(result) == 2

    end

    # -----------------------------------------------------------------------
    @testset "in-place version (!)" begin

        @testset "returns the same object" begin
            df = _make_df(["genus", "order"])
            result = _filter_res!(df, "genus")
            @test result === df
        end

        @testset "mutates the input" begin
            df = _make_df(["genus", "order", "species"])
            _filter_res!(df, "genus")
            @test nrow(df) == 2
            @test Set(df.accepted_rank) == Set(["genus", "species"])
        end

        @testset "produces identical results to non-mutating version" begin
            ranks = ["subspecies", "species", "genus", "family", "order", missing]
            df_mut   = _make_df(ranks)
            df_copy  = _make_df(ranks)

            _filter_res!(df_mut, "genus")
            result_copy = _filter_res(df_copy, "genus")

            @test nrow(df_mut) == nrow(result_copy)
            @test sort(collect(skipmissing(df_mut.accepted_rank))) ==
                  sort(collect(skipmissing(result_copy.accepted_rank)))
        end

    end

    # -----------------------------------------------------------------------
    @testset "edge cases" begin

        @testset "empty input DataFrame" begin
            df = _make_df(String[])
            @test nrow(_filter_res(df, "genus"))  == 0
            @test nrow(_filter_res!(df, "genus")) == 0
        end

        @testset "all rows pass" begin
            df = _make_df(["subspecies", "species", "genus"])
            @test nrow(_filter_res(df, "genus")) == 3
        end

        @testset "no rows pass" begin
            df = _make_df(["order", "phylum", "kingdom"])
            @test nrow(_filter_res(df, "genus")) == 0
        end

        @testset "single passing row" begin
            df = _make_df(["species"])
            result = _filter_res(df, "genus")
            @test nrow(result) == 1
            @test result.accepted_rank[1] == "species"
        end

        @testset "single failing row" begin
            df = _make_df(["order"])
            @test nrow(_filter_res(df, "genus")) == 0
        end

    end

    # -----------------------------------------------------------------------
    @testset "unknown rank throws ArgumentError" begin

        df = _make_df(["genus"])
        @test_throws ArgumentError _filter_res(df,  "bogus")
        @test_throws ArgumentError _filter_res!(copy(df), "bogus")

    end

    # -----------------------------------------------------------------------
    @testset "subgenus rank handling" begin

        @testset "subgenus passes genus filter" begin
            # A row with accepted_rank = "subgenus" is finer than genus and
            # should be kept when filtering at genus resolution.
            df = _make_df(["subgenus", "genus", "family"])
            result = _filter_res(df, "genus")
            @test nrow(result) == 2
            @test Set(result.accepted_rank) == Set(["subgenus", "genus"])
        end

        @testset "subgenus is finer than genus, coarser than species" begin
            valid_genus  = _ranks_finer("genus")
            valid_species = _ranks_finer("species")
            @test "subgenus" ∈ valid_genus
            @test "subgenus" ∉ valid_species
        end

    end

end
