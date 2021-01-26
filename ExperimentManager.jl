using LightGraphs
using Mongoc

include("./DecompositionDB/src/DecompositionDB.jl")
include("./Generation/src/Generation.jl")
include("./Generation/src/decomposition.jl")
include("./Generation/src/utils/constructgraph.jl")
include("./ReadFeatures/src/ReadFeatures.jl")


struct ExperimentManager
    instances::Mongoc.Collection
    decompositions::Mongoc.Collection
end

function ExperimentManager()
    client = Mongoc.Client()
    try
        Mongoc.ping(client)
    catch err
        if isa(err, MethodError)
            error("You need to have a MongoDB daemon running.")
        end
    end
    instances = DecompositionDB.get_collection("choleskyexp", "instances", client)
    decompositions = DecompositionDB.get_collection("choleskyexp", "decompositions", client)
    return ExperimentManager(instances, decompositions)
end

function load_instance_by_paths(manager::ExperimentManager, path_matpower::String, path_OPF_ctr::String, path_OPF_mat::String)
    name = basename(path_matpower)[1:end - 2]
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    graph = construct_network_graph(path_matpower)
    features = Mongoc.BSON("graph" => ReadFeatures.get_graph_features(graph))
    # TODO retrieve OPF features here before inserting
    return DecompositionDB.push_instance!(manager.instances, name, paths)
end

function load_matpower_instance_by_name(manager::ExperimentManager, name::String, path_matpower::String, path_OPF::String)
    path_matpower = joinpath(path_matpower, "$(name).m")
    path_OPF_ctr = joinpath(path_OPF, "$(name)_sdp_ctr.txt")
    path_OPF_mat = joinpath(path_OPF, "$(name)_sdp_mat.txt")
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    graph = construct_network_graph(path_matpower)
    features = Mongoc.BSON("graph" => ReadFeatures.get_graph_features(graph))
    # TODO retrieve OPF features here before inserting
    return DecompositionDB.push_instance!(manager.instances, name, paths, features)
end

function load_matpower_instance_by_name(manager::ExperimentManager, name::String, path_data::String="./data")
    path_matpower = joinpath(path_data, "matpower/$(name).m")
    path_OPF_ctr = joinpath(path_data, "OPF/$(name)_sdp_ctr.txt")
    path_OPF_mat = joinpath(path_data, "OPF/$(name)_sdp_mat.txt")
    graph = construct_network_graph(path_matpower)
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    features = Mongoc.BSON("graph" => ReadFeatures.get_graph_features(graph))
    # TODO retrieve OPF features here before inserting
    return DecompositionDB.push_instance!(manager.instances, name, paths, features)
end

function fill_options_arguments(options, graph)
    filled_options = Dict(key => convert(Dict{Symbol,Union{Int64, Base.OneTo{Int64}, AbstractGraph, Array{Int}}}, val) for (key, val) in options)
    for option in collect(keys(filled_options))
        ms = collect(methods(Generation.dst_options[option]))
        argnames = Generation.method_argnames(last(ms))[2:end]
        if :cliques in argnames
            filled_options[option][:cliques], nb_added_edges = Generation.get_decomposition(graph)
        end
        if :graph in argnames
            filled_options[option][:graph] = graph
        end
    end
    return filled_options
end

function generate_decomposition_all(manager::ExperimentManager, options_src::Dict, options_dst::Dict, nb_edges=15, seed=nothing)
    paths_matpower = collect(DecompositionDB.get_all_matpower_path(manager.instances))
    paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
    @debug paths_matpower
    for path in paths_matpower
        graph = construct_network_graph(path)
        # Here we add the graph-specific argument we want to pass to the filters
        options_src_copy = fill_options_arguments(options_src, graph)
        options_dst_copy = fill_options_arguments(options_dst, graph)
        name = basename(path)[1:end - 2]
        added_edges = Generation.add_edges_by!(graph, options_src_copy, options_dst_copy, nb_edges, seed)
        cliques, nb_added_edges, chordal_graph = get_decomposition(graph)
        cliquetree = Generation.get_cliquetree(cliques)
        # Not nice
        options_src_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                    for (key, val) in options_src)
        options_dst_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                    for (key, val) in options_dst)
        # Retrieve features. TODO: Move this part into another function
        features = Mongoc.BSON("nb_added_edges_chordal_extension" => nb_added_edges)
        chordal_graph_features = Mongoc.BSON("chordal_graph" => ReadFeatures.get_graph_features(chordal_graph))
        added_edges_graph_features = Mongoc.BSON("pre_chordal_graph" => ReadFeatures.get_graph_features(graph))
        cliques_features = Mongoc.BSON("cliques" => ReadFeatures.get_cliques_features(chordal_graph, cliques))
        merge!(features, chordal_graph_features, added_edges_graph_features, cliques_features)
        if !DecompositionDB.push_decomposition!(manager.decompositions,
                                                name,
                                                added_edges,
                                                cliques,
                                                cliquetree,
                                                options_src_features,
                                                options_dst_features,
                                                nothing,
                                                features)
            @warn "The decomposition ($name, $add_edges) hasn't be inserted to the database."
        else
            @debug "Insertion succeded"
        end
    end
end

function get_features_df(collection::Mongoc.Collection)
    if collection.name == "instances"
        return DecompositionDB.get_features_df(manager.instances)
    elseif collection.name == "decompositions"
        return DecompositionDB.get_features_df(manager.decompositions)
    end
end
