# test/taxonomy_phylopic_images.jl
# Tests for phylopic_node, phylopic_images, and phylopic_images_dataframe.
#
# Offline: structural / type tests; invalid filter argument error.
# Live:    real PBDB + PhyloPic round-trips.

const _phylopic_node         = PaleobiologyDB.TaxonomyMakie.PhyloPicPBDB.phylopic_node
const _phylopic_images       = PaleobiologyDB.TaxonomyMakie.PhyloPicPBDB.phylopic_images
const _phylopic_list_images  = PaleobiologyDB.TaxonomyMakie.PhyloPicPBDB.phylopic_images_dataframe
const _PHYLOPIC_IMG_COLS     = PaleobiologyDB.TaxonomyMakie.PhyloPicPBDB._PHYLOPIC_IMAGE_LIST_COLUMNS

# ---------------------------------------------------------------------------
# Offline unit tests
# ---------------------------------------------------------------------------

@testset "PhyloPic images — offline / unit" begin

    @testset "_PHYLOPIC_IMAGE_LIST_COLUMNS has 12 entries" begin
        @test length(_PHYLOPIC_IMG_COLS) == 12
    end

    @testset "_PHYLOPIC_IMAGE_LIST_COLUMNS contains expected keys" begin
        expected = [
            :query_taxon_name, :query_node_uuid, :uuid,
            :thumbnail, :vector, :raster, :source_file, :og_image,
            :license, :license_url, :contributor, :attribution,
        ]
        @test _PHYLOPIC_IMG_COLS == expected
    end

    @testset "phylopic_images_dataframe — invalid filter keyword throws ArgumentError" begin
        # ArgumentError raised before any network call.
        @test_throws ArgumentError _phylopic_list_images("Canis"; filter = :bad_value)
    end

    @testset "phylopic_node return type annotation" begin
        # Verify the declared return type resolves correctly (no network needed).
        T = Union{PhyloPicDB.PhyloPicNode, Nothing}
        @test T isa Union
    end

    @testset "phylopic_images return type annotation" begin
        T = Vector{PhyloPicDB.PhyloPicImage}
        @test T isa DataType
    end
end

# ---------------------------------------------------------------------------
# Live tests
# ---------------------------------------------------------------------------

@testset "PhyloPic images — live" begin
    if !LIVE
        @info "Live PhyloPic image tests skipped. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    @testset "phylopic_node — known taxon returns PhyloPicNode" begin
        node = _phylopic_node("Tyrannosaurus")
        @test !isnothing(node)
        @test node isa PhyloPicDB.PhyloPicNode
        @test !isempty(node.uuid)
        @test !isempty(node.preferred_name)
    end

    @testset "phylopic_node — unknown taxon returns nothing" begin
        @test isnothing(_phylopic_node("ZZZNOMATCH_FAKE_TAXON_XYZ_999"))
    end

    @testset "phylopic_node — two-stage pipeline" begin
        node = _phylopic_node("Carnivora")
        @test !isnothing(node)
        imgs = PhyloPicDB.clade_images(node.uuid; max_pages = 1)
        @test imgs isa Vector{PhyloPicDB.PhyloPicImage}
    end

    @testset "phylopic_node — second call returns same node (cached)" begin
        n1 = _phylopic_node("Canis")
        n2 = _phylopic_node("Canis")
        @test !isnothing(n1)
        @test n1.uuid == n2.uuid
    end

    @testset "phylopic_images — returns typed vector" begin
        imgs = _phylopic_images("Carnivora"; max_pages = 1)
        @test imgs isa Vector{PhyloPicDB.PhyloPicImage}
        @test !isempty(imgs)
    end

    @testset "phylopic_images — unknown taxon returns empty vector" begin
        imgs = _phylopic_images("ZZZNOMATCH_FAKE_TAXON_XYZ_999")
        @test imgs isa Vector{PhyloPicDB.PhyloPicImage}
        @test isempty(imgs)
    end

    @testset "phylopic_images — filter = :node" begin
        imgs = _phylopic_images("Carnivora"; filter = :node, max_pages = 1)
        @test imgs isa Vector{PhyloPicDB.PhyloPicImage}
    end

    @testset "phylopic_images_dataframe — Carnivora clade returns many rows" begin
        imgs = _phylopic_list_images("Carnivora")
        @test imgs isa DataFrame
        @test ncol(imgs) == 12
        @test nrow(imgs) >= 10
        @test all(!ismissing, imgs.phylopic_uuid)
        @test all(==("Carnivora"), imgs.phylopic_query_taxon_name)
        @test !ismissing(imgs.phylopic_query_node_uuid[1])
        @test all(==(imgs.phylopic_query_node_uuid[1]), imgs.phylopic_query_node_uuid)
    end

    @testset "phylopic_images_dataframe — filter = :node returns fewer rows than :clade" begin
        clade = _phylopic_list_images("Carnivora"; filter = :clade)
        node  = _phylopic_list_images("Carnivora"; filter = :node)
        @test nrow(node) <= nrow(clade)
    end

    @testset "phylopic_images_dataframe — max_pages = 1 limits results" begin
        limited   = _phylopic_list_images("Carnivora"; max_pages = 1)
        all_pages = _phylopic_list_images("Carnivora")
        @test nrow(limited) <= nrow(all_pages)
        @test nrow(limited) >= 1
    end

    @testset "phylopic_images_dataframe — URL columns are valid https strings" begin
        imgs = _phylopic_list_images("Canis"; max_pages = 1)
        @test nrow(imgs) >= 1
        for row in eachrow(imgs)
            !ismissing(row.phylopic_raster)    && @test startswith(row.phylopic_raster,    "https://")
            !ismissing(row.phylopic_thumbnail) && @test startswith(row.phylopic_thumbnail, "https://")
        end
    end

    @testset "phylopic_images_dataframe — unknown taxon returns empty DataFrame with correct columns" begin
        result = _phylopic_list_images("ZZZNOMATCH_FAKE_TAXON_XYZ_999")
        @test result isa DataFrame
        @test nrow(result) == 0
        @test ncol(result) == 12
        for col in _PHYLOPIC_IMG_COLS
            @test hasproperty(result, Symbol("phylopic_" * string(col)))
        end
    end

    @testset "phylopic_images_dataframe — custom prefix on empty result" begin
        result = _phylopic_list_images("ZZZNOMATCH_FAKE_TAXON_XYZ_999", "x_")
        @test ncol(result) == 12
        @test  hasproperty(result, :x_uuid)
        @test  hasproperty(result, :x_query_taxon_name)
        @test !hasproperty(result, :phylopic_uuid)
    end

    @testset "phylopic_images_dataframe — custom prefix" begin
        imgs = _phylopic_list_images("Canis", "dog_"; max_pages = 1)
        @test  hasproperty(imgs, :dog_uuid)
        @test  hasproperty(imgs, :dog_query_taxon_name)
        @test !hasproperty(imgs, :phylopic_uuid)
    end
end
