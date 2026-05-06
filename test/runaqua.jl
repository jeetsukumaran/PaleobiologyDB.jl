using Test
using Aqua
using PaleobiologyDB


@testset "Aqua.jl" begin
    Aqua.test_all(
        PaleobiologyDB;
        # PhyloPicMakie is a hard dep used only inside the PBDBMakie extension,
        # so it does not appear in main-package source. Aqua would flag it as stale
        # without this exclusion.
        stale_deps = (ignore = [:PhyloPicMakie],),
        deps_compat = (ignore = [:Test],),
    )
end
