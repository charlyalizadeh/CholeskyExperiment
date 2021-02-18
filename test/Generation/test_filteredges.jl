using LightGraphs
using Test

include("../../src/utils/filters.jl")
include("../../src/utils/maximalcliques.jl")
include("../../src/Generate/filteredges.jl")

@testset "filteredges" begin
    @testset "degree" begin
        graph = path_graph(10)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 3, 8)
        add_edge!(graph, 4, 8)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 6, 9)
        v = vertices(graph)
        @test filter_vertices_degree_max(vertices=v, graph=graph, degree=2) == [1, 2, 10]
        @test filter_vertices_degree_max(vertices=v, graph=graph, degree=0) == []
        @test filter_vertices_degree_min(vertices=v, graph=graph, degree=3) == [3, 4, 5, 6, 7, 8, 9]
        @test filter_vertices_degree_min(vertices=v, graph=graph, degree=5) == []
        @test filter_vertices_degree(vertices=v, graph=graph, degrees=[3]) == [3, 5, 6, 7, 9]
        @test filter_vertices_degree(vertices=v, graph=graph, degrees=[2, 3]) == [1, 2, 3, 5, 6, 7, 9]
        @test filter_vertices_degree(vertices=v, graph=graph, degrees=[0, 3]) == [3, 5, 6, 7, 9]
        @test filter_vertices_degree(vertices=v, graph=graph, degrees=[0]) == []
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
        @test filter_vertices_size_biggest_clique_max(vertices=v, cliques=cliques, size=3) == 1:11
        @test filter_vertices_size_biggest_clique_max(vertices=v, cliques=cliques, size=2) == [11]
        @test filter_vertices_size_biggest_clique_max(vertices=v, cliques=cliques, size=1) == []
        @test filter_vertices_size_biggest_clique_min(vertices=v, cliques=cliques, size=2) == 1:11
        @test filter_vertices_size_biggest_clique_min(vertices=v, cliques=cliques, size=3) == 1:10
        @test filter_vertices_size_biggest_clique_min(vertices=v, cliques=cliques, size=4) == []
        @test filter_vertices_size_biggest_clique(vertices=v, cliques=cliques, sizes=[2]) == [11]
        @test filter_vertices_size_biggest_clique(vertices=v, cliques=cliques, sizes=[3]) == 1:10
        @test filter_vertices_size_biggest_clique(vertices=v, cliques=cliques, sizes=[4]) == []
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
        @test filter_vertices_size_smallest_clique_max(vertices=v, cliques=cliques, size=3) == 1:11
        @test filter_vertices_size_smallest_clique_max(vertices=v, cliques=cliques, size=2) == [10, 11]
        @test filter_vertices_size_smallest_clique_max(vertices=v, cliques=cliques, size=1) == []
        @test filter_vertices_size_smallest_clique_min(vertices=v, cliques=cliques, size=2) == 1:11
        @test filter_vertices_size_smallest_clique_min(vertices=v, cliques=cliques, size=3) == 1:9
        @test filter_vertices_size_smallest_clique_min(vertices=v, cliques=cliques, size=4) == []
        @test filter_vertices_size_smallest_clique(vertices=v, cliques=cliques, sizes=[2]) == [10, 11]
        @test filter_vertices_size_smallest_clique(vertices=v, cliques=cliques, sizes=[3]) == 1:9
        @test filter_vertices_size_smallest_clique(vertices=v, cliques=cliques, sizes=[4]) == []
    end
    @testset "distance" begin
        graph = path_graph(10)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 3, 8)
        add_edge!(graph, 4, 8)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 6, 9)
        v = vertices(graph)
        @test filter_vertices_distance_max(vertices=v, src=1, graph=graph, dist=4) == 1:10
        @test filter_vertices_distance_max(vertices=v, src=1, graph=graph, dist=1) == [1, 2, 4]
        @test filter_vertices_distance_max(vertices=v, src=1, graph=graph, dist=-1) == []
        @test filter_vertices_distance_min(vertices=v, src=1, graph=graph, dist=1) == 2:10
        @test filter_vertices_distance_min(vertices=v, src=1, graph=graph, dist=3) == [6, 7, 9, 10]
        @test filter_vertices_distance_min(vertices=v, src=1, graph=graph, dist=6) == []
        @test filter_vertices_distance(vertices=v, src=1, graph=graph, dists=[3]) == [6, 7, 9]
        @test filter_vertices_distance(vertices=v, src=1, graph=graph, dists=[4]) == [10]
        @test filter_vertices_distance(vertices=v, src=1, graph=graph, dists=[5]) == []
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
        @test filter_vertices_same_clique(vertices=v, src=1, cliques=cliques) == [1, 2, 3, 9, 10]
        @test filter_vertices_same_clique(vertices=v, src=11, cliques=cliques) == [10, 11]
        @test filter_vertices_same_clique(vertices=v, src=12, cliques=cliques) == []
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
        @test filter_vertices_no_edge(vertices=v, src=1, choleskygraph=graph) == [1, 3, 5, 6, 7, 8, 9, 10, 11]
        @test filter_vertices_no_edge(vertices=v, src=11, choleskygraph=graph) == 1:11
        @test filter_vertices_has_edge(vertices=v, src=1, choleskygraph=graph) == [2, 4]
        @test filter_vertices_has_edge(vertices=v, src=11, choleskygraph=graph) == []
    end
end
