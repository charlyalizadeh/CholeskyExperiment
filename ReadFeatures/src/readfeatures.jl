using LightGraphs: AbstractGraph, nv, ne, Δ, δ, density, degree
using Statistics
using StatsBase




function get_graph_features(graph::T, vweights=ones(nv(graph))) where T<:AbstractGraph
    graph_features = Dict()
    graph_features["nv"] = nv(graph)
    graph_features["ne"] = ne(graph)
    graph_features["degree_mean"] = mean(degree(graph), weights(vweights))
    graph_features["degree_var"] = var(degree(graph), weights(vweights))
    graph_features["degree_max"] = Δ(graph)
    println()
    graph_features["degree_min"] = δ(graph)
    graph_features["density"] = density(graph)
    return graph_features
end

function get_cliques_features(graph::T, cliques, cweights=ones(length(cliques))) where T<:AbstractGraph
    cliques_features = Dict()
    cliques_features["nb"] = length(cliques)
    cliques_size = [length(clique) for clique in cliques]
    cliques_features["size_mean"] = mean(cliques_size, weights(cweights)) 
    cliques_features["size_var"] = var(cliques_size, weights(cweights)) 
    cliques_features["size_max"] = maximum(cliques_size) 
    cliques_features["size_min"] = minimum(cliques_size) 
    return cliques_features
end

function get_OPF_features(path_matpower)
    # TODO: load, linking constraints, etc
end
