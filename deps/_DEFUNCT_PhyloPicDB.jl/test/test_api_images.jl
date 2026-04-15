# test/test_api_images.jl — tests for _api_images.jl
#
# Offline: pure parser; invalid filter ArgumentError.
# Live:    fetch_image, fetch_images (clade and node filter) round-trips.

# Carnivora node — has both clade images and direct node images.
const _TEST_NODE_UUID_IMAGES = "36c04f2f-b7d2-4891-a4a9-138d79592bf2"

@testset "API — images" begin

    # -----------------------------------------------------------------------
    # Offline: parser used by fetch_image and fetch_images
    # -----------------------------------------------------------------------
    @testset "_parse_image_json — realistic mock" begin
        mock = (
            uuid        = "test-img-uuid-000",
            attribution = "Test Author",
            _links      = (
                thumbnailFiles = [
                    (href = "/t/64.png",  sizes = "64x64"),
                    (href = "/t/256.png", sizes = "256x256"),
                ],
                vectorFile  = (href = "/v/img.svg",),
                rasterFiles = [(href = "/r/512.png", sizes = "512x512")],
                sourceFile  = (href = "/s/source.svg",),
                license     = (
                    href = "https://creativecommons.org/publicdomain/zero/1.0/",
                ),
                contributor  = (href = "/contributors/test-contributor",),
                specificNode = (href = "/nodes/specific-node-uuid?build=200",),
                generalNode  = (href = "/nodes/general-node-uuid?build=200",),
            ),
        )

        img = PhyloPicDB._parse_image_json(mock, 200)

        @test img isa PhyloPicDB.PhyloPicImage
        @test img.uuid            == "test-img-uuid-000"
        @test img.build           == 200
        @test img.thumbnail_url   == "/t/256.png"   # 256 > 64
        @test img.vector_url      == "/v/img.svg"
        @test img.raster_url      == "/r/512.png"
        @test img.source_file_url == "/s/source.svg"
        @test img.license         == "CC0 1.0"
        @test img.attribution     == "Test Author"
        @test img.specific_node_uuid == "specific-node-uuid"
        @test img.general_node_uuid  == "general-node-uuid"
    end

    @testset "fetch_images — invalid filter raises ArgumentError" begin
        # ArgumentError is thrown before any network call.
        @test_throws ArgumentError PhyloPicDB.fetch_images(
            "any-uuid"; build = 1, filter = :invalid_filter,
        )
    end

    @testset "_IMAGES_PER_PAGE constant" begin
        @test PhyloPicDB._IMAGES_PER_PAGE isa Int
        @test PhyloPicDB._IMAGES_PER_PAGE > 0
    end

    # -----------------------------------------------------------------------
    # Live tests
    # -----------------------------------------------------------------------
    if LIVE
        @testset "fetch_images — clade filter returns non-empty vector" begin
            imgs = PhyloPicDB.fetch_images(_TEST_NODE_UUID_IMAGES; max_pages = 1)
            @test imgs isa Vector{PhyloPicDB.PhyloPicImage}
            @test !isempty(imgs)
            @test all(i -> i isa PhyloPicDB.PhyloPicImage, imgs)
            @test all(i -> !isempty(i.uuid), imgs)
        end

        @testset "fetch_images — node filter returns vector (may be empty)" begin
            imgs = PhyloPicDB.fetch_images(
                _TEST_NODE_UUID_IMAGES; filter = :node, max_pages = 1,
            )
            @test imgs isa Vector{PhyloPicDB.PhyloPicImage}
        end

        @testset "fetch_images — max_pages limits result count" begin
            imgs_p1 = PhyloPicDB.fetch_images(
                _TEST_NODE_UUID_IMAGES; max_pages = 1,
            )
            @test length(imgs_p1) <= PhyloPicDB._IMAGES_PER_PAGE
        end

        @testset "fetch_image — single image by UUID" begin
            # Obtain a valid image UUID via the clade list.
            imgs = PhyloPicDB.fetch_images(_TEST_NODE_UUID_IMAGES; max_pages = 1)
            if !isempty(imgs)
                first_uuid = imgs[1].uuid
                img2 = PhyloPicDB.fetch_image(first_uuid)
                @test !isnothing(img2)
                @test img2 isa PhyloPicDB.PhyloPicImage
                @test img2.uuid == first_uuid
            end
        end

        @testset "fetch_image — unknown UUID returns nothing" begin
            bad = "00000000-0000-0000-0000-000000000000"
            @test isnothing(PhyloPicDB.fetch_image(bad; build = 1))
        end
    end
end
