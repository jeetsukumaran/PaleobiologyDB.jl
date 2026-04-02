# test/curator_taxonomy_namevalidation.jl
# Tests for PaleobiologyDB.Curator taxonomy name-validation functions:
#   isvalid_taxon, audit_taxonomy, filter_valid_taxon_names
#
# Offline tests use a mock taxa-list snapshot injected directly into the
# module-level Refs so no network access is required.
#
# Live tests (gated on ENV["PBDB_LIVE"]="1") exercise the real API and
# the full snapshot download path.

using Test
using DataFrames
using PaleobiologyDB

const _isvalid        = PaleobiologyDB.Curator.isvalid_taxon
const _audit          = PaleobiologyDB.Curator.audit_taxonomy
const _filter         = PaleobiologyDB.Curator.filter_valid_taxon_names
const _store_info     = PaleobiologyDB.Curator.Store.info
const _store_list     = PaleobiologyDB.Curator.Store.list

# ---------------------------------------------------------------------------
# Helpers: inject a mock taxa index so offline tests never touch the network
# ---------------------------------------------------------------------------

const _NAME_SET_REF   = PaleobiologyDB.Curator._TAXA_NAME_SET
const _RANK_IDX_REF   = PaleobiologyDB.Curator._TAXA_RANK_INDEX

function _inject_mock_index!(names_with_ranks::Dict{String, String})
    name_set  = Set{String}(keys(names_with_ranks))
    rank_idx  = Dict{String, Set{String}}(
        n => Set{String}([r]) for (n, r) in names_with_ranks
    )
    _NAME_SET_REF[]  = name_set
    _RANK_IDX_REF[]  = rank_idx
end

function _clear_mock_index!()
    _NAME_SET_REF[]  = nothing
    _RANK_IDX_REF[]  = nothing
end

# Mock data mirroring a Plesiosauria family-level dataset
const _MOCK_TAXA = Dict(
    "Pliosauridae"    => "family",
    "Polycotylidae"   => "family",
    "Elasmosauridae"  => "family",
    "Leptocleididae"  => "family",
    "Cryptoclididae"  => "family",
    "Plesiosauridae"  => "family",
    "Microcleididae"  => "family",
    "Rhomaleosauridae"=> "family",
    "Plesiosauria"    => "order",   # valid but wrong rank for :family check
)

# ---------------------------------------------------------------------------
# isvalid_taxon — offline (snapshot mode with mock index)
# ---------------------------------------------------------------------------

@testset "isvalid_taxon — snapshot (offline mock)" begin
    _inject_mock_index!(_MOCK_TAXA)

    @test _isvalid("")                         == false
    @test _isvalid("   ")                      == false
    @test _isvalid("Pliosauridae")             == true
    @test _isvalid("NO_FAMILY_SPECIFIED")      == false
    @test _isvalid("missing")                  == false

    # InlineStrings compatibility: pass a non-String AbstractString
    @test _isvalid(SubString("Pliosauridae", 1)) == true

    # validate_correct_rank checks
    @test _isvalid("Pliosauridae";  validate_correct_rank = :family) == true
    @test _isvalid("Pliosauridae";  validate_correct_rank = :genus)  == false
    @test _isvalid("Plesiosauria";  validate_correct_rank = :order)  == true
    @test _isvalid("Plesiosauria";  validate_correct_rank = :family) == false
    @test _isvalid("NO_FAMILY_SPECIFIED"; validate_correct_rank = :family) == false

    _clear_mock_index!()
end

# ---------------------------------------------------------------------------
# audit_taxonomy — offline
# ---------------------------------------------------------------------------

@testset "audit_taxonomy — offline mock" begin
    _inject_mock_index!(_MOCK_TAXA)

    df = DataFrame(
        family = Union{Missing, String}[
            "Pliosauridae",
            "NO_FAMILY_SPECIFIED",
            missing,
            "Elasmosauridae",
            "",
            "Polycotylidae",
        ]
    )

    mask = _audit(df, :family)

    @test mask isa Vector{Bool}
    @test length(mask) == nrow(df)
    @test mask == [true, false, false, true, false, true]

    # validate_correct_rank: all family names should pass; non-family rows fail
    df2 = DataFrame(
        family = Union{Missing, String}["Pliosauridae", "Plesiosauria", missing]
    )
    mask2 = _audit(df2, :family; validate_correct_rank = true)
    @test mask2 == [true, false, false]  # Plesiosauria is :order, not :family

    _clear_mock_index!()
end

# ---------------------------------------------------------------------------
# filter_valid_taxon_names — offline
# ---------------------------------------------------------------------------

@testset "filter_valid_taxon_names — offline mock" begin
    _inject_mock_index!(_MOCK_TAXA)

    df = DataFrame(
        occ_id = 1:5,
        family = Union{Missing, String}[
            "Pliosauridae",
            "NO_FAMILY_SPECIFIED",
            missing,
            "Elasmosauridae",
            "",
        ]
    )

    filtered = _filter(df, :family)

    @test filtered isa DataFrame
    @test nrow(filtered) == 2
    @test Set(filtered.occ_id) == Set([1, 4])

    # Empty DataFrame → empty result
    empty_df = DataFrame(family = Union{Missing, String}[])
    @test nrow(_filter(empty_df, :family)) == 0

    # All-missing column → empty result
    all_missing = DataFrame(family = Union{Missing, String}[missing, missing])
    @test nrow(_filter(all_missing, :family)) == 0

    _clear_mock_index!()
end

# ---------------------------------------------------------------------------
# Store.info / Store.list — always available (no network)
# ---------------------------------------------------------------------------

@testset "Curator.Store metadata" begin
    info = _store_info(:taxa_list)

    @test info isa NamedTuple
    @test haskey(info, :name)
    @test haskey(info, :description)
    @test haskey(info, :path)
    @test haskey(info, :exists)
    @test haskey(info, :size_mb)
    @test haskey(info, :age_days)
    @test haskey(info, :max_age_days)
    @test haskey(info, :is_fresh)
    @test info.name == :taxa_list
    @test info.max_age_days == 30

    stores = _store_list()
    @test stores isa Vector
    @test any(s.name == :taxa_list for s in stores)
end

# ---------------------------------------------------------------------------
# Live tests — require ENV["PBDB_LIVE"]="1"  (LIVE constant defined in runtests.jl)
# ---------------------------------------------------------------------------

@testset "isvalid_taxon — live snapshot" begin
    if !LIVE
        @info "Live name-validation tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    # Snapshot path (triggers download on first run)
    @test _isvalid("Pliosauridae")                                     == true
    @test _isvalid("NO_FAMILY_SPECIFIED")                              == false
    @test _isvalid("")                                                 == false
    @test _isvalid("Pliosauridae"; validate_correct_rank = :family)   == true
    @test _isvalid("Pliosauridae"; validate_correct_rank = :genus)    == false

    # Query path (live API, DataCaches-backed)
    @test _isvalid("Pliosauridae";       validation_authority = :query) == true
    @test _isvalid("NO_FAMILY_SPECIFIED"; validation_authority = :query) == false
end

@testset "filter_valid_taxon_names — live snapshot" begin
    if !LIVE
        return
    end

    df = DataFrame(
        family = Union{Missing, String}[
            "Pliosauridae",
            "NO_FAMILY_SPECIFIED",
            missing,
            "Elasmosauridae",
        ]
    )

    filtered = _filter(df, :family)
    @test nrow(filtered) == 2
    @test Set(filtered.family) == Set(["Pliosauridae", "Elasmosauridae"])

    # With rank validation
    filtered_rank = _filter(df, :family; validate_correct_rank = true)
    @test nrow(filtered_rank) == 2
end
