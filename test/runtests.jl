using GeoExplorer
using Test

@testset "GeoExplorer.jl" begin
    @testset "Exports" begin
        @test isdefined(GeoExplorer, :GeoExplorerApp)
        @test isdefined(GeoExplorer, :explore)
        @test isdefined(GeoExplorer, :goto!)
        @test isdefined(GeoExplorer, :zoom!)
        @test isdefined(GeoExplorer, :reset_view!)
        @test isdefined(GeoExplorer, :set_center!)
        @test isdefined(GeoExplorer, :available_providers)
    end

    @testset "available_providers" begin
        providers = available_providers()
        @test length(providers) > 0
        @test all(p -> p isa Pair, providers)
    end

    @testset "Reexports" begin
        # Tyler
        @test isdefined(GeoExplorer, :Tyler)

        # GLMakie
        @test isdefined(GeoExplorer, :Figure)
        @test isdefined(GeoExplorer, :Axis)

        # GeoInterface
        @test isdefined(GeoExplorer, :GeoInterface)

        # Extents
        @test isdefined(GeoExplorer, :Extent)
    end
end
