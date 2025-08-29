# test/runtests.jl
using Test
using DataFrames
using PaleobiologyDB
import HTTP

# Helper to access internals without export
const _build_url = PaleobiologyDB._build_url
const _joinvals  = PaleobiologyDB._joinvals

@testset "PaleobiologyDB — pure/internal" begin
    @test PaleobiologyDB.pbdb_version() == "data1.2"

    @testset "_joinvals" begin
        @test _joinvals(["a","b","c"]) == "a,b,c"
        @test _joinvals(["a"]) == "a"
        @test _joinvals(42) == "42"
        @test _joinvals(true) == "true"
        @test _joinvals(false) == "false"
    end

    @testset "_build_url default vocab for text" begin
        url_txt = _build_url("occs/list"; format=:csv, query=Dict{String,Any}("base_name"=>"Canidae"))
        @test occursin("/occs/list.csv?", url_txt)
        @test occursin("vocab=pbdb", url_txt)  # added by default for text formats

        url_csv_with_vocab = _build_url("occs/list"; format=:csv, query=Dict{String,Any}("base_name"=>"Canidae","vocab"=>"pbdb"))
        @test occursin("vocab=pbdb", url_csv_with_vocab)

        url_json = _build_url("occs/single"; format=:json, query=Dict{String,Any}("id"=>1001))
        @test endswith(url_json, ".json?id=1001")  # no default vocab for json
    end
end

# Live tests hit the real API and are disabled by default.
# Enable by running with:  ENV["PBDB_LIVE"]="1"  (e.g., `PBDB_LIVE=1 julia --project -e 'using Pkg; Pkg.test()'`)
const LIVE = get(ENV, "PBDB_LIVE", "") == "1"

@testset "PaleobiologyDB — live" begin
    if !LIVE
        @info "Live tests are disabled. Set ENV[\"PBDB_LIVE\"]=\"1\" to enable."
        return
    end

    @testset "occs/single baseline" begin
        df = PaleobiologyDB.pbdb_occurrence(1001, show=["coords"], format=:csv)
        @test df isa DataFrame
        @test nrow(df) == 1
        # Coordinates columns are present when show=["coords"] and vocab=pbdb (default for text)
        @test all(col -> hasproperty(df, col), (:lat, :lng))
    end

    @testset "occs/list vector args join + limit" begin
        df = PaleobiologyDB.pbdb_occurrences(base_name="Canidae",
                                             show=["coords","classext"],
                                             limit=1,
                                             format=:csv)
        @test df isa DataFrame
        @test 0 ≤ nrow(df) ≤ 1
        # When coords requested, expect lat/lng if a record came back
        if nrow(df) == 1
            @test hasproperty(df, :lat)
            @test hasproperty(df, :lng)
        end
    end

    @testset "taxa/single json records parsing" begin
        df = PaleobiologyDB.pbdb_taxon(name="Canis", show=["attr","app","size"], format=:json)
        @test df isa DataFrame
        @test nrow(df) ≥ 1
        # JSON uses short 3-letter field names by default; but DataFrame columns are from JSON keys.
        # Just assert it's non-empty and has some expected fields in either vocabulary.
        @test any(in.([:nam, :nam_orig, :taxon_name], Ref(names(df))))
    end

    @testset "collections summary requires level" begin
        @test_throws ErrorException PaleobiologyDB.pbdb_collections_geo(nothing; format=:csv)
        # With a valid level, a tiny bbox
        df = PaleobiologyDB.pbdb_collections_geo(2; lngmin=0.0, lngmax=1.0, latmin=0.0, latmax=1.0, format=:csv)
        @test df isa DataFrame
    end

    @testset "readtimeout integer handling" begin
        # This will run the request with an integer timeout; just ensure it doesn't throw due to type
        df = PaleobiologyDB.pbdb_occurrences(base_name="Canidae", limit=0, format=:csv)
        @test df isa DataFrame
    end
end
