using Test
using PaleobiologyDB

@testset "PBDBMakie submodule" begin
    declared_symbols = (
        :taxonomytreeplot,
        :taxonomytreeplot!,
        :set_rank_axis_ticks!,
        :leaf_positions,
        :augment_leaf_phylopic!,
        :acquire_phylopic,
        :augment_phylopic,
        :augment_phylopic!,
        :augment_phylopic_ranges,
        :augment_phylopic_ranges!,
        :phylopic_images_dataframe,
        :phylopic_node,
        :phylopic_images,
        :pbdb_phylopic_grid,
        :pbdb_phylopic_grid!,
    )

    @testset "Module visibility before Makie" begin
        @test isdefined(PaleobiologyDB, :PBDBMakie)
        @test PaleobiologyDB.PBDBMakie isa Module
    end

    @testset "Declared API visibility before Makie" begin
        @test :PBDBMakie in names(PaleobiologyDB)
        @test all(symbol -> symbol in names(PaleobiologyDB.PBDBMakie), declared_symbols)
        @test :TaxonomyTreePlot ∉ names(PaleobiologyDB.PBDBMakie)
    end

    @testset "Extension remains unloaded before Makie" begin
        @test isnothing(Base.get_extension(PaleobiologyDB, :PBDBMakieExt))
    end

    @testset "Functions throw MethodError before Makie" begin
        @test_throws MethodError PaleobiologyDB.PBDBMakie.taxonomytreeplot()
        @test_throws MethodError PaleobiologyDB.PBDBMakie.augment_leaf_phylopic!()
        @test_throws MethodError PaleobiologyDB.PBDBMakie.acquire_phylopic()
    end
end
