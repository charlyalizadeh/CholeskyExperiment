using LightGraphs
using Random

include("./filteredges.jl")


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

function check_options_src(options_src)
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

function check_options_dst(options_dst)
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

function get_valid_srcs(graph, options, v=vertices(graph))
    for (option, args) in options
        v = dst_options[option](args...)
        if isempty(v)
            return v
        end
    end
end

function get_valid_dsts(graph, options, src, v=setdiff(vertices(graph), src))
    for (option, args) in options
        insert!(args, src, 2)
        v = dst_options[option](args...)
        if isempty(v)
            return v
        end
    end
end

function add_edge_by!(graph::AbstractGraph, options_src::Dict=nothing, options_dst::Dict=nothing)
    src = nothing
    dst = nothing
    srcs = get_valid_vertices(graph, options_src)
    isempty(srcs) && return nothing
    while !isempty(srcs)
        src = srcs[rand(1:end)]
        dsts = get_valid_vertices(graph, options_dst, true, setdiff(vertices(graph), src))
        if isempty(srcs)
            srcs = setdiff(srcs, src)
            continue
        else
            dst = dsts[rand(1:end)]
            break
        end
    end
    if dst == nothing
        return False
    end
    return src, dst
end
