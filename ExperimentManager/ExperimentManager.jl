using LightGraphs
using Mongoc

include("./DecompositionDB/src/DecompositionDB.jl")
include("./Generation/src/Generation.jl")
include("./Generation/src/decomposition.jl")
include("./ExperimentManager/constructgraph.jl")


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
    instances = DecompositionDB.get_collection("instances", "choleskyexp", client)
    decompositions = DecompositionDB.get_collection("decompositions", "choleskyexp", client)
    return ExperimentManager(instances, decompositions)
end

function load_instance_by_paths(manager::ExperimentManager, path_matpower::String, path_OPF_ctr::String, path_OPF_mat::String)
    name = basename(path_matpower)[1:end - 2]
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    # TODO retrieve some features here before inserting
    return DecompositionDB.push_instance!(manager.instances, name, paths)
end

function load_matpower_instance_by_name(manager::ExperimentManager, name::String, path_matpower::String, path_OPF::String)
    path_matpower = joinpath(path_matpower, "$(name).m")
    path_OPF_ctr = joinpath(path_OPF, "$(name)_sdp_ctr.txt")
    path_OPF_mat = joinpath(path_OPF, "$(name)_sdp_mat.txt")
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    # TODO retrieve some features here before inserting
    return DecompositionDB.push_instance!(manager.instances, name, paths)
end

function load_matpower_instance_by_name(manager::ExperimentManager, name::String, path_data::String="./data")
    path_matpower = joinpath(path_data, "matpower/$(name).m")
    path_OPF_ctr = joinpath(path_data, "OPF/$(name)_sdp_ctr.txt")
    path_OPF_mat = joinpath(path_data, "OPF/$(name)_sdp_mat.txt")
    graph = construct_network_graph(path_matpower)
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    # TODO retrieve some features here before inserting
    return DecompositionDB.push_instance!(manager.instances, name, paths)
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

function generate_decomposition(manager::ExperimentManager, options_src, options_dst, nb_edges=15, seed=nothing)
    paths_matpower = collect(DecompositionDB.get_all_matpower_path(manager.instances))
    paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
    for path in paths_matpower
        graph = construct_network_graph(path)

        # Here we add the graph-specific argument we want to pass to the filters
        options_src_copy = fill_options_arguments(options_src, graph)
        options_dst_copy = fill_options_arguments(options_dst, graph)

        added_edges = Generation.add_edges_by!(graph, options_src_copy,
                                               options_dst_copy, nb_edges,
                                               seed)
        println("$(path) => $(added_edges)")
        # TODO: Generate the decompositions and store them into the databse
    end
end

