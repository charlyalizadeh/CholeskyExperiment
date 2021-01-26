using LightGraphs
using Mongoc
using CSV

include("./DecompositionDB/src/DecompositionDB.jl")
include("./Generation/src/Generation.jl")
include("./Generation/src/utils/chordalextension.jl")
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
    # TODO: I don't know what but I need to do something for this line
    filled_options = Dict(key => convert(Dict{Symbol,Union{Int64, Base.OneTo{Int64}, AbstractGraph, Array{Int}, Array{Any}}}, val) for (key, val) in options)
    for option in collect(keys(filled_options))
        ms = collect(methods(Generation.dst_options[option]))
        argnames = Generation.method_argnames(last(ms))[2:end]
        cliques_arg = :cliques in argnames
        choleskygraph_arg = :choleskygraph in argnames
        if cliques_arg || choleskygraph_arg
            if !cliques_arg
                filled_options[option][:choleskygraph] = SimpleGraph(get_cholesky_graph(graph)[1])
            else
                cliques, nb_added_edges, choleskygraph = Generation.get_decomposition(graph)
                filled_options[option][:cliques] = cliques
                choleskygraph_arg && (filled_options[option][:choleskygraph] = SimpleGraph(choleskygraph))
            end
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
    for path in paths_matpower
        @debug "Generating decompositions for $(basename(path))"
        @debug "    Constructing graph"
        graph = construct_network_graph(path)
        # Here we add the graph-specific argument we want to pass to the filters
        @debug "    Filling the options arguments"
        options_src_copy = fill_options_arguments(options_src, graph)
        options_dst_copy = fill_options_arguments(options_dst, graph)
        name = basename(path)[1:end - 2]
        @debug "    Adding the edges"
        # TODO: Here we may generate a decomposition which is already in the database, two solutions:
        #           - We just check if the decompositions is in the database and avoid recomputing the cliques (which is computionaly expensive). This the solution for now
        #           - We check if the decompositions is in the database and if so we try to add another set of edges. This solutions may had a lot of computation 
        #             if we have a graph in the database which has almost all the possible decompositions in the database. I have no idea if this a realistic scenario, would need 
        #             to do some combinatorial calcul to get the number of decompositions for a given number of edges added.
        added_edges = Generation.add_edges_by!(graph, options_src_copy, options_dst_copy, nb_edges, seed)
        if DecompositionDB.decomposition_in_db(manager.decompositions, name, added_edges)
            @warn "Decomposition already on database, cliques computation aborted"
            continue
        end
        @debug "    Get the cliques"
        cliques, nb_added_edges, chordal_graph = get_decomposition(graph)
        @debug "    Get the cliquetree"
        cliquetree = Generation.get_cliquetree(cliques)
        # Not nice
        options_src_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                    for (key, val) in options_src)
        options_dst_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                    for (key, val) in options_dst)
        # Retrieve features. TODO: Move this part into another function
        @debug "    Retieve features"
        @debug "        -> Number edges added"
        features = Mongoc.BSON("nb_added_edges_chordal_extension" => nb_added_edges)
        @debug "        -> Chordal graph features"
        chordal_graph_features = Mongoc.BSON("chordal_graph" => ReadFeatures.get_graph_features(chordal_graph))
        @debug "        -> Pre-chordal graph features"
        pre_chordal_graph_features = Mongoc.BSON("pre_chordal_graph" => ReadFeatures.get_graph_features(graph))
        @debug "        -> Cliques features"
        cliques_features = Mongoc.BSON("cliques" => ReadFeatures.get_cliques_features(chordal_graph, cliques))
        @debug "        -> Merging the features dict"
        merge!(features, chordal_graph_features, pre_chordal_graph_features, cliques_features)
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

function export_features_df_to_csv(collection::Mongoc.Collection, path="./data/")
    filepath = joinpath(path, "$(collection.name)_features.csv")
    df = get_features_df(collection)
    symbnames = [Symbol(name) for name in names(df)]
    instance_name_index = findfirst(isequal(:instance_name), symbnames)
    symbnames[1], symbnames[instance_name_index] = symbnames[instance_name_index], symbnames[1]
    if collection.name == "decompositions"
        nb_added_edges_index = findfirst(isequal(:nb_added_edges), symbnames)
        symbnames[2], symbnames[nb_added_edges_index] = symbnames[nb_added_edges_index], symbnames[2]
    end
    df = df[!, symbnames]
    sort!(df, [:instance_name])
    CSV.write(filepath, df)
end
