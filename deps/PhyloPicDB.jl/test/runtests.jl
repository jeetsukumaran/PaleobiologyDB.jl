using PhyloPicDB
using Test
using Aqua
using JET

@testset "PhyloPicDB.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(PhyloPicDB)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(PhyloPicDB; target_defined_modules = true)
    end
    # Write your tests here.
end
