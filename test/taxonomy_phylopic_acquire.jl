# test/taxonomy_phylopic_acquire.jl
# Tests for acquire_phylopic and augment_phylopic.
#
# Offline: structural tests on null record, prefix, missing/empty input,
#          column counts, image_selector dispatch.
# Live:    real PBDB + PhyloPic round-trips for single-name and DataFrame variants.

const _phylopic_acquire   = PaleobiologyDB.Taxonomy.acquire_phylopic
const _phylopic_augment   = PaleobiologyDB.Taxonomy.augment_phylopic
const _PHYLOPIC_BASE_COLS = PaleobiologyDB.Taxonomy.PhyloPicPBDB._PHYLOPIC_BASE_COLUMNS
const _phylopic_null_rec  = PaleobiologyDB.Taxonomy.PhyloPicPBDB._phylopic_null_record
const _apply_prefix       = PaleobiologyDB.Taxonomy.PhyloPicPBDB._apply_fieldname_prefix

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
end
