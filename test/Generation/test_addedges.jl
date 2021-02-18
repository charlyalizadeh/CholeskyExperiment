using Test
using LightGraphs

include("../../src/Generate/filteredges.jl")
include("../../src/Generate/addedges.jl")

@testset "addedges" begin
    @testset "check_options" begin
        options = Dict(:degree_max => Dict("degree" => 3),
                       :degree_min => Dict("degree" => 4))
        @test_throws ErrorException(":degree_max cannot be strictly inferior to :degree_min") check_options_src(options)
        options = Dict(:size_biggest_clique_max => Dict("size" => 3),
                       :size_biggest_clique_min => Dict("size" => 4))
        @test_throws ErrorException(":size_biggest_clique_max cannot be strictly inferior to :size_biggest_clique_min") check_options_src(options)
        options = Dict(:size_smallest_clique_max => Dict("size" => 3),
                       :size_smallest_clique_min => Dict("size" => 4))
        @test_throws ErrorException(":size_smallest_clique_max cannot be strictly inferior to :size_smallest_clique_min") check_options_src(options)

        options = Dict(:distance_max => Dict("dist" => 3),
                       :distance_min => Dict("dist" => 4))
        @test_throws ErrorException(":distance_max cannot be strictly inferior to :distance_min") check_options_dst(options)
        options = Dict(:same_clique => nothing,
                       :no_same_clique => nothing)
        @test_throws ErrorException(":same_clique and :no_same_clique cannot be set together") check_options_dst(options)
        options = Dict(:has_edge => nothing,
                       :no_edge => nothing)
        @test_throws ErrorException(":has_edge and :no_edge cannot be set together") check_options_dst(options)
    end
end
