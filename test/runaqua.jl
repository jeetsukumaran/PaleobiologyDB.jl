
# using Test
using Aqua
using PaleobiologyDB


@testset "Aqua.jl" begin
    Aqua.test_all(PaleobiologyDB)
#   Aqua.test_all(
#     PaleobiologyDB;
#     # ambiguities=(exclude=[SomePackage.some_function], broken=true),
#     # stale_deps=(ignore=[:SomePackage],),
#     deps_compat=(ignore=[:Test],),
#     # piracies=false,
#   )
end
