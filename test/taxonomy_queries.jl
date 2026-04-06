# test/taxonomy_queries.jl
# Tests for PaleobiologyDB.Taxonomy taxonomy tree-query functions:
#   ls_taxonomic_ranks, ls_registered_taxa,
#   ls_child_taxa, ls_parent_taxa,
#   taxon_occursin (2-arg and 1-arg ByRow forms)
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

const _ls_ranks    = PaleobiologyDB.Taxonomy.ls_taxonomic_ranks
const _ls_regtaxa  = PaleobiologyDB.Taxonomy.ls_registered_taxa
const _ls_children = PaleobiologyDB.Taxonomy.ls_child_taxa
const _ls_parents  = PaleobiologyDB.Taxonomy.ls_parent_taxa
const _taxon_in    = PaleobiologyDB.Taxonomy.taxon_occursin
const _PBDB_RANKS  = PaleobiologyDB.Taxonomy.PBDB_RANK_HIERARCHY

# ---------------------------------------------------------------------------
# Helpers: inject and clear mock hierarchy indices
# ---------------------------------------------------------------------------

const _NAME_IDX_REF     = PaleobiologyDB.Taxonomy._TAXA_HIERARCHY_NAME_INDEX
const _NO_IDX_REF       = PaleobiologyDB.Taxonomy._TAXA_HIERARCHY_NO_INDEX
const _CHILDREN_IDX_REF = PaleobiologyDB.Taxonomy._TAXA_CHILDREN_INDEX
const _TaxonInfo        = PaleobiologyDB.Taxonomy._TaxonInfo

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
# ls_taxonomic_ranks — no network needed
# ---------------------------------------------------------------------------

@testset "ls_taxonomic_ranks" begin
    ranks = _ls_ranks()
    @test ranks isa Vector{String}
    @test length(ranks) == 19
    @test ranks[1]   == "subspecies"
    @test ranks[end] == "kingdom"
    @test ranks == _PBDB_RANKS          # same order
    @test ranks !== _PBDB_RANKS         # independent copy — mutation safe
    ranks[1] = "MUTATED"
    @test _PBDB_RANKS[1] == "subspecies"
end

# ---------------------------------------------------------------------------
# ls_registered_taxa — offline (mock name index)
# ---------------------------------------------------------------------------

@testset "ls_registered_taxa — offline mock" begin
    _inject_mock_hierarchy!()

    @testset "nothing → all accepted names sorted" begin
        result = _ls_regtaxa()
        @test result isa Vector{String}
        @test Set(result) == Set([
            "Carnivora", "Canidae", "Felidae",
            "Canis", "Vulpes", "Felis",
            "Canis lupus", "Canis aureus", "Vulpes vulpes", "Felis catus",
        ])
        @test result == sort(result)
    end

    @testset "single Regex — matching names" begin
        result = _ls_regtaxa(r"^Canis\b")
        @test Set(result) == Set(["Canis", "Canis lupus", "Canis aureus"])
        @test result == sort(result)
    end

    @testset "single Regex — no match → empty" begin
        @test _ls_regtaxa(r"Tyrannosaurus") == String[]
    end

    @testset "vector of Regex — union" begin
        result = _ls_regtaxa([r"^Canis\b", r"^Vulpes\b"])
        @test Set(result) == Set(["Canis", "Canis lupus", "Canis aureus", "Vulpes", "Vulpes vulpes"])
        @test result == sort(result)
    end

    @testset "vector of Regex — no match → empty" begin
        @test _ls_regtaxa([r"ZZZNOMATCH1", r"ZZZNOMATCH2"]) == String[]
    end

    _clear_mock_hierarchy!()
end

# ---------------------------------------------------------------------------
# taxon_occursin — helper mock DataFrame with augmented columns
# ---------------------------------------------------------------------------

# Build a small DataFrame that already has augmented taxonomy columns so that
# _taxonomy_search_setup takes path 1 (no network access required).
function _mock_augmented_df()
    DataFrame(
        accepted_name  = ["Canis lupus", "Vulpes vulpes", "Felis catus", missing, ""],
        taxonomy_genus    = Union{String,Missing}["Canis",    "Vulpes",   "Felis",   missing, ""],
        taxonomy_family   = Union{String,Missing}["Canidae",  "Canidae",  "Felidae", missing, ""],
        taxonomy_order    = Union{String,Missing}["Carnivora","Carnivora","Carnivora",missing,""],
        taxonomy_clades = [
            "Animalia > Carnivora > Canidae > Canis > Canis lupus",
            "Animalia > Carnivora > Canidae > Vulpes > Vulpes vulpes",
            "Animalia > Carnivora > Felidae > Felis > Felis catus",
            "",
            "",
        ],
    )
end

# Build a DataFrame with original-style columns (no taxonomy_ prefix) for fallback path.
function _mock_original_df()
    DataFrame(
        genus   = Union{String,Missing}["Canis", "Vulpes", "Felis", missing],
        family  = Union{String,Missing}["Canidae","Canidae","Felidae",missing],
    )
end

# ---------------------------------------------------------------------------
# taxon_occursin — 2-arg form (Vector{Bool})
# ---------------------------------------------------------------------------

@testset "taxon_occursin 2-arg — offline mock DataFrame" begin
    df = _mock_augmented_df()

    @testset "AbstractString — exact match" begin
        mask = _taxon_in("Canis", df)
        @test mask isa Vector{Bool}
        @test mask == [true, false, false, false, false]
    end

    @testset "AbstractString — no match" begin
        @test _taxon_in("Ursidae", df) == [false, false, false, false, false]
    end

    @testset "Regex — match in rank column" begin
        mask = _taxon_in(r"^Canis\b", df)
        @test mask[1] == true    # taxonomy_genus = "Canis"
        @test mask[2] == false
        @test mask[3] == false
    end

    @testset "Regex — match in taxonomy_clades" begin
        mask = _taxon_in(r"Canidae", df)
        @test mask[1] == true   # Canis lupus
        @test mask[2] == true   # Vulpes vulpes (also in Canidae)
        @test mask[3] == false  # Felis catus (Felidae)
    end

    @testset "Regex — missing/empty rows never match" begin
        mask = _taxon_in(r".*", df)   # matches any non-empty string
        @test mask[4] == false  # missing row
        @test mask[5] == false  # empty-string row
    end

    @testset "AbstractVector{String} — matchall=true (AND, default)" begin
        # "Canis" must be in one column AND "Canidae" in another
        mask = _taxon_in(["Canis", "Canidae"], df)
        @test mask[1] == true   # genus=Canis, family=Canidae ✓
        @test mask[2] == false  # genus=Vulpes (not "Canis")
        @test mask[3] == false
    end

    @testset "AbstractVector{String} — matchall=false (OR)" begin
        mask = _taxon_in(["Canis", "Vulpes"], df; matchall=false)
        @test mask[1] == true   # genus=Canis
        @test mask[2] == true   # genus=Vulpes
        @test mask[3] == false
    end

    @testset "AbstractVector{Regex} — matchall=true (AND, default)" begin
        # Each pattern must match at least one column
        mask = _taxon_in([r"Canidae", r"^Canis$"], df)
        @test mask[1] == true   # family=Canidae AND genus=Canis ✓
        @test mask[2] == false  # family=Canidae but genus=Vulpes (not "Canis")
        @test mask[3] == false
    end

    @testset "AbstractVector{Regex} — matchall=false (OR)" begin
        mask = _taxon_in([r"^Canis$", r"^Vulpes$"], df; matchall=false)
        @test mask[1] == true   # genus=Canis
        @test mask[2] == true   # genus=Vulpes
        @test mask[3] == false
    end

    @testset "autoaugment=false uses existing augmented cols" begin
        # Even with autoaugment=false, path 1 fires because cols already present
        mask = _taxon_in("Canis", df; autoaugment=false)
        @test mask == [true, false, false, false, false]
    end

    @testset "fallback to original columns" begin
        df_orig = _mock_original_df()
        mask = _taxon_in("Canis", df_orig; autoaugment=false)
        @test mask == [true, false, false, false]
    end
end

# ---------------------------------------------------------------------------
# taxon_occursin — 1-arg form (ByRow predicate)
# ---------------------------------------------------------------------------

@testset "taxon_occursin 1-arg — ByRow predicates" begin
    # ByRow(f) when called on a vector applies f element-wise.
    col = Union{String,Missing}["Canis", "Vulpes", "Canidae", missing, ""]

    @testset "AbstractString — exact match" begin
        pred = _taxon_in("Canis")
        result = pred(col)
        @test result == [true, false, false, false, false]
    end

    @testset "Regex — match" begin
        pred = _taxon_in(r"^Canis\b")
        result = pred(col)
        @test result == [true, false, false, false, false]
    end

    @testset "Regex — missing/empty → false" begin
        pred = _taxon_in(r".*")   # matches any non-empty string
        result = pred(col)
        @test result[4] == false  # missing
        @test result[5] == false  # ""
    end

    @testset "AbstractVector{String} — matchall=true (AND, default)" begin
        # Single value can't equal two different strings → always false for length > 1
        pred = _taxon_in(["Canis", "Vulpes"])
        result = pred(col)
        @test all(!, result)
    end

    @testset "AbstractVector{String} — matchall=false (OR)" begin
        pred = _taxon_in(["Canis", "Vulpes"]; matchall=false)
        result = pred(col)
        @test result == [true, true, false, false, false]
    end

    @testset "AbstractVector{Regex} — matchall=true (AND, default)" begin
        # Both patterns must match the same single value
        taxonomy_col = [
            "Animalia > Carnivora > Canidae > Canis",
            "Animalia > Carnivora > Felidae > Felis",
            missing,
            "",
        ]
        pred = _taxon_in([r"Canidae", r"Canis"])
        result = pred(taxonomy_col)
        @test result[1] == true   # contains both "Canidae" and "Canis"
        @test result[2] == false  # contains "Felidae", not "Canidae"
        @test result[3] == false  # missing
        @test result[4] == false  # empty
    end

    @testset "AbstractVector{Regex} — matchall=false (OR)" begin
        pred = _taxon_in([r"^Canis$", r"^Vulpes$"]; matchall=false)
        result = pred(col)
        @test result == [true, true, false, false, false]
    end

    @testset "predicate usable with subset" begin
        df = _mock_augmented_df()
        # subset(df, :col => pred) calls pred(column_vector) → Vector{Bool}
        result = subset(df, :taxonomy_genus => _taxon_in("Canis"))
        @test nrow(result) == 1
        @test result.taxonomy_genus[1] == "Canis"

        result2 = subset(df, :taxonomy_genus => _taxon_in(["Canis", "Vulpes"]; matchall=false))
        @test nrow(result2) == 2

        result3 = subset(df, :taxonomy_clades => _taxon_in([r"Canidae", r"lupus"]))
        @test nrow(result3) == 1   # only "Canis lupus" matches both
    end
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

@testset "ls_registered_taxa — live snapshot" begin
    if !LIVE
        @info "Live taxonomy-query tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    all_taxa = _ls_regtaxa()
    @test all_taxa isa Vector{String}
    @test length(all_taxa) > 10_000
    @test "Canidae" in all_taxa
    @test "Canis lupus" in all_taxa

    canis = _ls_regtaxa(r"^Canis\b")
    @test "Canis" in canis
    @test "Canis lupus" in canis
    @test all(startswith("Canis"), canis)

    multi = _ls_regtaxa([r"^Canis\b", r"^Vulpes\b"])
    @test "Canis" in multi
    @test "Vulpes" in multi
end

@testset "ls_child_taxa — live snapshot" begin
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
