# test/test_build.jl — tests for _build.jl
#
# Offline: ensure_build with explicit Int; BUILD_TTL constant.
# Live:    fetch_current_build round-trip; caching; ensure_build(nothing).

@testset "Build management" begin

    # -----------------------------------------------------------------------
    # Offline tests
    # -----------------------------------------------------------------------
    @testset "BUILD_TTL constant" begin
        @test PhyloPicDB.BUILD_TTL isa Float64
        @test PhyloPicDB.BUILD_TTL > 0.0
    end

    @testset "ensure_build — explicit Int passthrough (no network call)" begin
        @test PhyloPicDB.ensure_build(1)   == 1
        @test PhyloPicDB.ensure_build(537) == 537
        @test PhyloPicDB.ensure_build(0)   == 0
    end

    # -----------------------------------------------------------------------
    # Live tests
    # -----------------------------------------------------------------------
    if LIVE
        @testset "fetch_current_build — returns positive Int" begin
            b = PhyloPicDB.fetch_current_build()
            @test b isa Int
            @test b > 0
        end

        @testset "fetch_current_build — second call returns cached value" begin
            b1 = PhyloPicDB.fetch_current_build()
            b2 = PhyloPicDB.fetch_current_build()
            @test b1 == b2
        end

        @testset "fetch_current_build — force re-fetches" begin
            b1 = PhyloPicDB.fetch_current_build()
            b2 = PhyloPicDB.fetch_current_build(; force = true)
            # Build index is stable within a session; equality is expected.
            @test b1 == b2
        end

        @testset "ensure_build — nothing triggers fetch" begin
            b = PhyloPicDB.ensure_build(nothing)
            @test b isa Int
            @test b > 0
        end

        @testset "ensure_build — explicit Int beats cached value" begin
            # Regardless of what the API returns, passing an Int returns it.
            b_explicit = 9999
            @test PhyloPicDB.ensure_build(b_explicit) == b_explicit
        end
    end
end
