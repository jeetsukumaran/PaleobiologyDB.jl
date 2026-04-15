# test/test_http.jl — tests for _http.jl
#
# Offline: PHYLOPIC_BASE_URL constant; error propagation on bad URL.
# Live:    successful GET to base URL; 404 raises immediately without retry.

@testset "HTTP primitive" begin

    # -----------------------------------------------------------------------
    # Offline tests
    # -----------------------------------------------------------------------
    @testset "PHYLOPIC_BASE_URL constant" begin
        @test PhyloPicDB.PHYLOPIC_BASE_URL isa String
        @test PhyloPicDB.PHYLOPIC_BASE_URL == "https://api.phylopic.org"
        @test startswith(PhyloPicDB.PHYLOPIC_BASE_URL, "https://")
    end

    @testset "phylopic_get — malformed URL raises" begin
        # An obviously invalid URL should fail with some exception.
        @test_throws Exception PhyloPicDB.phylopic_get("not-a-valid-url")
    end

    # -----------------------------------------------------------------------
    # Live tests
    # -----------------------------------------------------------------------
    if LIVE
        @testset "phylopic_get — base URL returns 200" begin
            resp = PhyloPicDB.phylopic_get(PhyloPicDB.PHYLOPIC_BASE_URL)
            @test resp.status == 200
        end

        @testset "phylopic_get — 404 raises immediately (no retry)" begin
            # A non-existent UUID should yield a 4xx StatusError, which is
            # never retried.  Catch any exception — the important thing is that
            # the call raises rather than silently returning nothing.
            bad_url = "$(PhyloPicDB.PHYLOPIC_BASE_URL)/nodes/00000000-0000-0000-0000-000000000000?build=1"
            @test_throws Exception PhyloPicDB.phylopic_get(bad_url; retries = 1)
        end

        @testset "phylopic_get — retries and readtimeout kwargs accepted" begin
            resp = PhyloPicDB.phylopic_get(
                PhyloPicDB.PHYLOPIC_BASE_URL;
                retries     = 2,
                readtimeout = 15,
            )
            @test resp.status == 200
        end
    end
end
