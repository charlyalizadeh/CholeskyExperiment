const src_options = Dict(
    :degree_max => filter_vertices_degree_max,
    :degree_min => filter_vertices_degree_min,
    :degree => filter_vertices_degree,
    :size_biggest_clique_max => filter_vertices_size_biggest_clique_max,
    :size_biggest_clique_min => filter_vertices_size_biggest_clique_min,
    :size_biggest_clique => filter_vertices_size_biggest_clique,
    :size_smallest_clique_max => filter_vertices_size_smallest_clique_max,
    :size_smallest_clique_min => filter_vertices_size_smallest_clique_min,
    :size_smallest_clique => filter_vertices_size_smallest_clique,
)

const dst_options = Dict(
    :degree_max => filter_vertices_degree_max,
    :degree_min => filter_vertices_degree_min,
    :degree => filter_vertices_degree,
    :size_biggest_clique_max => filter_vertices_size_biggest_clique_max,
    :size_biggest_clique_min => filter_vertices_size_biggest_clique_min,
    :size_biggest_clique => filter_vertices_size_biggest_clique,
    :size_smallest_clique_max => filter_vertices_size_smallest_clique_max,
    :size_smallest_clique_min => filter_vertices_size_smallest_clique_min,
    :size_smallest_clique => filter_vertices_size_smallest_clique,
    :distance_max => filter_vertices_distance_max,
    :distance_min => filter_vertices_distance_min,
    :distance => filter_vertices_distance,
    :same_clique => filter_vertices_same_clique,
    :no_same_clique => filter_vertices_no_same_clique,
    :no_edge => filter_vertices_no_edge,
    :has_edge => filter_vertices_has_edge 
)


"""
    check_options_src(options_src::AbstractDict{Symbol})

Check if the sources options are valids.
"""
function check_options_src(options_src::AbstractDict{Symbol})
    options_names = keys(options_src)
    if issubset((:degree_max, :degree_min), options_names) && options_src[:degree_max]["degree"] < options_src[:degree_min]["degree"]
        error(":degree_max cannot be strictly inferior to :degree_min")
    end
    if issubset((:size_biggest_clique_max, :size_biggest_clique_min), options_names) &&
       options_src[:size_biggest_clique_max]["size"] < options_src[:size_biggest_clique_min]["size"]
        error(":size_biggest_clique_max cannot be strictly inferior to :size_biggest_clique_min")
    end
    if issubset((:size_smallest_clique_max, :size_smallest_clique_min), options_names) &&
       options_src[:size_smallest_clique_max]["size"] < options_src[:size_smallest_clique_min]["size"]
        error(":size_smallest_clique_max cannot be strictly inferior to :size_smallest_clique_min")
    end
end

"""
    check_options_dst(options_dst::AbstractDict{Symbol})

Check if the destinations options are valids.
"""
function check_options_dst(options_dst::AbstractDict{Symbol})
    check_options_src(options_dst)
    options_names = keys(options_dst)
    if issubset((:distance_max, :distance_min), options_names) && options_dst[:distance_max]["dist"] < options_dst[:distance_min]["dist"]
        error(":distance_max cannot be strictly inferior to :distance_min")
    end
    if issubset((:same_clique, :no_same_clique), options_names)
        error(":same_clique and :no_same_clique cannot be set together")
    end
    if issubset((:has_edge, :no_edge), options_names)
        error(":has_edge and :no_edge cannot be set together")
    end
end

"""
    get_valid_srcs(vertices::AbstractVector{Int}, options::AbstractDict{Symbol})

Return the vertices in `vertices` validating the options passed in parameters.
"""
function get_valid_srcs(vertices::AbstractVector{Int}, options::AbstractDict{Symbol})
    for (option, args) in options
        args[:vertices] = vertices
        vertices = src_options[option](;args...)
        if isempty(vertices)
            return vertices
        end
    end
    return vertices
end

"""
    get_valid_dsts(vertices::AbstractVector{Int}, options::AbstractDict{Symbol}, src::Int)

Return the vertices in `vertives` validating the options passed in parameters.
"""
function get_valid_dsts(vertices::AbstractVector{Int}, options::AbstractDict{Symbol}, src::Int)
    for (option, args) in options
        args[:vertices] = vertices
        ms = collect(methods(dst_options[option]))
        if :src in method_argnames(last(ms))
            args[:src] = src
        end
        vertices = dst_options[option](;args...)
        if !isempty(vertices)
            return vertices
        end
    end
    return vertices
end

"""
    add_edge_by!(graph::AbstractGraph,
                 options_src::AbstractDict{Symbol},
                 options_dst::AbstractDict{Symbol},
                 seed=nothing)

Add a single edge to `graph` validating the options passed in parameters.
If no edge corresponds to the options then the function returns `nothing`.
"""
function add_edge_by!(graph::AbstractGraph,
                      options_src::AbstractDict{Symbol},
                      options_dst::AbstractDict{Symbol},
                      seed=nothing)::Vector{Int}
    seed == nothing || Random.seed!(seed)
    src = nothing
    dst = nothing
    srcs = get_valid_srcs(vertices(graph), options_src)
    isempty(srcs) && return nothing
    while !isempty(srcs)
        src = srcs[rand(1:end)]
        dsts = get_valid_dsts(setdiff(vertices(graph), src), options_dst, src)
        if isempty(dsts)
            srcs = setdiff(srcs, src)
            continue
        else
            dst = dsts[rand(1:end)]
            break
        end
    end
    if dst == nothing
        return nothing
    end
    add_edge!(graph, src, dst)
    return [src, dst]
end

"""
    add_edges_by!(graph::AbstractGraph,
                  options_src::AbstractDict{Symbol},
                  options_dst::AbstractDict{Symbol},
                  nb_edges, seed=nothing)

Add multiple edges to `graph` validating the options passed in parameters.
"""
function add_edges_by!(graph::AbstractGraph,
                       options_src::AbstractDict{Symbol},
                       options_dst::AbstractDict{Symbol},
                       nb_edges, seed=nothing)::Vector{Vector{Int}}
    seed == nothing || Random.seed!(seed)
    added_edges = []
    for i in 1:nb_edges
        edge = add_edge_by!(graph, options_src, options_dst)
        if  edge == nothing
            @warn "Could not add $(nb_edges) with the given options, added $(length(added_edges)) instead"
            break
        else
            push!(added_edges, edge)
        end
    end
    return added_edges
end

"""
    add_edges_by!(graphs::AbstractVector{AbstractGraph},
                  options_src::AbstractDict{Symbol},
                  options_dst::AbstractDict{Symbol},
                  nb_edges, seed=nothing)

Add multiple edges to all the graph in `graphs` validating the options passed in parameters.
"""
function add_edges_by!(graphs::AbstractVector{AbstractGraph},
                       options_src::AbstractDict{Symbol},
                       options_dst::AbstractDict{Symbol},
                       nb_edges, seed=nothing)
    seed == nothing || Random.seed!(seed)
    added_edges = []
    for graph in graphs
        push!(added_edges, add_edges_by!(graph, options_src, options_dst, nb_edges))
    end
    return added_edges
end
