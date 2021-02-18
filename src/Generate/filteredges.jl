"""
    filter_vertices_degree_max(vertices, graph::AbstractGraph, degree::Int)

Return the vertices in `vertices` whose degree is lesser than `degree`.
"""
function filter_vertices_degree_max(;vertices, graph::AbstractGraph, degree::Int)
    return filter(vertex -> degreeislesser(graph, vertex, degree), vertices)
end

"""
    filter_vertices_degree_min(vertices, graph::AbstractGraph, degree::Int)

Return the vertices in `vertices` whose degree is greater than `degree`.
"""
function filter_vertices_degree_min(;vertices, graph::AbstractGraph, degree::Int)
    return filter(vertex -> degreeisgreater(graph, vertex, degree), vertices)
end

"""
    filter_vertices_degree(vertices, graph::AbstractGraph, degrees::AbstractVector{Int})

Return the vertices in `vertices` whose degree is in `degrees`.
"""
function filter_vertices_degree(;vertices, graph::AbstractGraph, degrees::AbstractVector{Int})
    return filter(vertex -> degreeis(graph, vertex, degrees), vertices)
end

"""
    filter_vertices_size_biggest_clique_max(vertices, cliques, size::Int)

Return the vertices in `vertices` whose biggest clique size in `cliques` is lesser than `size`.
"""
function filter_vertices_size_biggest_clique_max(;vertices, cliques, size::Int)
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
    filter_vertices_size_biggest_clique_min(vertices, cliques, size::Int)

Return the vertices in `vertices` whose biggest clique size in `cliques` is greater than `size`.
"""
function filter_vertices_size_biggest_clique_min(;vertices, cliques, size::Int)
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
    filter_vertices_size_biggest_clique(vertices, cliques, sizes::AbstractVector{Int})
    
Return the vertices in `vertices` whose biggest clique size in `cliques` is `sizes`.
"""
function filter_vertices_size_biggest_clique(;vertices, cliques, sizes::AbstractVector{Int})
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
    filter_vertices_size_smallest_clique_max(vertices, cliques, size::Int)

Return the vertices in `vertices` whose smallest clique size in `cliques` is lesser than `size`.
"""
function filter_vertices_size_smallest_clique_max(;vertices, cliques, size::Int)
    valid_vertices = []
    for vertex in vertices
        filter_cliques = filter(clique -> vertex in clique, cliques)
        if getminsize(filter_cliques)<= size
            push!(valid_vertices, vertex)
        end
    end
    return valid_vertices
end

"""
    filter_vertices_size_smallest_clique_min(;vertices, cliques, size::Int)

Return the vertices in `vertices` whose smallest clique size in `cliques` is greater than `size`.
"""
function filter_vertices_size_smallest_clique_min(;vertices, cliques, size::Int)
    valid_vertices = []
    for vertex in vertices
        filter_cliques = filter(clique -> vertex in clique, cliques)
        if getminsize(filter_cliques)>= size
            push!(valid_vertices, vertex)
        end
    end
    return valid_vertices
end

"""
    filter_vertices_size_smallest_clique(;vertices, cliques, sizes::AbstractVector{Int})

Return the vertices in `vertices` whose smallest clique size in `cliques` is in `sizes`.
"""
function filter_vertices_size_smallest_clique(;vertices, cliques, sizes::AbstractVector{Int})
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
    filter_vertices_distance_max(vertices, src::Int, graph::AbstractGraph, dist::Int)

Return the vertices in `vertices` whose distance to `src` is lesser than `dist`.
"""
function filter_vertices_distance_max(;vertices, src::Int, graph::AbstractGraph, dist::Int)
    distances = dijkstra_shortest_paths(graph, src).dists
    return filter(vertex -> distances[vertex] <= dist, vertices)
end

"""
    filter_vertices_distance_min(vertices, src::Int, graph::AbstractGraph, dist::Int)

Return the vertices in `vertices` whose distance to `src` is greater than `dist`.
"""
function filter_vertices_distance_min(;vertices, src::Int, graph::AbstractGraph, dist::Int)
    distances = dijkstra_shortest_paths(graph, src).dists
    return filter(vertex -> distances[vertex] >= dist, vertices)
end

"""
    filter_vertices_distance_min(vertices, src::Int, graph::AbstractGraph, dist::AbstractVector{Int})

Return the vertices in `vertices` whose distance to `src` is in `dists`.
"""
function filter_vertices_distance(;vertices, src::Int, graph::AbstractGraph, dists::AbstractVector{Int})
    distances = dijkstra_shortest_paths(graph, src).dists
    return filter(vertex -> distances[vertex] in dists, vertices)
end

"""
    filter_vertices_same_clique(vertices, src::Int, cliques)

Return the vertices in `vertices` that share a similar clique to `src`.
"""
function filter_vertices_same_clique(;vertices, src::Int, cliques)
    return filter(vertex -> !isempty(getsubset(cliques, [src, vertex])), vertices)
end


"""
    filter_vertices_no_same_clique(vertices, src::Int, cliques)

Return the vertices in `vertices` that don't share a similar clique to `src`.
"""
function filter_vertices_no_same_clique(;vertices, src::Int, cliques)
    return filter(vertex -> isempty(getsubset(cliques, [src, vertex])), vertices)
end


"""
    filter_vertices_no_edge(vertices, src::Int, choleskygraph::AbstractGraph)

Return the vertices in `vertices` that don't share an edge with `src`.
"""
function filter_vertices_no_edge(;vertices, src::Int, choleskygraph::AbstractGraph)
    return filter(vertex -> !has_edge(choleskygraph, src, vertex), vertices)
end

"""
    filter_vertices_has_edge(vertices, src::Int, choleskygraph::AbstractGraph)

Return the vertices in `vertices` that share an edge with `src`.
"""
function filter_vertices_has_edge(;vertices, src::Int, choleskygraph::AbstractGraph)
    return filter(vertex -> has_edge(choleskygraph, src, vertex), vertices)
end
