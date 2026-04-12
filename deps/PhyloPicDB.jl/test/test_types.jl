# test/test_types.jl — offline tests for _types.jl
#
# Tests cover:
#   _cc_license_label, _parse_img_width, _largest_file_href
#   _null_image, _parse_node_json, _parse_image_json
#
# No network access required.

@testset "Types and pure utilities" begin

    # -----------------------------------------------------------------------
    # _cc_license_label
    # -----------------------------------------------------------------------
    @testset "_cc_license_label" begin
        @test PhyloPicDB._cc_license_label(
            "https://creativecommons.org/licenses/by/4.0/"
        ) == "CC BY 4.0"

        @test PhyloPicDB._cc_license_label(
            "https://creativecommons.org/licenses/by-nc/4.0/"
        ) == "CC BY NC 4.0"

        @test PhyloPicDB._cc_license_label(
            "https://creativecommons.org/licenses/by-nc-sa/3.0/"
        ) == "CC BY NC SA 3.0"

        @test PhyloPicDB._cc_license_label(
            "https://creativecommons.org/publicdomain/zero/1.0/"
        ) == "CC0 1.0"

        # Unrecognised URL returned unchanged
        url = "https://example.com/other-license"
        @test PhyloPicDB._cc_license_label(url) == url
    end

    # -----------------------------------------------------------------------
    # _parse_img_width
    # -----------------------------------------------------------------------
    @testset "_parse_img_width" begin
        @test PhyloPicDB._parse_img_width("256x192") == 256
        @test PhyloPicDB._parse_img_width("64x64")   == 64
        @test PhyloPicDB._parse_img_width("1x1")     == 1
        @test PhyloPicDB._parse_img_width("0x0")     == 0
        @test PhyloPicDB._parse_img_width("bad")     == 0
        @test PhyloPicDB._parse_img_width("")        == 0
    end

    # -----------------------------------------------------------------------
    # _largest_file_href
    # -----------------------------------------------------------------------
    @testset "_largest_file_href" begin
        # Empty array → missing
        @test ismissing(PhyloPicDB._largest_file_href([]))

        # Single entry
        files1 = [(href = "/img/64.png", sizes = "64x64")]
        @test PhyloPicDB._largest_file_href(files1) == "/img/64.png"

        # Multiple entries — picks largest width
        files2 = [
            (href = "/img/32.png",  sizes = "32x32"),
            (href = "/img/128.png", sizes = "128x128"),
            (href = "/img/64.png",  sizes = "64x64"),
        ]
        @test PhyloPicDB._largest_file_href(files2) == "/img/128.png"

        # Entry without :href field → missing
        files3 = [(sizes = "64x64",)]
        @test ismissing(PhyloPicDB._largest_file_href(files3))
    end

    # -----------------------------------------------------------------------
    # _null_image
    # -----------------------------------------------------------------------
    @testset "_null_image" begin
        img = PhyloPicDB._null_image(537)
        @test img isa PhyloPicDB.PhyloPicImage
        @test img.uuid  == ""
        @test img.build == 537
        @test ismissing(img.thumbnail_url)
        @test ismissing(img.vector_url)
        @test ismissing(img.raster_url)
        @test ismissing(img.source_file_url)
        @test ismissing(img.og_image_url)
        @test ismissing(img.license_url)
        @test ismissing(img.license)
        @test ismissing(img.contributor_href)
        @test ismissing(img.attribution)
        @test isnothing(img.specific_node_uuid)
        @test isnothing(img.general_node_uuid)
    end

    # -----------------------------------------------------------------------
    # _parse_node_json
    # -----------------------------------------------------------------------
    @testset "_parse_node_json — full fields" begin
        mock = (
            uuid   = "abc-def-123",
            names  = [
                [(class = "scientific", text = "Tyrannosaurus rex")],
            ],
            _links = (
                self         = (title = "Tyrannosaurus rex", href = "/nodes/abc-def-123"),
                parentNode   = (href = "/nodes/parent-uuid-456?build=537",),
                primaryImage = (href = "/images/img-uuid-789?build=537",),
                cladeImages  = (href = "/images?filter_clade=abc-def-123",),
                images       = (href = "/images?filter_node=abc-def-123",),
            ),
        )

        node = PhyloPicDB._parse_node_json(mock, 537)

        @test node isa PhyloPicDB.PhyloPicNode
        @test node.uuid              == "abc-def-123"
        @test node.preferred_name   == "Tyrannosaurus rex"
        @test "Tyrannosaurus rex" in node.all_names
        @test node.build             == 537
        @test node.parent_node_uuid  == "parent-uuid-456"
        @test node.primary_image_uuid == "img-uuid-789"
        @test node.clade_images_href == "/images?filter_clade=abc-def-123"
        @test node.images_href       == "/images?filter_node=abc-def-123"
    end

    @testset "_parse_node_json — root node (no parent, no primary image)" begin
        mock = (
            uuid   = "root-uuid",
            names  = [],
            _links = (
                self         = (title = "Root", href = "/nodes/root-uuid"),
                parentNode   = nothing,
                primaryImage = nothing,
                cladeImages  = (href = "/images?filter_clade=root-uuid",),
                images       = (href = "/images?filter_node=root-uuid",),
            ),
        )

        node = PhyloPicDB._parse_node_json(mock, 1)
        @test isnothing(node.parent_node_uuid)
        @test isnothing(node.primary_image_uuid)
    end

    @testset "_parse_node_json — multiple names, preferred is first scientific" begin
        mock = (
            uuid   = "multi-uuid",
            names  = [
                [(class = "scientific", text = "First Taxon")],
                [(class = "scientific", text = "Second Taxon")],
            ],
            _links = (
                self         = (title = "Multi", href = "/nodes/multi-uuid"),
                parentNode   = nothing,
                primaryImage = nothing,
                cladeImages  = (href = "/images?filter_clade=multi-uuid",),
                images       = (href = "/images?filter_node=multi-uuid",),
            ),
        )

        node = PhyloPicDB._parse_node_json(mock, 10)
        @test node.preferred_name == "First Taxon"
        @test length(node.all_names) == 2
    end

    # -----------------------------------------------------------------------
    # _parse_image_json
    # -----------------------------------------------------------------------
    @testset "_parse_image_json — full fields" begin
        mock = (
            uuid        = "img-uuid-123",
            attribution = "J. Doe",
            _links      = (
                thumbnailFiles = [
                    (href = "/img/64.png",  sizes = "64x64"),
                    (href = "/img/128.png", sizes = "128x128"),
                ],
                vectorFile   = (href = "/img/vec.svg",),
                rasterFiles  = [(href = "/img/raster.png", sizes = "512x512")],
                sourceFile   = (href = "/img/source.svg",),
                license      = (href = "https://creativecommons.org/licenses/by/4.0/",),
                contributor  = (href = "/contributors/jdoe",),
                specificNode = (href = "/nodes/specific-uuid?build=537",),
                generalNode  = (href = "/nodes/general-uuid?build=537",),
            ),
        )

        img = PhyloPicDB._parse_image_json(mock, 537)

        @test img isa PhyloPicDB.PhyloPicImage
        @test img.uuid             == "img-uuid-123"
        @test img.build            == 537
        @test img.thumbnail_url    == "/img/128.png"   # largest: 128 > 64
        @test img.vector_url       == "/img/vec.svg"
        @test img.raster_url       == "/img/raster.png"
        @test img.source_file_url  == "/img/source.svg"
        @test img.license_url      == "https://creativecommons.org/licenses/by/4.0/"
        @test img.license          == "CC BY 4.0"
        @test img.contributor_href == "/contributors/jdoe"
        @test img.attribution      == "J. Doe"
        @test img.specific_node_uuid == "specific-uuid"
        @test img.general_node_uuid  == "general-uuid"
    end

    @testset "_parse_image_json — CC0 license" begin
        mock = (
            uuid   = "img-cc0",
            _links = (
                thumbnailFiles = [],
                license = (href = "https://creativecommons.org/publicdomain/zero/1.0/",),
            ),
        )
        img = PhyloPicDB._parse_image_json(mock, 1)
        @test img.license == "CC0 1.0"
    end

    @testset "_parse_image_json — absent _links all missing/nothing" begin
        mock = (uuid = "img-minimal", _links = nothing)
        img  = PhyloPicDB._parse_image_json(mock, 42)
        @test img.uuid             == "img-minimal"
        @test img.build            == 42
        @test ismissing(img.thumbnail_url)
        @test ismissing(img.vector_url)
        @test ismissing(img.license)
        @test isnothing(img.specific_node_uuid)
        @test isnothing(img.general_node_uuid)
    end

    @testset "_parse_image_json — no node links (specificNode/generalNode absent)" begin
        mock = (
            uuid   = "img-no-nodes",
            _links = (
                thumbnailFiles = [],
                license = (href = "https://creativecommons.org/licenses/by/4.0/",),
            ),
        )
        img = PhyloPicDB._parse_image_json(mock, 5)
        @test isnothing(img.specific_node_uuid)
        @test isnothing(img.general_node_uuid)
    end
end
