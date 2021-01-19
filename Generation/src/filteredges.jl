using LightGraphs

include("utils.jl")

"""
    filter_vertices_degree_max(vertices, graph, degree)

Return the vertices in `vertices` whose degree is lesser than `degree`.
"""
function filter_vertices_degree_max(vertices, graph, degree)
    return filter(vertex -> degreeislesser(graph, vertex, degree), vertices)
end

"""
    filter_vertices_degree_min(vertices, graph, degree)

Return the vertices in `vertices` whose degree is greater than `degree`.
"""
function filter_vertices_degree_min(vertices, graph, degree)
    return filter(vertex -> degreeisgreater(graph, vertex, degree), vertices)
end

"""
    filter_vertices_degree(vertices, graph, degree)

Return the vertices in `vertices` whose degree is in `degrees`.
"""
function filter_vertices_degree(vertices, graph, degrees)
    return filter(vertex -> degreeis(graph, vertex, degrees), vertices)
end

"""
    filter_vertices_size_biggest_clique_max(vertices, cliques, size)

Return the vertices in `vertices` whose biggest clique size in `cliques` is lesser than `size`.
"""
function filter_vertices_size_biggest_clique_max(vertices, cliques, size)
    valid_vertices = []
    for vertex in vertices
        filter_cliques = filter(clique -> vertex in clique, cliques)
        if getmaxsize(filter_cliques) <= size
            push!(valid_vertices, vertex)
        end
    end
    return valid_vertices
end

"""
    filter_vertices_size_biggest_clique_min(vertices, cliques, size)

Return the vertices in `vertices` whose biggest clique size in `cliques` is greater than `size`.
"""
function filter_vertices_size_biggest_clique_min(vertices, cliques, size)
    valid_vertices = []
    for vertex in vertices
        filter_cliques = filter(clique -> vertex in clique, cliques)
        if getmaxsize(filter_cliques) >= size
            push!(valid_vertices, vertex)
        end
    end
    return valid_vertices
end

"""
    filter_vertices_size_biggest_clique(vertices, cliques, size)

Return the vertices in `vertices` whose biggest clique size in `cliques` is `sizes`.
"""
function filter_vertices_size_biggest_clique(vertices, cliques, sizes)
    valid_vertices = []
    for vertex in vertices
        filter_cliques = filter(clique -> vertex in clique, cliques)
        if getmaxsize(filter_cliques) in sizes
            push!(valid_vertices, vertex)
        end
    end
    return valid_vertices
end


"""
    filter_vertices_size_smallest_clique_max(vertices, cliques, size)

Return the vertices in `vertices` whose smallest clique size in `cliques` is lesser than `size`.
"""
function filter_vertices_size_smallest_clique_max(vertices, cliques, size)
    valid_vertices = []
    for vertex in vertices
        filter_cliques = filter(clique -> vertex in clique, cliques)
        if getminsize(filter_cliques) <= size
            push!(valid_vertices, vertex)
        end
    end
    return valid_vertices
end

"""
    filter_vertices_size_smallest_clique_max(vertices, cliques, size)

Return the vertices in `vertices` whose smallest clique size in `cliques` is greater than `size`.
"""
function filter_vertices_size_smallest_clique_min(vertices, cliques, size)
    valid_vertices = []
    for vertex in vertices
        filter_cliques = filter(clique -> vertex in clique, cliques)
        if getminsize(filter_cliques) >= size
            push!(valid_vertices, vertex)
        end
    end
    return valid_vertices
end

"""
    filter_vertices_size_smallest_clique_max(vertices, cliques, size)

Return the vertices in `vertices` whose smallest clique size in `cliques` is in `sizes`.
"""
function filter_vertices_size_smallest_clique(vertices, cliques, sizes)
    valid_vertices = []
    for vertex in vertices
        filter_cliques = filter(clique -> vertex in clique, cliques)
        if getminsize(filter_cliques) in sizes
            push!(valid_vertices, vertex)
        end
    end
    return valid_vertices
end

"""
    filter_vertices_distance_max(vertices, src, graph, dist)

Return the vertices in `vertices` whose distance to `src` is lesser than `dist`.
"""
function filter_vertices_distance_max(vertices, src, graph, dist)
    distances = dijkstra_shortest_paths(graph, src).dists
    return filter(vertex -> distances[vertex] <= dist, vertices)
end

"""
    filter_vertices_distance_min(vertices, src, graph, dist)

Return the vertices in `vertices` whose distance to `src` is greater than `dist`.
"""
function filter_vertices_distance_min(vertices, src, graph, dist)
    distances = dijkstra_shortest_paths(graph, src).dists
    return filter(vertex -> distances[vertex] >= dist, vertices)
end

"""
    filter_vertices_distance_min(vertices, src, graph, dist)

Return the vertices in `vertices` whose distance to `src` is in `dists`.
"""
function filter_vertices_distance(vertices, src, graph, dists)
    distances = dijkstra_shortest_paths(graph, src).dists
    return filter(vertex -> distances[vertex] in dists, vertices)
end

"""
    filter_vertices_same_clique(vertices, src, cliques)

Return the vertices in `vertices` that share a similar clique to `src`.
"""
function filter_vertices_same_clique(vertices, src, cliques)
    return filter(vertex -> !isempty(getsubset(cliques, [src, vertex])), vertices)
end


"""
    filter_vertices_no_same_clique(vertices, src, cliques)

Return the vertices in `vertices` that don't share a similar clique to `src`.
"""
function filter_vertices_no_same_clique(vertices, src, cliques)
    return filter(vertex -> isempty(getsubset(cliques, [src, vertex])), vertices)
end


"""
    filter_vertices_no_edge(vertices, src, graph)

Return the vertices in `vertices` that don't share an edge with `src`.
"""
function filter_vertices_no_edge(vertices, src, graph)
    return filter(vertex -> !has_edge(graph, src, vertex), vertices)
end

"""
    filter_vertices_has_edge(vertices, src, graph)

Return the vertices in `vertices` that share an edge with `src`.
"""
function filter_vertices_has_edge(vertices, src, graph)
    return filter(vertex -> has_edge(graph, src, vertex), vertices)
end
