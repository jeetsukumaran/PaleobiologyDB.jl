# test/test_image_selector.jl — tests for _image_selector.jl
#
# Offline: select_image dispatch (:first, Int in/out of bounds, callable, unknown symbol).
# Live:    primary_image, clade_images, node_images round-trips.

# Construct a minimal PhyloPicImage fixture for offline dispatch tests.
function _make_test_image(n::Int)::PhyloPicDB.PhyloPicImage
    PhyloPicDB.PhyloPicImage(
        "uuid-$n",                              # uuid
        537,                                    # build
        "https://example.com/t/$n.png",         # thumbnail_url
        missing,                                # vector_url
        missing,                                # raster_url
        missing,                                # source_file_url
        missing,                                # og_image_url
        "https://creativecommons.org/licenses/by/4.0/",  # license_url
        "CC BY 4.0",                            # license
        missing,                                # contributor_href
        missing,                                # attribution
        nothing,                                # specific_node_uuid
        nothing,                                # general_node_uuid
    )
end

# Known stable UUID for live selector tests.
const _TEST_NODE_UUID_SELECTOR = "8f901db5-84c1-4dc0-93ba-2300eeddf4ab"

@testset "Image selector" begin

    imgs       = [_make_test_image(i) for i in 1:5]
    empty_imgs = PhyloPicDB.PhyloPicImage[]

    # -----------------------------------------------------------------------
    # select_image — :first
    # -----------------------------------------------------------------------
    @testset "select_image — :first on non-empty vector" begin
        sel = PhyloPicDB.select_image(imgs, :first)
        @test !isnothing(sel)
        @test sel.uuid == "uuid-1"
    end

    @testset "select_image — :first on empty vector returns nothing" begin
        @test isnothing(PhyloPicDB.select_image(empty_imgs, :first))
    end

    # -----------------------------------------------------------------------
    # select_image — Int index
    # -----------------------------------------------------------------------
    @testset "select_image — Int in bounds" begin
        @test PhyloPicDB.select_image(imgs, 1).uuid == "uuid-1"
        @test PhyloPicDB.select_image(imgs, 3).uuid == "uuid-3"
        @test PhyloPicDB.select_image(imgs, 5).uuid == "uuid-5"
    end

    @testset "select_image — Int out of bounds returns nothing" begin
        @test isnothing(PhyloPicDB.select_image(imgs, 0))
        @test isnothing(PhyloPicDB.select_image(imgs, 6))
        @test isnothing(PhyloPicDB.select_image(imgs, -1))
        @test isnothing(PhyloPicDB.select_image(imgs, 999))
    end

    @testset "select_image — Int on empty vector returns nothing" begin
        @test isnothing(PhyloPicDB.select_image(empty_imgs, 1))
    end

    # -----------------------------------------------------------------------
    # select_image — callable
    # -----------------------------------------------------------------------
    @testset "select_image — callable receives full vector" begin
        last_img = PhyloPicDB.select_image(imgs, v -> last(v))
        @test last_img.uuid == "uuid-5"
    end

    @testset "select_image — callable returning nothing is valid" begin
        result = PhyloPicDB.select_image(
            empty_imgs, v -> isempty(v) ? nothing : v[1],
        )
        @test isnothing(result)
    end

    # -----------------------------------------------------------------------
    # select_image — unknown Symbol
    # -----------------------------------------------------------------------
    @testset "select_image — unknown Symbol throws ArgumentError" begin
        @test_throws ArgumentError PhyloPicDB.select_image(imgs, :unknown_selector)
        @test_throws ArgumentError PhyloPicDB.select_image(imgs, :second)
    end

    # -----------------------------------------------------------------------
    # Live tests
    # -----------------------------------------------------------------------
    if LIVE
        @testset "primary_image — returns PhyloPicImage or nothing" begin
            img = PhyloPicDB.primary_image(_TEST_NODE_UUID_SELECTOR)
            @test isnothing(img) || img isa PhyloPicDB.PhyloPicImage
        end

        @testset "clade_images — returns Vector{PhyloPicImage}" begin
            imgs_live = PhyloPicDB.clade_images(
                _TEST_NODE_UUID_SELECTOR; max_pages = 1,
            )
            @test imgs_live isa Vector{PhyloPicDB.PhyloPicImage}
        end

        @testset "node_images — returns Vector{PhyloPicImage}" begin
            imgs_live = PhyloPicDB.node_images(
                _TEST_NODE_UUID_SELECTOR; max_pages = 1,
            )
            @test imgs_live isa Vector{PhyloPicDB.PhyloPicImage}
        end

        @testset "select_image after clade_images — :first" begin
            imgs_live = PhyloPicDB.clade_images(
                _TEST_NODE_UUID_SELECTOR; max_pages = 1,
            )
            sel = PhyloPicDB.select_image(imgs_live, :first)
            @test isnothing(sel) || sel isa PhyloPicDB.PhyloPicImage
        end
    end
end
