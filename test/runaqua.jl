
using Test
using Aqua
using PaleobiologyDB

Aqua.test_all(PaleobiologyDB)

# @testset "Aqua.jl" begin
#   Aqua.test_all(
#     YourPackage;
#     ambiguities=(exclude=[SomePackage.some_function], broken=true),
#     stale_deps=(ignore=[:SomePackage],),
#     deps_compat=(ignore=[:SomeOtherPackage],),
#     piracies=false,
#   )
# end
