using LightGraphs
using Test

include("../src/filteredges.jl")

@testset "filteredges" begin
    @testset "degree" begin
        graph = path_graph(10)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 3, 8)
        add_edge!(graph, 4, 8)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 6, 9)
        v = vertices(graph)
        @test filter_vertices_degree_max(v, graph, 2) == [1, 2, 10]
        @test filter_vertices_degree_max(v, graph, 0) == []
        @test filter_vertices_degree_min(v, graph, 3) == [3, 4, 5, 6, 7, 8, 9]
        @test filter_vertices_degree_min(v, graph, 5) == []
        @test filter_vertices_degree(v, graph, 3) == [3, 5, 6, 7, 9]
        @test filter_vertices_degree(v, graph, [2, 3]) == [1, 2, 3, 5, 6, 7, 9]
        @test filter_vertices_degree(v, graph, [0, 3]) == [3, 5, 6, 7, 9]
        @test filter_vertices_degree(v, graph, 0) == []
    end
    @testset "biggest clique" begin
        graph = path_graph(11)
        add_edge!(graph, 1, 10)
        add_edge!(graph, 1, 3)
        add_edge!(graph, 1, 9)
        add_edge!(graph, 3, 5)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 7, 9)
        add_edge!(graph, 3, 9)
        add_edge!(graph, 3, 7)
        v = vertices(graph)
        cliques = get_maximal_cliques(graph)
        @test filter_vertices_size_biggest_clique_max(v, cliques, 3) == 1:11
        @test filter_vertices_size_biggest_clique_max(v, cliques, 2) == [11]
        @test filter_vertices_size_biggest_clique_max(v, cliques, 1) == []
        @test filter_vertices_size_biggest_clique_min(v, cliques, 2) == 1:11
        @test filter_vertices_size_biggest_clique_min(v, cliques, 3) == 1:10
        @test filter_vertices_size_biggest_clique_min(v, cliques, 4) == []
        @test filter_vertices_size_biggest_clique(v, cliques, 2) == [11]
        @test filter_vertices_size_biggest_clique(v, cliques, 3) == 1:10
        @test filter_vertices_size_biggest_clique(v, cliques, 4) == []
    end
    @testset "smallest clique" begin
        graph = path_graph(11)
        add_edge!(graph, 1, 10)
        add_edge!(graph, 1, 3)
        add_edge!(graph, 1, 9)
        add_edge!(graph, 3, 5)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 7, 9)
        add_edge!(graph, 3, 9)
        add_edge!(graph, 3, 7)
        v = vertices(graph)
        cliques = get_maximal_cliques(graph)
        @test filter_vertices_size_smallest_clique_max(v, cliques, 3) == 1:11
        @test filter_vertices_size_smallest_clique_max(v, cliques, 2) == [10, 11]
        @test filter_vertices_size_smallest_clique_max(v, cliques, 1) == []
        @test filter_vertices_size_smallest_clique_min(v, cliques, 2) == 1:11
        @test filter_vertices_size_smallest_clique_min(v, cliques, 3) == 1:9
        @test filter_vertices_size_smallest_clique_min(v, cliques, 4) == []
        @test filter_vertices_size_smallest_clique(v, cliques, 2) == [10, 11]
        @test filter_vertices_size_smallest_clique(v, cliques, 3) == 1:9
        @test filter_vertices_size_smallest_clique(v, cliques, 4) == []
    end
    @testset "distance" begin
        graph = path_graph(10)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 3, 8)
        add_edge!(graph, 4, 8)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 6, 9)
        v = vertices(graph)
        @test filter_vertices_distance_max(v, 1, graph, 4) == 1:10
        @test filter_vertices_distance_max(v, 1, graph, 1) == [1, 2, 4]
        @test filter_vertices_distance_max(v, 1, graph, -1) == []
        @test filter_vertices_distance_min(v, 1, graph, 1) == 2:10
        @test filter_vertices_distance_min(v, 1, graph, 3) == [6, 7, 9, 10]
        @test filter_vertices_distance_min(v, 1, graph, 6) == []
        @test filter_vertices_distance(v, 1, graph, 3) == [6, 7, 9]
        @test filter_vertices_distance(v, 1, graph, 4) == [10]
        @test filter_vertices_distance(v, 1, graph, 5) == []
    end
    @testset "same clique" begin
        graph = path_graph(11)
        add_edge!(graph, 1, 10)
        add_edge!(graph, 1, 3)
        add_edge!(graph, 1, 9)
        add_edge!(graph, 3, 5)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 7, 9)
        add_edge!(graph, 3, 9)
        add_edge!(graph, 3, 7)
        v = vertices(graph)
        cliques = get_maximal_cliques(graph)
        @test filter_vertices_same_clique(v, 1, cliques) == [1, 2, 3, 9, 10]
        @test filter_vertices_same_clique(v, 11, cliques) == [10, 11]
        @test filter_vertices_same_clique(v, 12, cliques) == []
    end
    @testset "has/hasn't edge" begin
        graph = path_graph(10)
        add_vertex!(graph)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 3, 8)
        add_edge!(graph, 4, 8)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 6, 9)
        v = vertices(graph)
        @test filter_vertices_no_edge(v, 1, graph) == [1, 3, 5, 6, 7, 8, 9, 10, 11]
        @test filter_vertices_no_edge(v, 11, graph) == 1:11
        @test filter_vertices_has_edge(v, 1, graph) == [2, 4]
        @test filter_vertices_has_edge(v, 11, graph) == []
    end
end
