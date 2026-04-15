# test/test_api_nodes.jl — tests for _api_nodes.jl
#
# Offline: pure parser with realistic mock data.
# Live:    fetch_node, fetch_node_with_primary_image round-trips.

# Known stable Dinosauria node UUID used across live tests.
const _TEST_NODE_UUID_NODES = "8f901db5-84c1-4dc0-93ba-2300eeddf4ab"

@testset "API — nodes" begin

    # -----------------------------------------------------------------------
    # Offline: parser used by fetch_node
    # -----------------------------------------------------------------------
    @testset "_parse_node_json — realistic mock" begin
        mock = (
            uuid   = _TEST_NODE_UUID_NODES,
            names  = [
                [(class = "scientific", text = "Dinosauria")],
            ],
            _links = (
                self         = (title = "Dinosauria",
                                href  = "/nodes/$(_TEST_NODE_UUID_NODES)"),
                parentNode   = (href = "/nodes/parent-00?build=537",),
                primaryImage = nothing,
                cladeImages  = (href = "/images?filter_clade=$(_TEST_NODE_UUID_NODES)",),
                images       = (href = "/images?filter_node=$(_TEST_NODE_UUID_NODES)",),
            ),
        )

        node = PhyloPicDB._parse_node_json(mock, 537)

        @test node isa PhyloPicDB.PhyloPicNode
        @test node.uuid           == _TEST_NODE_UUID_NODES
        @test node.preferred_name == "Dinosauria"
        @test node.build          == 537
        @test node.parent_node_uuid    == "parent-00"
        @test isnothing(node.primary_image_uuid)
        @test !isempty(node.clade_images_href)
        @test !isempty(node.images_href)
    end

    # -----------------------------------------------------------------------
    # Live tests
    # -----------------------------------------------------------------------
    if LIVE
        @testset "fetch_node — known UUID returns PhyloPicNode" begin
            node = PhyloPicDB.fetch_node(_TEST_NODE_UUID_NODES)
            @test !isnothing(node)
            @test node isa PhyloPicDB.PhyloPicNode
            @test node.uuid == _TEST_NODE_UUID_NODES
            @test !isempty(node.preferred_name)
            @test node.build > 0
        end

        @testset "fetch_node — unknown UUID returns nothing" begin
            bad = "00000000-0000-0000-0000-000000000000"
            result = PhyloPicDB.fetch_node(bad; build = 1)
            @test isnothing(result)
        end

        @testset "fetch_node — explicit build accepted" begin
            b    = PhyloPicDB.fetch_current_build()
            node = PhyloPicDB.fetch_node(_TEST_NODE_UUID_NODES; build = b)
            @test !isnothing(node)
            @test node.build == b
        end

        @testset "fetch_node_with_primary_image — returns (node, img) tuple" begin
            node, img = PhyloPicDB.fetch_node_with_primary_image(_TEST_NODE_UUID_NODES)
            @test !isnothing(node)
            @test node.uuid == _TEST_NODE_UUID_NODES
            # Primary image presence is not guaranteed; check types only.
            @test isnothing(img) || img isa PhyloPicDB.PhyloPicImage
        end

        @testset "fetch_node_with_primary_image — unknown UUID returns (nothing, nothing)" begin
            bad = "00000000-0000-0000-0000-000000000000"
            node, img = PhyloPicDB.fetch_node_with_primary_image(bad; build = 1)
            @test isnothing(node)
            @test isnothing(img)
        end
    end
end
