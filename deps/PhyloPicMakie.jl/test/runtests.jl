using PhyloPicMakie
using Test
using Aqua
using JET

@testset "PhyloPicMakie.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(PhyloPicMakie)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(PhyloPicMakie; target_defined_modules = true)
    end
    # Write your tests here.
end
