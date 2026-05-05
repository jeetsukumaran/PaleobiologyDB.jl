# test/taxonomy_phylopic_acquire.jl
# Tests for acquire_phylopic and augment_phylopic.
#
# Offline: structural tests on null record, prefix, missing/empty input,
#          column counts, image_selector dispatch, autocaching wiring.
# Live:    real PBDB + PhyloPic round-trips for single-name and DataFrame variants,
#          plus autocaching write/hit/cross-function tests.

using DataCaches

const _phylopic_acquire   = PaleobiologyDB.PBDBMakie.PhyloPic.acquire_phylopic
const _phylopic_augment   = PaleobiologyDB.PBDBMakie.PhyloPic.augment_phylopic
const _PHYLOPIC_BASE_COLS = PaleobiologyDB.PBDBMakie.PhyloPic._PHYLOPIC_BASE_COLUMNS
const _phylopic_null_rec  = PaleobiologyDB.PBDBMakie.PhyloPic._phylopic_null_record
const _apply_prefix       = PaleobiologyDB.PBDBMakie.PhyloPic._apply_fieldname_prefix

# ---------------------------------------------------------------------------
# Offline unit tests
# ---------------------------------------------------------------------------

@testset "PhyloPic — offline / unit" begin

    @testset "_phylopic_null_record structure" begin
        rec = _phylopic_null_rec()
        @test rec isa NamedTuple
        @test length(rec) == length(_PHYLOPIC_BASE_COLS)
        for col in _PHYLOPIC_BASE_COLS
            @test hasproperty(rec, col)
            @test ismissing(getfield(rec, col))
        end
    end

    @testset "_apply_fieldname_prefix — non-empty prefix" begin
        rec      = _phylopic_null_rec()
        prefixed = _apply_prefix(rec, "foo_")
        for col in _PHYLOPIC_BASE_COLS
            @test  hasproperty(prefixed, Symbol("foo_" * string(col)))
            @test !hasproperty(prefixed, col)
        end
    end

    @testset "_apply_fieldname_prefix — default 'phylopic_' prefix" begin
        rec      = _phylopic_null_rec()
        prefixed = _apply_prefix(rec, "phylopic_")
        @test  hasproperty(prefixed, :phylopic_uuid)
        @test  hasproperty(prefixed, :phylopic_thumbnail)
        @test !hasproperty(prefixed, :uuid)
    end

    @testset "_apply_fieldname_prefix — empty string is no-op" begin
        rec       = _phylopic_null_rec()
        unchanged = _apply_prefix(rec, "")
        @test keys(unchanged) == keys(rec)
        for col in _PHYLOPIC_BASE_COLS
            @test hasproperty(unchanged, col)
        end
    end

    @testset "_cc_license_label (via PhyloPicDB)" begin
        fn = PhyloPicDB._cc_license_label
        @test fn("https://creativecommons.org/licenses/by/4.0/")       == "CC BY 4.0"
        @test fn("https://creativecommons.org/licenses/by-nc/3.0/")    == "CC BY NC 3.0"
        @test fn("https://creativecommons.org/licenses/by-nc-sa/4.0/") == "CC BY NC SA 4.0"
        @test fn("https://creativecommons.org/publicdomain/zero/1.0/") == "CC0 1.0"
        @test fn("https://example.com/some-license") == "https://example.com/some-license"
    end

    @testset "DataFrame variant — missing taxon_field throws ArgumentError" begin
        df = DataFrame(wrong_col = ["Canis lupus"])
        @test_throws ArgumentError _phylopic_acquire(df, :accepted_name)
    end

    @testset "DataFrame variant — missing/empty taxon values → missing rows (no network call)" begin
        # All-missing/empty input: build number must never be fetched (no network).
        # The source short-circuits before calling ensure_build when all names are empty.
        df   = DataFrame(taxon = Union{String, Missing}[missing, "", "   "])
        pics = _phylopic_acquire(df, :taxon)

        @test pics isa DataFrame
        @test nrow(pics) == 3
        for col in _PHYLOPIC_BASE_COLS
            dest = Symbol("phylopic_" * string(col))
            @test hasproperty(pics, dest)
            @test all(ismissing, pics[!, dest])
        end
    end

    @testset "DataFrame variant — 14 output columns" begin
        df   = DataFrame(taxon = Union{String, Missing}[missing])
        pics = _phylopic_acquire(df, :taxon)
        @test ncol(pics) == length(_PHYLOPIC_BASE_COLS)
    end

    @testset "augment_phylopic — column count" begin
        df       = DataFrame(id = [1, 2], taxon = Union{String, Missing}[missing, missing])
        enriched = _phylopic_augment(df, :taxon)
        @test enriched isa DataFrame
        @test nrow(enriched) == nrow(df)
        @test ncol(enriched) == ncol(df) + length(_PHYLOPIC_BASE_COLS)
    end

    @testset "augment_phylopic — custom prefix" begin
        df       = DataFrame(t = Union{String, Missing}[missing])
        enriched = _phylopic_augment(df, :t, "x_")
        @test  hasproperty(enriched, :x_uuid)
        @test  hasproperty(enriched, :t)
        @test !hasproperty(enriched, :phylopic_uuid)
    end

    @testset "_PHYLOPIC_BASE_COLUMNS has 14 entries" begin
        @test length(_PHYLOPIC_BASE_COLS) == 14
    end

    @testset "_PHYLOPIC_BASE_COLUMNS contains expected keys" begin
        expected = [
            :pbdb_taxon_id, :pbdb_lineage, :node_uuid, :matched_name,
            :uuid, :thumbnail, :vector, :raster, :source_file, :og_image,
            :license, :license_url, :contributor, :attribution,
        ]
        @test _PHYLOPIC_BASE_COLS == expected
    end

    @testset "autocaching — acquire_phylopic is a valid func reference for set_autocaching!" begin
        # Structural test: verify the caching machinery accepts acquire_phylopic as
        # the func reference used in _phylopic_lookup_taxon.  Both acquire_phylopic
        # and augment_phylopic are controlled via this reference.
        @test_nowarn PaleobiologyDB.set_autocaching!(true,  _phylopic_acquire)
        @test_nowarn PaleobiologyDB.set_autocaching!(false, _phylopic_acquire)
    end
end

# ---------------------------------------------------------------------------
# Live tests
# ---------------------------------------------------------------------------

@testset "PhyloPic — live" begin
    if !LIVE
        @info "Live PhyloPic tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    @testset "String variant — Tyrannosaurus (default prefix)" begin
        rec = _phylopic_acquire("Tyrannosaurus")
        @test rec isa NamedTuple
        @test  hasproperty(rec, :phylopic_uuid)
        @test !ismissing(rec.phylopic_uuid)
        @test !ismissing(rec.phylopic_node_uuid)
        @test !ismissing(rec.phylopic_thumbnail)
        @test !ismissing(rec.phylopic_license_url)
        @test startswith(rec.phylopic_license_url, "https://")
        @test !ismissing(rec.phylopic_pbdb_taxon_id)
        @test rec.phylopic_pbdb_taxon_id isa Int
    end

    @testset "String variant — custom prefix" begin
        rec = _phylopic_acquire("Triceratops", "dino_")
        @test  hasproperty(rec, :dino_uuid)
        @test  hasproperty(rec, :dino_thumbnail)
        @test !hasproperty(rec, :phylopic_uuid)
        @test !ismissing(rec.dino_uuid)
    end

    @testset "String variant — unknown taxon → all missing" begin
        rec = _phylopic_acquire("ZZZNOMATCH_FAKE_TAXON_XYZ_999")
        @test rec isa NamedTuple
        for col in _PHYLOPIC_BASE_COLS
            dest = Symbol("phylopic_" * string(col))
            @test ismissing(rec[dest])
        end
    end

    @testset "String variant — image_selector = :primary (default)" begin
        rec = _phylopic_acquire("Tyrannosaurus"; image_selector = :primary)
        @test !ismissing(rec.phylopic_uuid)
    end

    @testset "String variant — image_selector = 1 (first clade image)" begin
        rec = _phylopic_acquire("Tyrannosaurus"; image_selector = 1)
        # Should find at least one clade image
        @test !ismissing(rec.phylopic_uuid)
    end

    @testset "String variant — image_selector = 999 (OOB → missing)" begin
        rec = _phylopic_acquire("Tyrannosaurus"; image_selector = 999)
        @test ismissing(rec.phylopic_uuid)
    end

    @testset "DataFrame variant — basic enrichment" begin
        df   = DataFrame(accepted_name = ["Tyrannosaurus", "Triceratops", "ZZZNOMATCH_XYZ_999"])
        pics = _phylopic_acquire(df)

        @test pics isa DataFrame
        @test nrow(pics) == 3
        @test ncol(pics) == length(_PHYLOPIC_BASE_COLS)
        @test !ismissing(pics.phylopic_uuid[1])
        @test !ismissing(pics.phylopic_uuid[2])
        @test  ismissing(pics.phylopic_uuid[3])
    end

    @testset "DataFrame variant — deduplication (repeated names)" begin
        df   = DataFrame(
            accepted_name = ["Tyrannosaurus", "Triceratops", "Tyrannosaurus", "Triceratops"],
        )
        pics = _phylopic_acquire(df)

        @test nrow(pics) == 4
        @test pics.phylopic_uuid[1] == pics.phylopic_uuid[3]
        @test pics.phylopic_uuid[2] == pics.phylopic_uuid[4]
    end

    @testset "DataFrame variant — custom taxon_field" begin
        df   = DataFrame(name_col = ["Canis"])
        pics = _phylopic_acquire(df, :name_col)
        @test  hasproperty(pics, :phylopic_uuid)
        @test !ismissing(pics.phylopic_uuid[1])
    end

    @testset "DataFrame variant — custom fieldname_prefix" begin
        df   = DataFrame(accepted_name = ["Canis"])
        pics = _phylopic_acquire(df, :accepted_name, "my_")
        @test  hasproperty(pics, :my_uuid)
        @test !hasproperty(pics, :phylopic_uuid)
        @test !ismissing(pics.my_uuid[1])
    end

    @testset "augment_phylopic — all original cols preserved" begin
        df       = DataFrame(id = [1], accepted_name = ["Canis"])
        enriched = _phylopic_augment(df)

        @test nrow(enriched) == 1
        @test ncol(enriched) == ncol(df) + length(_PHYLOPIC_BASE_COLS)
        @test  hasproperty(enriched, :id)
        @test  hasproperty(enriched, :accepted_name)
        @test  hasproperty(enriched, :phylopic_uuid)
        @test !ismissing(enriched.phylopic_uuid[1])
    end

    @testset "multi-level enrichment pattern" begin
        df      = DataFrame(genus = ["Tyrannosaurus"], accepted_name = ["Tyrannosaurus rex"])
        g_pics  = _phylopic_acquire(df, :genus,         "genus_phylopic_")
        sp_pics = _phylopic_acquire(df, :accepted_name, "sp_phylopic_")
        full    = hcat(df, g_pics, sp_pics)

        @test hasproperty(full, :genus_phylopic_uuid)
        @test hasproperty(full, :sp_phylopic_uuid)
        @test hasproperty(full, :genus)
        @test hasproperty(full, :accepted_name)
    end

    @testset "PBDB metadata fields populated" begin
        rec = _phylopic_acquire("Canis")
        @test !ismissing(rec.phylopic_pbdb_taxon_id)
        @test rec.phylopic_pbdb_taxon_id isa Int
        @test !ismissing(rec.phylopic_pbdb_lineage)
        @test rec.phylopic_pbdb_lineage isa String
        @test !isempty(rec.phylopic_pbdb_lineage)
    end

    @testset "node_uuid and matched_name are present" begin
        rec = _phylopic_acquire("Tyrannosaurus")
        @test !ismissing(rec.phylopic_node_uuid)
        @test !ismissing(rec.phylopic_matched_name)
        @test !isempty(rec.phylopic_matched_name)
    end

    @testset "caching — second call returns same result as first" begin
        rec1 = _phylopic_acquire("Canis")
        rec2 = _phylopic_acquire("Canis")
        @test rec1 == rec2
    end

    @testset "autocaching — string variant writes and hits cache" begin
        test_cache = DataCache(mktempdir())
        try
            PaleobiologyDB.set_autocaching!(true, _phylopic_acquire; cache = test_cache)

            rec1 = _phylopic_acquire("Tyrannosaurus")
            @test length(test_cache) == 1       # one taxon entry stored

            rec2 = _phylopic_acquire("Tyrannosaurus")
            @test rec1 == rec2                  # identical result from cache
            @test length(test_cache) == 1       # no new entry written
        finally
            PaleobiologyDB.set_autocaching!(false, _phylopic_acquire)
        end
    end

    @testset "autocaching — DataFrame variant shares per-taxon cache across calls" begin
        # Caching is keyed per (taxon_name, build), not per DataFrame.  Two
        # DataFrames with the same unique taxa must produce no additional cache
        # entries on the second call.
        test_cache = DataCache(mktempdir())
        try
            PaleobiologyDB.set_autocaching!(true, _phylopic_acquire; cache = test_cache)

            df1 = DataFrame(accepted_name = ["Tyrannosaurus", "Triceratops"])
            df2 = DataFrame(accepted_name = ["Triceratops", "Tyrannosaurus", "Tyrannosaurus"])

            pics1 = _phylopic_acquire(df1)
            @test length(test_cache) == 2       # 2 unique taxa cached

            pics2 = _phylopic_acquire(df2)
            @test length(test_cache) == 2       # 0 new entries (all cache hits)

            # Tyrannosaurus UUID must be consistent across both DataFrames
            @test pics1.phylopic_uuid[1] == pics2.phylopic_uuid[2]  # T-rex row in df2
            @test pics1.phylopic_uuid[1] == pics2.phylopic_uuid[3]  # duplicate T-rex
        finally
            PaleobiologyDB.set_autocaching!(false, _phylopic_acquire)
        end
    end

    @testset "autocaching — augment_phylopic benefits via acquire_phylopic cache" begin
        # augment_phylopic internally calls acquire_phylopic(df), which calls
        # _phylopic_lookup_taxon, which is instrumented with acquire_phylopic as
        # the func reference.  Enabling autocaching for acquire_phylopic therefore
        # caches all taxon lookups made through augment_phylopic as well.
        test_cache = DataCache(mktempdir())
        try
            PaleobiologyDB.set_autocaching!(true, _phylopic_acquire; cache = test_cache)

            df       = DataFrame(accepted_name = ["Canis"])
            enriched = _phylopic_augment(df)
            @test length(test_cache) == 1       # taxon entry stored via acquire_phylopic

            enriched2 = _phylopic_augment(df)
            @test length(test_cache) == 1       # no new entries
            @test all(enriched.phylopic_uuid .=== enriched2.phylopic_uuid)
        finally
            PaleobiologyDB.set_autocaching!(false, _phylopic_acquire)
        end
    end
end
