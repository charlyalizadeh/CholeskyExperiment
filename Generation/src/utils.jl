using LightGraphs

"""
    degreeisgreater(graph::AbstractGraph, vertex, deg)

Check if the degree of `vertex` is greater than `deg`.
"""
function degreeisgreater(graph::AbstractGraph, vertex, deg)
    return degree(graph)[vertex] >= deg
end

"""
    degreeislesser(graph::AbstractGraph, vertex, deg)

Check if the degree of `vertex` is lesser than `deg`.
"""
function degreeislesser(graph::AbstractGraph, vertex, deg)
    return degree(graph)[vertex] <= deg
end

"""
    degreeis(graph::AbstractGraph, vertex, degrees)

Check if the degree of `vertex` is contained in `degrees`.
"""
function degreeis(graph::AbstractGraph, vertex, degrees)
    return degree(graph)[vertex] in degrees
end

"""
    getmaxsize(arrays) 
    
Return the maximum size of subarrays contained in `arrays`.
"""
function getmaxsize(arrays) 
    try
        return maximum([length(array) for array in arrays])
    catch err
        if isa(err, ArgumentError)
            return -1
        end
    end
end

"""
    getminsize(arrays) 
    
Return the minimum size of subarrays contained in `arrays`.
"""
function getminsize(arrays)  
    try
        return minimum([length(array) for array in arrays])
    catch err
        if isa(err, ArgumentError)
            return -1 
        end
    end
end

"""
    getsubset(arrays, values)

Return the subset of arrays contained in `arrays` wich contains `values`.
"""
function getsubset(arrays, values)
    return filter(array -> issubset(values, array), arrays)
end

"""
    refine(S, X)

Refine the set S into tow set.
"""
function refine(S, X)
    intersection = intersect(S, X)
    difference = setdiff(S, X)
    if isempty(intersection)
        return [difference]
    elseif isempty(difference)
        return [intersection]
    else
        return [intersection, difference]
    end
end

"""
    refineset(S, X)

Refine the set of set `S` with the set `X`.
"""
function refineset(S, X)
    new_S = []
    for set in S
        append!(new_S, refine(set, X))
    end
    return new_S
end

"""
    compute_lbfs(graph::AbstractGraph)

Return a lexicographic ordering of `graph`.
"""
function compute_lbfs(graph::AbstractGraph)
    S = [[vertices(graph)...]]
    visited = []
    ordering = []
    for i in 1:nv(graph)
        current_vertex = S[1][1]
        push!(ordering, current_vertex)
        setdiff!(S[1], current_vertex)
        if isempty(S[1])
            popfirst!(S)
        end
        nghbrs = setdiff(neighbors(graph, current_vertex), ordering)
        S = refineset(S, nghbrs)
    end
    return ordering
end

"""
    compute_perfect_elimination_ordering(graph::AbstractGraph)

Return a perfect elimination ordering of graph.
"""
function compute_perfect_elimination_ordering(graph::AbstractGraph)
    ordering = compute_lbfs(graph)
    return reverse(ordering)
end

"""
    isasubset(set, set_array)

Check if `set` isn't a subset of a the subaray in `sets`.
"""
function isasubset(set, sets)
    for s in sets
        if issubset(set, s)
            return true
        end
    end
    return false
end

"""
    get_prior_neighbors(graph::AbstractGraph, ordering, i, exclude=[])

Return the neighbors of `ordering[i]` in graph with index inferior to i.
"""
function get_prior_neighbors(graph::AbstractGraph, ordering, i, exclude=[])
    prior_neighbors = []
    for j in 1:i-1
        if  !(j in exclude) && (ordering[j] in neighbors(graph, ordering[i]))
            push!(prior_neighbors, ordering[j])
        end
    end
    return prior_neighbors
end

"""
    get_later_neighbors(graph::AbstractGraph, ordering, i, exclude=[])

Return the neighbors of `ordering[i]` in graph with index superior to i.
TODO : join `get_prior_neighbors` and `get_later_neighbors` into one function
"""
function get_later_neighbors(graph::AbstractGraph, ordering, i, exclude=[])
    later_neighbors = []
    for j in i+1:length(ordering)
        if !(j in exclude) && (ordering[j] in neighbors(graph, ordering[i]))
            push!(later_neighbors, ordering[j])
        end
    end
    return later_neighbors
end

"""
    get_closest_neighbor(graph::AbstractGraph, ordering, i)

Return the index of the closest neighbor of the value in `ordering` corresponding to the index `i`.
The return index is inferior to `j`
"""
function get_closest_neighbor(graph::AbstractGraph, ordering, i)
    for j in i-1:-1:1
        if ordering[j] in neighbors(graph, ordering[i])
            return j
        end
    end
    return nothing
end

"""
    is_complete(graph::AbstractGraph, vertices)

Check if the subgraph form by `vertices` is complete.
"""
function is_complete(graph::AbstractGraph, vertices=vertices(graph))
    for i in 1:length(vertices)-1
        for j in i+1:length(vertices)
            if !has_edge(graph, vertices[j], vertices[i])
                return false
            end
        end
    end
    return true
end

"""
    is_maximal_clique(graph::AbstractGraph, clique, clique_list = [])

Check is `clique` is maximal clique in `graph` knowing the already found cliques in `clique_list`.
"""
function is_maximal_clique(graph::AbstractGraph, clique, clique_list = [])
    return is_complete(graph, clique) && !isasubset(clique, clique_list)
end


"""
    get_maximal_cliques(graph::AbstractGraph)

Return the maximal cliques of `graph`. `graph` needs to be chordal.
"""
function get_maximal_cliques(graph::AbstractGraph)
    perfect_ordering = compute_perfect_elimination_ordering(graph)
    cliques = []
    for i in 1:length(perfect_ordering)
        later_neighbors = get_later_neighbors(graph, perfect_ordering, i)
        potential_clique = [later_neighbors;perfect_ordering[i]]
        if is_maximal_clique(graph, potential_clique, cliques)
            push!(cliques, potential_clique)
        end
    end
    return cliques
end

"""
    get_cliquetree(cliques)

Return the clique tree and the distance matrix of the cliques in `cliques`.
"""
function get_cliquetree(cliques)
    graph = SimpleGraph(length(cliques))
    dstmx = zeros(Int,length(cliques), length(cliques))
    for i in 1:length(cliques) - 1
        for j in i+1:length(cliques)
            value = length(intersect(cliques[i], cliques[j]))
            dstmx[i, j] = value
            dstmx[j, i] = value
            if value >= 1
                add_edge!(graph, i, j)
            end
        end
    end
    return kruskal_mst(graph, dstmx; minimize = false)
end


"""
    is_chordal(graph::AbstractGraph)

Return true if `graph` is chordal, false otherwise.
"""
function is_chordal(graph::AbstractGraph)
    if !is_connected(graph)
        return false
    end
    ordering = compute_lbfs(graph)
    for i in 3:length(ordering)
        index_neighbor = get_closest_neighbor(graph, ordering, i)
        if index_neighbor == -1
            continue
        else
            prior_current = get_prior_neighbors(graph, ordering, i, [index_neighbor])
            prior_closest = get_prior_neighbors(graph, ordering, index_neighbor)
            if !issubset(prior_current, prior_closest)
                return false
            end
        end
    end
    return true
end
