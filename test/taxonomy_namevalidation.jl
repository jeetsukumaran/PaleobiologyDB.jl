# test/taxonomy_namevalidation.jl
# Tests for PaleobiologyDB.Taxonomy taxonomy name-validation functions:
#   istaxon, audit_taxonomy, drop_unrecognized_taxa, drop_unrecognized_taxa!
#
# Offline tests inject a mock taxa-list index directly into the module-level
# Refs so no network access is required.
#
# Live tests (gated on ENV["PBDB_LIVE"]="1") exercise the real API and
# the full snapshot download path.

using Test
using DataFrames
using PaleobiologyDB

const _istaxon   = PaleobiologyDB.Taxonomy.istaxon
const _audit     = PaleobiologyDB.Taxonomy.audit_taxonomy
const _drop      = PaleobiologyDB.Taxonomy.drop_unrecognized_taxa
const _drop!     = PaleobiologyDB.Taxonomy.drop_unrecognized_taxa!

# ---------------------------------------------------------------------------
# Helpers: inject a mock taxa index so offline tests never touch the network
# ---------------------------------------------------------------------------

const _NAME_SET_REF = PaleobiologyDB.Taxonomy._TAXA_NAME_SET

function _inject_mock_index!(names::AbstractVector{String})
    _NAME_SET_REF[] = Set{String}(names)
end

function _clear_mock_index!()
    _NAME_SET_REF[] = nothing
end

# Mock data mirroring a Plesiosauria family-level dataset
const _MOCK_TAXA = [
    "Pliosauridae",
    "Polycotylidae",
    "Elasmosauridae",
    "Leptocleididae",
    "Cryptoclididae",
    "Plesiosauridae",
    "Microcleididae",
    "Rhomaleosauridae",
    "Plesiosauria",
]

# ---------------------------------------------------------------------------
# istaxon — offline (snapshot mode with mock index)
# ---------------------------------------------------------------------------

@testset "istaxon — snapshot (offline mock)" begin
    _inject_mock_index!(_MOCK_TAXA)

    @test _istaxon("")                    == false
    @test _istaxon("   ")                 == false
    @test _istaxon("Pliosauridae")        == true
    @test _istaxon("NO_FAMILY_SPECIFIED") == false
    @test _istaxon("missing")             == false

    # InlineStrings compatibility: AbstractString subtypes should work
    @test _istaxon(SubString("Pliosauridae", 1)) == true

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

    _clear_mock_index!()
end

# ---------------------------------------------------------------------------
# drop_unrecognized_taxa (non-mutating) — offline
# ---------------------------------------------------------------------------

@testset "drop_unrecognized_taxa — offline mock" begin
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

    filtered = _drop(df, :family)

    @test filtered isa DataFrame
    @test nrow(filtered) == 2
    @test Set(filtered.occ_id) == Set([1, 4])
    @test nrow(df) == 5  # original unchanged

    # Edge cases
    @test nrow(_drop(DataFrame(family = Union{Missing,String}[]),             :family)) == 0
    @test nrow(_drop(DataFrame(family = Union{Missing,String}[missing, missing]), :family)) == 0

    _clear_mock_index!()
end

# ---------------------------------------------------------------------------
# drop_unrecognized_taxa! (in-place) — offline
# ---------------------------------------------------------------------------

@testset "drop_unrecognized_taxa! — offline mock" begin
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
    original_ref = df  # same object

    result = _drop!(df, :family)

    @test result === original_ref  # same object returned
    @test nrow(df) == 2
    @test Set(df.occ_id) == Set([1, 4])

    _clear_mock_index!()
end

# ---------------------------------------------------------------------------
# Taxonomy.Store metadata — always available (no network)
# ---------------------------------------------------------------------------

@testset "Depot metadata" begin
    info = PaleobiologyDB.Depot.info(:pbdb_taxa)

    @test info isa NamedTuple
    @test info.name         == :pbdb_taxa
    @test info.max_age_days == 30
    @test haskey(info, :path)
    @test haskey(info, :exists)
    @test haskey(info, :size_mb)
    @test haskey(info, :age_days)
    @test haskey(info, :is_fresh)
    @test haskey(info, :description)

    stores = PaleobiologyDB.Depot.list()
    @test stores isa Vector
    @test any(s.name == :pbdb_taxa for s in stores)
end

# ---------------------------------------------------------------------------
# Live tests — require ENV["PBDB_LIVE"]="1"  (LIVE constant defined in runtests.jl)
# ---------------------------------------------------------------------------

@testset "istaxon — live snapshot" begin
    if !LIVE
        @info "Live name-validation tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    @test _istaxon("Pliosauridae")        == true
    @test _istaxon("NO_FAMILY_SPECIFIED") == false
    @test _istaxon("")                    == false

    # Query authority (live API, DataCaches-backed)
    @test _istaxon("Pliosauridae";        validation_authority = :query) == true
    @test _istaxon("NO_FAMILY_SPECIFIED"; validation_authority = :query) == false
end

@testset "drop_unrecognized_taxa — live snapshot" begin
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

    filtered = _drop(df, :family)
    @test nrow(filtered) == 2
    @test Set(filtered.family) == Set(["Pliosauridae", "Elasmosauridae"])
end
