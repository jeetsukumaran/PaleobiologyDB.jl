# test/runtests.jl — PhyloPicDB test orchestrator
#
# Offline tests run always (no network required).
# Live tests require ENV["PHYLOPIC_LIVE"]="1".
#
# Usage:
#   julia --project=deps/PhyloPicDB.jl -e 'using Pkg; Pkg.test()'
#   PHYLOPIC_LIVE=1 julia --project=deps/PhyloPicDB.jl -e 'using Pkg; Pkg.test()'

using Test
using PhyloPicDB
using Aqua

const LIVE = get(ENV, "PHYLOPIC_LIVE", "") == "1"

@testset "PhyloPicDB" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(PhyloPicDB; ambiguities = false)
    end

    include("test_types.jl")
    include("test_build.jl")
    include("test_http.jl")
    include("test_api_nodes.jl")
    include("test_api_images.jl")
    include("test_image_selector.jl")
    include("test_bulk.jl")
end
