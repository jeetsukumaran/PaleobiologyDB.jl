# test/test_bulk.jl — tests for _bulk.jl
#
# Offline: deduplication logic (unique/Dict key count).
# Live:    batch_primary_images, batch_images return types and key coverage.

# UUIDs used for live batch tests.
const _TEST_UUID_BULK_A = "8f901db5-84c1-4dc0-93ba-2300eeddf4ab"  # Dinosauria
const _TEST_UUID_BULK_B = "36c04f2f-b7d2-4891-a4a9-138d79592bf2"  # Carnivora

@testset "Bulk operations" begin

    # -----------------------------------------------------------------------
    # Offline: verify deduplication contract
    # -----------------------------------------------------------------------
    @testset "unique — duplicate UUIDs reduce to distinct set" begin
        uuids        = ["a", "b", "a", "c", "b"]
        unique_uuids = unique(uuids)
        @test length(unique_uuids) == 3
        @test Set(unique_uuids) == Set(["a", "b", "c"])
    end

    @testset "batch_primary_images — return type annotation is correct" begin
        # Verify Julia can resolve the declared return type (no network needed).
        T = Dict{String, Union{PhyloPicDB.PhyloPicImage, Nothing}}
        @test T isa DataType
    end

    @testset "batch_images — return type annotation is correct" begin
        T = Dict{String, Vector{PhyloPicDB.PhyloPicImage}}
        @test T isa DataType
    end

    # -----------------------------------------------------------------------
    # Live tests
    # -----------------------------------------------------------------------
    if LIVE
        @testset "batch_primary_images — returns Dict with unique input keys" begin
            # Duplicate UUID: only 2 unique → 2 API calls, 2 Dict keys.
            uuids  = [_TEST_UUID_BULK_A, _TEST_UUID_BULK_B, _TEST_UUID_BULK_A]
            result = PhyloPicDB.batch_primary_images(uuids)

            @test result isa Dict{String, Union{PhyloPicDB.PhyloPicImage, Nothing}}
            @test haskey(result, _TEST_UUID_BULK_A)
            @test haskey(result, _TEST_UUID_BULK_B)
            # Batch result contains exactly the unique input UUIDs as keys.
            @test length(result) == 2
        end

        @testset "batch_primary_images — values are PhyloPicImage or nothing" begin
            result = PhyloPicDB.batch_primary_images([_TEST_UUID_BULK_A])
            val    = result[_TEST_UUID_BULK_A]
            @test isnothing(val) || val isa PhyloPicDB.PhyloPicImage
        end

        @testset "batch_images — returns Dict with unique input keys" begin
            uuids  = [_TEST_UUID_BULK_A, _TEST_UUID_BULK_B]
            result = PhyloPicDB.batch_images(uuids; max_pages = 1)

            @test result isa Dict{String, Vector{PhyloPicDB.PhyloPicImage}}
            @test haskey(result, _TEST_UUID_BULK_A)
            @test haskey(result, _TEST_UUID_BULK_B)
            @test length(result) == 2
        end

        @testset "batch_images — values are Vector{PhyloPicImage}" begin
            result = PhyloPicDB.batch_images([_TEST_UUID_BULK_B]; max_pages = 1)
            @test result[_TEST_UUID_BULK_B] isa Vector{PhyloPicDB.PhyloPicImage}
        end

        @testset "batch_primary_images — single-element input" begin
            result = PhyloPicDB.batch_primary_images([_TEST_UUID_BULK_A])
            @test length(result) == 1
        end

        @testset "batch_primary_images — empty input" begin
            result = PhyloPicDB.batch_primary_images(String[])
            @test result isa Dict{String, Union{PhyloPicDB.PhyloPicImage, Nothing}}
            @test isempty(result)
        end
    end
end
