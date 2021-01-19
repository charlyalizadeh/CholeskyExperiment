using LightGraphs
using Test

include("../src/utils.jl")

@testset "utils" begin
    @testset "graph degree" begin
        graph = path_graph(10)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 3, 8)
        add_edge!(graph, 4, 8)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 6, 9)
        @test degreeisgreater(graph, 4, 4)
        @test !degreeisgreater(graph, 1, 3)
        @test !degreeislesser(graph, 4, 3)
        @test degreeislesser(graph, 1, 3)
        @test degreeis(graph, 1, [2])
        @test degreeis(graph, 1, [1, 2])
        @test !degreeis(graph, 1, [3])
        @test !degreeis(graph, 1, [3, 4])
    end
    @testset "max/min size subarray" begin
        arrays = [[1, 2, 3], [4], [5, 6, 7, 8]]
        @test getmaxsize(arrays) == 4
        @test getminsize(arrays) == 1
        arrays = []
        @test getmaxsize(arrays) == -1
        @test getminsize(arrays) == -1
    end
    @testset "getsubset" begin
        arrays = [[1, 2, 3], [1], [3], [1, 6, 3, 8]]
        @test getsubset(arrays, [1, 3]) == [[1, 2, 3], [1, 6, 3, 8]]
        @test getsubset(arrays, [2, 6]) == []
    end
    @testset "refine/refine_set" begin
        settest = [1, 2, 3, 4]
        @test refine(settest, 1) == [[1], [2, 3, 4]]
        @test refine(settest, 4) == [[4], [1, 2, 3]]
        @test refine(settest, 5) == [settest]
        @test refine(settest, settest) == [settest]
        settest = [[1, 2, 3], [2, 3, 4], [5, 6]]
        @test refineset(settest, 2) == [[2], [1, 3], [2], [3, 4], [5, 6]]
        @test refineset(settest, 7) == settest
    end
    @testset "lbfs/perfect elimination ordering" begin
        graph = path_graph(10)
        add_edge!(graph, 1, 3)
        add_edge!(graph, 1, 9)
        add_edge!(graph, 3, 5)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 7, 9)
        add_edge!(graph, 3, 9)
        add_edge!(graph, 3, 7)
        @test compute_lbfs(graph) == [1, 2, 3, 9, 7, 5, 4, 8, 10, 6]
        @test compute_perfect_elimination_ordering(graph) == [6, 10, 8, 4, 5, 7, 9, 3, 2, 1]
    end
    @testset "isasubset" begin
        sets = [[1, 2, 3], [4, 5, 6]]
        @test isasubset([1, 2], sets)
        @test !isasubset([3, 4], sets)
    end
    @testset "get prior/later/closest neighbors" begin
        graph = path_graph(10)
        add_edge!(graph, 1, 3)
        add_edge!(graph, 1, 9)
        add_edge!(graph, 3, 5)
        add_edge!(graph, 5, 7)
        add_edge!(graph, 7, 9)
        add_edge!(graph, 3, 9)
        add_edge!(graph, 3, 7)
        ordering = [1, 2, 3, 9, 7, 5, 4, 8, 10, 6]
        @test get_prior_neighbors(graph, ordering, 4) == [1, 3]
        @test get_prior_neighbors(graph, ordering, 4, [3]) == [1] # Here ordering[3] = 3 and ordering[1] = 1, the exclude parameter takes ***indexes***.
        @test get_prior_neighbors(graph, ordering, 4, [3, 1]) == []
        @test get_prior_neighbors(graph, ordering, 1) == []
        @test get_later_neighbors(graph, ordering, 4) == [7, 8, 10]
        @test get_later_neighbors(graph, ordering, 4, [5]) == [8, 10]
        @test get_later_neighbors(graph, ordering, 4, [5, 8, 9]) == []
        @test get_later_neighbors(graph, ordering, length(ordering)) == []
        @test get_closest_neighbor(graph, ordering, 1) == nothing
        @test get_closest_neighbor(graph, ordering, 4) == 3
    end
    @testset "is_complete" begin
        graph = path_graph(4)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 1, 3)
        @test !is_complete(graph)
        @test is_complete(graph, 1:3)
        add_edge!(graph, 4, 2)
        @test is_complete(graph)
    end
    @testset "is_maximal_clique" begin
        graph = path_graph(4)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 1, 3)
        @test is_maximal_clique(graph, [1, 2, 3])
        @test !is_maximal_clique(graph, [1, 2, 3], [[1, 2, 3, 4]]) # Not a real scenario on this graph
        @test !is_maximal_clique(graph, [1, 2, 3, 4])
    end
    @testset "get_maximal_clique" begin
        graph = path_graph(4)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 1, 3)
        cliques = get_maximal_cliques(graph)
        @test isasubset([1, 2, 3], cliques)
        @test isasubset([1, 3, 4], cliques)
    end
    @testset "get_cliquetree" begin
        graph = path_graph(4)
        add_edge!(graph, 1, 4)
        add_edge!(graph, 1, 3)
        cliques = get_maximal_cliques(graph)
        cliquetree = get_cliquetree(cliques)
        @test cliquetree[1].src == 1
        @test cliquetree[1].dst == 2
    end
    @testset "is_chordal" begin
        graph = path_graph(4)
        add_edge!(graph, 1, 4)
        @test !is_chordal(graph)
        add_edge!(graph, 1, 3)
        @test is_chordal(graph)
    end
end
