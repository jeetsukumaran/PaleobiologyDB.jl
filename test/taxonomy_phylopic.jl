# test/taxonomy_phylopic.jl
# Tests for PaleobiologyDB.Taxonomy PhyloPic integration:
#   pbdb_phylopic (string and DataFrame variants)
#   pbdb_augment_phylopic
#
# Offline tests bypass network by injecting the build number Ref directly,
# so _ensure_phylopic_build() is never triggered.
#
# Live tests (gated on ENV["PBDB_LIVE"]="1") call the real PBDB + PhyloPic APIs.

using Test
using DataFrames
using PaleobiologyDB

const _phylopic_pbdb_phylopic        = PaleobiologyDB.Taxonomy.pbdb_phylopic
const _phylopic_augment              = PaleobiologyDB.Taxonomy.pbdb_augment_phylopic
const _PHYLOPIC_BASE_COLUMNS         = PaleobiologyDB.Taxonomy._PHYLOPIC_BASE_COLUMNS
const _phylopic_null_record_fn       = PaleobiologyDB.Taxonomy._phylopic_null_record
const _apply_prefix_fn               = PaleobiologyDB.Taxonomy._apply_fieldname_prefix
const _cc_label_fn                   = PaleobiologyDB.Taxonomy._cc_license_label
const _PHYLOPIC_BUILD_REF            = PaleobiologyDB.Taxonomy._PHYLOPIC_BUILD

# ---------------------------------------------------------------------------
# Offline unit tests
# ---------------------------------------------------------------------------

@testset "PhyloPic — offline / unit" begin

    @testset "_phylopic_null_record structure" begin
        rec = _phylopic_null_record_fn()
        @test rec isa NamedTuple
        @test length(rec) == length(_PHYLOPIC_BASE_COLUMNS)
        for col in _PHYLOPIC_BASE_COLUMNS
            @test hasproperty(rec, col)
            @test ismissing(getfield(rec, col))
        end
    end

    @testset "_apply_fieldname_prefix — non-empty prefix" begin
        rec      = _phylopic_null_record_fn()
        prefixed = _apply_prefix_fn(rec, "foo_")
        for col in _PHYLOPIC_BASE_COLUMNS
            @test  hasproperty(prefixed, Symbol("foo_" * string(col)))
            @test !hasproperty(prefixed, col)
        end
    end

    @testset "_apply_fieldname_prefix — default 'phylopic_' prefix" begin
        rec      = _phylopic_null_record_fn()
        prefixed = _apply_prefix_fn(rec, "phylopic_")
        @test hasproperty(prefixed, :phylopic_uuid)
        @test hasproperty(prefixed, :phylopic_thumbnail)
        @test !hasproperty(prefixed, :uuid)
    end

    @testset "_apply_fieldname_prefix — empty string is no-op" begin
        rec       = _phylopic_null_record_fn()
        unchanged = _apply_prefix_fn(rec, "")
        @test keys(unchanged) == keys(rec)
        for col in _PHYLOPIC_BASE_COLUMNS
            @test hasproperty(unchanged, col)
        end
    end

    @testset "_cc_license_label" begin
        @test _cc_label_fn("https://creativecommons.org/licenses/by/4.0/")       == "CC BY 4.0"
        @test _cc_label_fn("https://creativecommons.org/licenses/by-nc/3.0/")    == "CC BY NC 3.0"
        @test _cc_label_fn("https://creativecommons.org/licenses/by-nc-sa/4.0/") == "CC BY NC SA 4.0"
        @test _cc_label_fn("https://creativecommons.org/publicdomain/zero/1.0/") == "CC0 1.0"
        # Unknown URL passes through unchanged
        @test _cc_label_fn("https://example.com/some-license") == "https://example.com/some-license"
    end

    @testset "DataFrame variant — missing taxon_field throws ArgumentError" begin
        df = DataFrame(wrong_col = ["Canis lupus"])
        @test_throws ArgumentError _phylopic_pbdb_phylopic(df, :accepted_name)
    end

    @testset "DataFrame variant — missing/empty taxon values → missing rows" begin
        # Inject build number so _ensure_phylopic_build() never hits the network.
        # We also rely on the fact that missing/empty values short-circuit before
        # any API call is made.
        _PHYLOPIC_BUILD_REF[] = 999_999  # sentinel; real calls would fail at resolve step

        df = DataFrame(
            taxon = Union{String, Missing}[missing, "", "   "],
        )
        pics = _phylopic_pbdb_phylopic(df, :taxon)

        @test pics isa DataFrame
        @test nrow(pics) == 3
        for col in _PHYLOPIC_BASE_COLUMNS
            dest = Symbol("phylopic_" * string(col))
            @test hasproperty(pics, dest)
            @test all(ismissing, pics[!, dest])
        end

        _PHYLOPIC_BUILD_REF[] = nothing   # reset so live tests get a real build
    end

    @testset "DataFrame variant — 14 output columns" begin
        _PHYLOPIC_BUILD_REF[] = 999_999

        df   = DataFrame(taxon = Union{String, Missing}[missing])
        pics = _phylopic_pbdb_phylopic(df, :taxon)
        @test ncol(pics) == length(_PHYLOPIC_BASE_COLUMNS)

        _PHYLOPIC_BUILD_REF[] = nothing
    end

    @testset "pbdb_augment_phylopic — column count" begin
        _PHYLOPIC_BUILD_REF[] = 999_999

        df       = DataFrame(id = [1, 2], taxon = Union{String, Missing}[missing, missing])
        enriched = _phylopic_augment(df, :taxon)
        @test enriched isa DataFrame
        @test nrow(enriched) == nrow(df)
        @test ncol(enriched) == ncol(df) + length(_PHYLOPIC_BASE_COLUMNS)

        _PHYLOPIC_BUILD_REF[] = nothing
    end

    @testset "pbdb_augment_phylopic — custom prefix" begin
        _PHYLOPIC_BUILD_REF[] = 999_999

        df       = DataFrame(t = Union{String, Missing}[missing])
        enriched = _phylopic_augment(df, :t, "x_")
        @test hasproperty(enriched, :x_uuid)
        @test hasproperty(enriched, :t)          # original col preserved
        @test !hasproperty(enriched, :phylopic_uuid)

        _PHYLOPIC_BUILD_REF[] = nothing
    end
end

# ---------------------------------------------------------------------------
# Live tests (require network + real PBDB + PhyloPic data)
# ---------------------------------------------------------------------------

@testset "PhyloPic — live" begin
    if !LIVE
        @info "Live PhyloPic tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    @testset "String variant — Tyrannosaurus (default prefix)" begin
        rec = _phylopic_pbdb_phylopic("Tyrannosaurus")
        @test rec isa NamedTuple
        @test hasproperty(rec, :phylopic_uuid)
        @test !ismissing(rec.phylopic_uuid)
        @test !ismissing(rec.phylopic_node_uuid)
        @test !ismissing(rec.phylopic_thumbnail)
        @test !ismissing(rec.phylopic_license_url)
        @test startswith(rec.phylopic_license_url, "https://")
        @test !ismissing(rec.phylopic_pbdb_taxon_id)
        @test rec.phylopic_pbdb_taxon_id isa Int
    end

    @testset "String variant — custom prefix" begin
        rec = _phylopic_pbdb_phylopic("Triceratops", "dino_")
        @test hasproperty(rec, :dino_uuid)
        @test hasproperty(rec, :dino_thumbnail)
        @test !hasproperty(rec, :phylopic_uuid)
        @test !ismissing(rec.dino_uuid)
    end

    @testset "String variant — unknown taxon → all missing" begin
        rec = _phylopic_pbdb_phylopic("ZZZNOMATCH_FAKE_TAXON_XYZ_999")
        @test rec isa NamedTuple
        for col in _PHYLOPIC_BASE_COLUMNS
            dest = Symbol("phylopic_" * string(col))
            @test ismissing(rec[dest])
        end
    end

    @testset "DataFrame variant — basic enrichment" begin
        df = DataFrame(
            accepted_name = ["Tyrannosaurus", "Triceratops", "ZZZNOMATCH_XYZ_999"],
        )
        pics = _phylopic_pbdb_phylopic(df)

        @test pics isa DataFrame
        @test nrow(pics) == 3
        @test ncol(pics) == length(_PHYLOPIC_BASE_COLUMNS)
        @test !ismissing(pics.phylopic_uuid[1])
        @test !ismissing(pics.phylopic_uuid[2])
        @test  ismissing(pics.phylopic_uuid[3])
    end

    @testset "DataFrame variant — deduplication (repeated names)" begin
        df = DataFrame(
            accepted_name = ["Tyrannosaurus", "Triceratops",
                             "Tyrannosaurus", "Triceratops"],
        )
        pics = _phylopic_pbdb_phylopic(df)

        @test nrow(pics) == 4
        # Rows with the same taxon name must have identical values
        @test pics.phylopic_uuid[1] == pics.phylopic_uuid[3]
        @test pics.phylopic_uuid[2] == pics.phylopic_uuid[4]
    end

    @testset "DataFrame variant — custom taxon_field" begin
        df   = DataFrame(name_col = ["Canis"])
        pics = _phylopic_pbdb_phylopic(df, :name_col)
        @test hasproperty(pics, :phylopic_uuid)
        @test !ismissing(pics.phylopic_uuid[1])
    end

    @testset "DataFrame variant — custom fieldname_prefix" begin
        df   = DataFrame(accepted_name = ["Canis"])
        pics = _phylopic_pbdb_phylopic(df, :accepted_name, "my_")
        @test  hasproperty(pics, :my_uuid)
        @test !hasproperty(pics, :phylopic_uuid)
        @test !ismissing(pics.my_uuid[1])
    end

    @testset "pbdb_augment_phylopic — all original cols preserved" begin
        df       = DataFrame(id = [1], accepted_name = ["Canis"])
        enriched = _phylopic_augment(df)

        @test nrow(enriched) == 1
        @test ncol(enriched) == ncol(df) + length(_PHYLOPIC_BASE_COLUMNS)
        @test hasproperty(enriched, :id)
        @test hasproperty(enriched, :accepted_name)
        @test hasproperty(enriched, :phylopic_uuid)
        @test !ismissing(enriched.phylopic_uuid[1])
    end

    @testset "multi-level enrichment pattern" begin
        df      = DataFrame(genus = ["Tyrannosaurus"], accepted_name = ["Tyrannosaurus rex"])
        g_pics  = _phylopic_pbdb_phylopic(df, :genus,         "genus_phylopic_")
        sp_pics = _phylopic_pbdb_phylopic(df, :accepted_name, "sp_phylopic_")
        full    = hcat(df, g_pics, sp_pics)

        @test hasproperty(full, :genus_phylopic_uuid)
        @test hasproperty(full, :sp_phylopic_uuid)
        @test hasproperty(full, :genus)
        @test hasproperty(full, :accepted_name)
    end
end
