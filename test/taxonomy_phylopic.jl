# test/taxonomy_phylopic.jl
# Tests for PaleobiologyDB.Taxonomy PhyloPic integration:
#   acquire_phylopic (string and DataFrame variants)
#   augment_phylopic
#   phylopic_images_dataframe
#
# Offline tests bypass network by injecting the build number Ref directly,
# so _ensure_phylopic_build() is never triggered.
#
# Live tests (gated on ENV["PBDB_LIVE"]="1") call the real PBDB + PhyloPic APIs.

using Test
using DataFrames
using DataCaches
using PaleobiologyDB

const _phylopic_acquire              = PaleobiologyDB.Taxonomy.acquire_phylopic
const _phylopic_augment              = PaleobiologyDB.Taxonomy.augment_phylopic
const _phylopic_list_images          = PaleobiologyDB.Taxonomy.phylopic_images_dataframe
const _PHYLOPIC_BASE_COLUMNS         = PaleobiologyDB.Taxonomy.PhyloPicPBDB._PHYLOPIC_BASE_COLUMNS
const _PHYLOPIC_IMAGE_LIST_COLUMNS   = PaleobiologyDB.Taxonomy.PhyloPicPBDB._PHYLOPIC_IMAGE_LIST_COLUMNS
const _phylopic_null_record_fn       = PaleobiologyDB.Taxonomy.PhyloPicPBDB._phylopic_null_record
const _apply_prefix_fn               = PaleobiologyDB.Taxonomy.PhyloPicPBDB._apply_fieldname_prefix
const _cc_label_fn                   = PaleobiologyDB.Taxonomy.PhyloPicPBDB._cc_license_label
const _PHYLOPIC_BUILD_REF            = PaleobiologyDB.Taxonomy.PhyloPicPBDB._PHYLOPIC_BUILD

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
        @test_throws ArgumentError _phylopic_acquire(df, :accepted_name)
    end

    @testset "DataFrame variant — missing/empty taxon values → missing rows" begin
        # Inject build number so _ensure_phylopic_build() never hits the network.
        # We also rely on the fact that missing/empty values short-circuit before
        # any API call is made.
        _PHYLOPIC_BUILD_REF[] = 999_999  # sentinel; real calls would fail at resolve step

        df = DataFrame(
            taxon = Union{String, Missing}[missing, "", "   "],
        )
        pics = _phylopic_acquire(df, :taxon)

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
        pics = _phylopic_acquire(df, :taxon)
        @test ncol(pics) == length(_PHYLOPIC_BASE_COLUMNS)

        _PHYLOPIC_BUILD_REF[] = nothing
    end

    @testset "augment_phylopic — column count" begin
        _PHYLOPIC_BUILD_REF[] = 999_999

        df       = DataFrame(id = [1, 2], taxon = Union{String, Missing}[missing, missing])
        enriched = _phylopic_augment(df, :taxon)
        @test enriched isa DataFrame
        @test nrow(enriched) == nrow(df)
        @test ncol(enriched) == ncol(df) + length(_PHYLOPIC_BASE_COLUMNS)

        _PHYLOPIC_BUILD_REF[] = nothing
    end

    @testset "augment_phylopic — custom prefix" begin
        _PHYLOPIC_BUILD_REF[] = 999_999

        df       = DataFrame(t = Union{String, Missing}[missing])
        enriched = _phylopic_augment(df, :t, "x_")
        @test hasproperty(enriched, :x_uuid)
        @test hasproperty(enriched, :t)          # original col preserved
        @test !hasproperty(enriched, :phylopic_uuid)

        _PHYLOPIC_BUILD_REF[] = nothing
    end

    @testset "autocaching — acquire_phylopic is a valid func reference for set_autocaching!" begin
        # Structural test: the caching machinery is wired to acquire_phylopic
        # (the user-visible function reference used inside _phylopic_lookup_taxon).
        # Both acquire_phylopic and augment_phylopic are controlled via this reference.
        @test_nowarn PaleobiologyDB.set_autocaching!(true,  _phylopic_acquire)
        @test_nowarn PaleobiologyDB.set_autocaching!(false, _phylopic_acquire)
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
        rec = _phylopic_acquire("Tyrannosaurus")
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
        rec = _phylopic_acquire("Triceratops", "dino_")
        @test hasproperty(rec, :dino_uuid)
        @test hasproperty(rec, :dino_thumbnail)
        @test !hasproperty(rec, :phylopic_uuid)
        @test !ismissing(rec.dino_uuid)
    end

    @testset "String variant — unknown taxon → all missing" begin
        rec = _phylopic_acquire("ZZZNOMATCH_FAKE_TAXON_XYZ_999")
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
        pics = _phylopic_acquire(df)

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
        pics = _phylopic_acquire(df)

        @test nrow(pics) == 4
        # Rows with the same taxon name must have identical values
        @test pics.phylopic_uuid[1] == pics.phylopic_uuid[3]
        @test pics.phylopic_uuid[2] == pics.phylopic_uuid[4]
    end

    @testset "DataFrame variant — custom taxon_field" begin
        df   = DataFrame(name_col = ["Canis"])
        pics = _phylopic_acquire(df, :name_col)
        @test hasproperty(pics, :phylopic_uuid)
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
        @test ncol(enriched) == ncol(df) + length(_PHYLOPIC_BASE_COLUMNS)
        @test hasproperty(enriched, :id)
        @test hasproperty(enriched, :accepted_name)
        @test hasproperty(enriched, :phylopic_uuid)
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
        # Key property: caching is keyed per (taxon_name, build), not per DataFrame.
        # Two DataFrames with different rows but the same unique taxa should produce
        # no additional cache entries on the second call.
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
        # _phylopic_lookup_taxon, which is instrumented with acquire_phylopic as the
        # func reference.  Enabling autocaching for acquire_phylopic therefore caches
        # all taxon lookups made through augment_phylopic as well.
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

# ---------------------------------------------------------------------------
# phylopic_images_dataframe — offline / unit tests
# ---------------------------------------------------------------------------

@testset "phylopic_images_dataframe — offline / unit" begin

    @testset "_PHYLOPIC_IMAGE_LIST_COLUMNS has 12 entries" begin
        @test length(_PHYLOPIC_IMAGE_LIST_COLUMNS) == 12
    end

    @testset "_PHYLOPIC_IMAGE_LIST_COLUMNS contains expected keys" begin
        expected = [
            :query_taxon_name, :query_node_uuid, :uuid,
            :thumbnail, :vector, :raster, :source_file, :og_image,
            :license, :license_url, :contributor, :attribution,
        ]
        @test _PHYLOPIC_IMAGE_LIST_COLUMNS == expected
    end

    @testset "invalid filter keyword throws ArgumentError" begin
        # The ArgumentError is raised before any network call, so this is
        # fully offline regardless of the build ref state.
        @test_throws ArgumentError _phylopic_list_images("Canis"; filter = :bad_value)
    end
end

# ---------------------------------------------------------------------------
# phylopic_images_dataframe — live tests
# ---------------------------------------------------------------------------

@testset "phylopic_images_dataframe — live" begin
    if !LIVE
        @info "Live phylopic_images_dataframe tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    @testset "Carnivora — clade filter returns many rows" begin
        imgs = _phylopic_list_images("Carnivora")
        @test imgs isa DataFrame
        @test ncol(imgs) == 12
        @test nrow(imgs) >= 10          # expect hundreds in practice
        # Every row must have a non-missing UUID
        @test all(!ismissing, imgs.phylopic_uuid)
        # query context columns must be consistent
        @test all(==("Carnivora"), imgs.phylopic_query_taxon_name)
        @test !ismissing(imgs.phylopic_query_node_uuid[1])
        @test all(==(imgs.phylopic_query_node_uuid[1]), imgs.phylopic_query_node_uuid)
    end

    @testset "filter = :node returns fewer rows than filter = :clade" begin
        clade = _phylopic_list_images("Carnivora"; filter = :clade)
        node  = _phylopic_list_images("Carnivora"; filter = :node)
        @test nrow(node) <= nrow(clade)
    end

    @testset "max_pages = 1 limits results" begin
        limited = _phylopic_list_images("Carnivora"; max_pages = 1)
        all_pages = _phylopic_list_images("Carnivora")
        @test nrow(limited) <= nrow(all_pages)
        @test nrow(limited) >= 1
    end

    @testset "image URL columns are non-missing strings" begin
        imgs = _phylopic_list_images("Canis"; max_pages = 1)
        @test nrow(imgs) >= 1
        for row in eachrow(imgs)
            # raster and thumbnail should be present for well-formed images
            !ismissing(row.phylopic_raster)    && @test startswith(row.phylopic_raster, "https://")
            !ismissing(row.phylopic_thumbnail) && @test startswith(row.phylopic_thumbnail, "https://")
        end
    end

    @testset "unknown taxon returns empty DataFrame with correct columns" begin
        result = _phylopic_list_images("ZZZNOMATCH_FAKE_TAXON_XYZ_999")
        @test result isa DataFrame
        @test nrow(result) == 0
        @test ncol(result) == 12
        for col in _PHYLOPIC_IMAGE_LIST_COLUMNS
            @test hasproperty(result, Symbol("phylopic_" * string(col)))
        end
    end

    @testset "custom prefix produces correctly-named columns on empty result" begin
        result = _phylopic_list_images("ZZZNOMATCH_FAKE_TAXON_XYZ_999", "x_")
        @test ncol(result) == 12
        @test hasproperty(result, :x_uuid)
        @test hasproperty(result, :x_query_taxon_name)
        @test !hasproperty(result, :phylopic_uuid)
    end

    @testset "custom prefix" begin
        imgs = _phylopic_list_images("Canis", "dog_"; max_pages = 1)
        @test hasproperty(imgs, :dog_uuid)
        @test hasproperty(imgs, :dog_query_taxon_name)
        @test !hasproperty(imgs, :phylopic_uuid)
    end
end
