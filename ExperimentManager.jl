using LightGraphs
using Mongoc
using CSV
import JSON

include("./DecompositionDB/src/DecompositionDB.jl")
include("./Generation/src/Generation.jl")
include("./Solve/src/Solve.jl")
include("./utils/chordalextension.jl")
include("./utils/constructgraph.jl")
include("./utils/misc.jl")
include("./ReadFeatures/src/ReadFeatures.jl")

# TODO: Docstring

# ExperimentManager definition and constructor
struct ExperimentManager
    instances::Mongoc.Collection
    decompositions::Mongoc.Collection
end

function ExperimentManager(port::String="mongodb://localhost:27017")
    client = Mongoc.Client(port)
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

# Load instance from matpower files
function load_instance_by_paths(manager::ExperimentManager, path_matpower::String, path_OPF_ctr::String, path_OPF_mat::String)
    name = basename(path_matpower)[1:end - 2]
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    graph = construct_network_graph(path_matpower)
    features = get_features_instance(graph, paths["matpower"])
    return DecompositionDB.push_instance!(manager.instances, name, paths)
end

function load_matpower_instance_by_name(manager::ExperimentManager, name::String, path_matpower::String, path_OPF::String)
    path_matpower = joinpath(path_matpower, "$(name).m")
    path_OPF_ctr = joinpath(path_OPF, "$(name)_sdp_ctr.txt")
    path_OPF_mat = joinpath(path_OPF, "$(name)_sdp_mat.txt")
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    graph = construct_network_graph(path_matpower)
    features = get_features_instance(graph, paths["matpower"])
    return DecompositionDB.push_instance!(manager.instances, name, paths, features)
end

function load_matpower_instance_by_name(manager::ExperimentManager, name::String, path_data::String="./data")
    path_matpower = joinpath(path_data, "matpower/$(name).m")
    path_OPF_ctr = joinpath(path_data, "OPF/$(name)_sdp_ctr.txt")
    path_OPF_mat = joinpath(path_data, "OPF/$(name)_sdp_mat.txt")
    graph = construct_network_graph(path_matpower)
    paths = Mongoc.BSON("matpower" => path_matpower, "OPF_ctr" => path_OPF_ctr, "OPF_mat" => path_OPF_mat)
    features = get_features_instance(graph, paths["matpower"])
    return DecompositionDB.push_instance!(manager.instances, name, paths, features)
end

function load_matpower_instance_by_size(manager::ExperimentManager, min_size=0, max_size=10000, path_data::String="./data")
    paths_matpower = readdir(joinpath(path_data, "matpower"))
    for name in paths_matpower
        print(joinpath(path_data, "matpower", name))
        graph = construct_network_graph(joinpath(path_data, "matpower", name))
        if nv(graph) >= min_size && nv(graph) <= max_size
            name = basename(name)[1:end - 2]
            load_matpower_instance_by_name(manager, name, path_data)
        end
    end
end

# Retrieve features
function get_features_instance(graph, path_matpower)
    features = Dict("graph" => ReadFeatures.get_graph_features(graph))
    merge!(features, Dict("OPF" => ReadFeatures.get_OPF_features(path_matpower)))
    merge!(features, Dict("kernel" => ReadFeatures.get_kernel_features(graph)))
    return features
end

function get_features_decomposition(pre_chordal_graph, chordal_graph, nb_added_edges, cliques, cliquetree)
    features = Mongoc.BSON("nb_added_edges_chordal_extension" => nb_added_edges)
    chordal_graph_features = Mongoc.BSON("chordal_graph" => ReadFeatures.get_graph_features(chordal_graph))
    pre_chordal_graph_features = Mongoc.BSON("pre_chordal_graph" => ReadFeatures.get_graph_features(pre_chordal_graph))
    cliques_features = Mongoc.BSON("cliques" => ReadFeatures.get_cliques_features(chordal_graph, cliques))
    kernel_graph_features = Mongoc.BSON("kernel" => ReadFeatures.get_kernel_features(pre_chordal_graph))
    merge!(features, chordal_graph_features, pre_chordal_graph_features, cliques_features, kernel_graph_features)
    return features
end

# Generate the decompositions
function generate_decomposition_all(manager::ExperimentManager, options_src::Dict, options_dst::Dict, nb_edges=15, seed=nothing)
    paths_matpower = collect(DecompositionDB.get_all_matpower_path(manager.instances))
    paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
    for path in paths_matpower
        name = basename(path)[1:end - 2]
        @info "    $name"
        @info "        Constructing graph"
        graph = construct_network_graph(path)
        # Here we add the graph-specific argument we want to pass to the filters
        @info "        Filling the options arguments"
        options_src_copy = fill_options_arguments(options_src, graph)
        options_dst_copy = fill_options_arguments(options_dst, graph)
        @info "        Adding the edges"
        # Here we may generate a decomposition which is already in the database, two solutions:
        #     - We just check if the decompositions is in the database and avoid recomputing the cliques (which is computionaly expensive). This the solution for now
        #     - We check if the decompositions is in the database and if so we try to add another set of edges. This solutions may had a lot of computation 
        #       if we have a graph in the database which has almost all the possible decompositions in the database. I have no idea if this a realistic scenario, would need 
        #       to do some combinatorial calcul to get the number of decompositions for a given number of edges added.
        added_edges = Generation.add_edges_by!(graph, options_src_copy, options_dst_copy, nb_edges, seed)
        if DecompositionDB.decomposition_in_db(manager.decompositions, name, added_edges)
            @warn "Decomposition already on database, cliques computation aborted"
            continue
        end
        @info "        Get the cliques"
        cliques, nb_added_edges, chordal_graph = Generation.get_decomposition(graph)
        @info "        Get the cliquetree"
        cliquetree = Generation.get_cliquetree(cliques)
        # Not nice
        options_src_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                    for (key, val) in options_src)
        options_dst_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                    for (key, val) in options_dst)
        @info "        Get the features"
        features = get_features_decomposition(graph, chordal_graph, nb_added_edges, cliques, cliquetree)
        if !DecompositionDB.push_decomposition!(manager.decompositions,
                                                name,
                                                added_edges,
                                                cliques,
                                                cliquetree,
                                                options_src_features,
                                                options_dst_features,
                                                nothing,
                                                features)
            @warn "The decomposition ($name, $add_edges) hasn't be inserted to the database"
        else
            DecompositionDB.add_decomposition_in_instance!(manager.instances, name, added_edges)
            @info "        Insertion succeeded"
        end
    end
end

function generate_decomposition_all(manager::ExperimentManager, json_file::String)
    config = JSON.parsefile(json_file)
    options_src = convertkeytosymbol(config["src"])
    options_dst = convertkeytosymbol(config["dst"])
    nb_added_edges = config["nb_added_edges"]
    seed = config["seed"]
    generate_decomposition_all(manager, options_src, options_dst, nb_added_edges, seed)
end

function generate_decomposition_mult(manager::ExperimentManager, json_file::String, paths_matpower)
    config = JSON.parsefile(json_file)
    options_src = convertkeytosymbol(config["src"])
    options_dst = convertkeytosymbol(config["dst"])
    nb_added_edges = config["nb_added_edges"]
    seed = config["seed"]
    for path in paths_matpower
        generate_decomposition(manager, path, options_src, options_dst, nb_added_edges, seed)
    end
end

function generate_decomposition_all_mult(manager::ExperimentManager, json_file::String)
    config = JSON.parsefile(json_file)
    for (key, val) in config
        options_src = convertkeytosymbol(val["src"])
        options_dst = convertkeytosymbol(val["dst"])
        nb_added_edges = val["nb_added_edges"]
        seed = val["seed"]
        generate_decomposition_all(manager, options_src, options_dst, nb_added_edges, seed)
    end
end

function generate_decomposition(manager::ExperimentManager, path, options_src, options_dst, nb_added_edges, seed=nothing)
    name = basename(path)[1:end - 2]
    @info "    $name"
    @info "        Constructing graph $path"
    graph = construct_network_graph(path)
    # Here we add the graph-specific argument we want to pass to the filters
    @info "        Filling the options arguments"
    options_src_copy = fill_options_arguments(options_src, graph)
    options_dst_copy = fill_options_arguments(options_dst, graph)
    @info "        Adding the edges"
    added_edges = Generation.add_edges_by!(graph, options_src_copy, options_dst_copy, nb_added_edges, seed)
    if DecompositionDB.decomposition_in_db(manager.decompositions, name, added_edges)
        @warn "Decomposition already on database, cliques computation aborted"
    end
    @info "        Get the cliques"
    cliques, nb_added_edges, chordal_graph = Generation.get_decomposition(graph)
    @info "        Get the cliquetree"
    cliquetree = Generation.get_cliquetree(cliques)
    # Not nice
    options_src_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                for (key, val) in options_src)
    options_dst_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                for (key, val) in options_dst)
    @info "        Get the features"
    features = get_features_decomposition(graph, chordal_graph, nb_added_edges, cliques, cliquetree)
    if !DecompositionDB.push_decomposition!(manager.decompositions,
                                            name,
                                            added_edges,
                                            cliques,
                                            cliquetree,
                                            options_src_features,
                                            options_dst_features,
                                            nothing,
                                            features)
        @warn "The decomposition ($name, $add_edges) hasn't be inserted to the database"
    else
        DecompositionDB.add_decomposition_in_instance!(manager.instances, name, added_edges)
        @info "        Insertion succeeded"
    end
end

function generate_cholesky_all(manager::ExperimentManager)
    paths_matpower = collect(DecompositionDB.get_all_matpower_path(manager.instances))
    paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
    for path in paths_matpower
        name = basename(path)[1:end - 2]
        @info "    $name"
        @info "        Constructing graph"
        graph = construct_network_graph(path)
        @info "        Get the cliques"
        cliques, nb_added_edges, chordal_graph = Generation.get_decomposition(graph)
        @info "        Get the cliquetree"
        cliquetree = Generation.get_cliquetree(cliques)
        @info "        Get the features"
        features = get_features_decomposition(graph, chordal_graph, nb_added_edges, cliques, cliquetree)
        if !DecompositionDB.push_decomposition!(manager.decompositions,
                                                name,
                                                [],
                                                cliques,
                                                cliquetree,
                                                Dict(),
                                                Dict(),
                                                nothing,
                                                features)
            @warn "The decomposition ($name) hasn't be inserted to the database"
        else
            DecompositionDB.add_decomposition_in_instance!(manager.instances, name, [])
            @info "        Insertion succeeded"
        end
    end
end

# Solve the decompositions
function solve_all_decomposition(manager::ExperimentManager; resolve=false)
    path_dict = DecompositionDB.get_opf_path_dict(manager.instances)
    for (index, decomposition) in enumerate(manager.decompositions)
        instance_name = decomposition["_id"]["instance_name"]
        added_edges = decomposition["_id"]["added_edges"]
        @info "Solving $index/$(length(manager.decompositions)): $instance_name, $(decomposition["features"]["chordal_graph"]["ne"]))"
        if decomposition["features"]["chordal_graph"]["ne"] > 10000
            continue
        end
        if resolve || (!resolve && !DecompositionDB.is_decomposition_solved(manager.decompositions, instance_name, added_edges))
            cliques = decomposition["cliques"]
            cliquetree = decomposition["cliquetree"]
            instance_name = decomposition["_id"]["instance_name"]
            path_opf_ctr = path_dict[instance_name]["ctr"]
            path_opf_mat = path_dict[instance_name]["mat"]
            time, nb_iter = Solve.solve_sdp(instance_name, cliques, cliquetree, path_opf_ctr, path_opf_mat)
            features = Mongoc.BSON("solver" => Mongoc.BSON("solving_time" => time, "nb_iter" => nb_iter))
            DecompositionDB.set_decomposition_features!(manager.decompositions, instance_name, decomposition["_id"]["added_edges"], features)
        end
    end
end

function solve_decomposition(manager::ExperimentManager, instance_name, added_edges; resolve=false)
    paths = DecompositionDB.get_opf_path_dict_one(manager.instances, instance_name)
    path_opf_ctr = paths["OPF_ctr"]
    path_opf_mat = paths["OPF_mat"]
    solve_decomposition(manager, instance_name, added_edges, path_opf_ctr, path_opf_mat; resolve=resolve)
end

function solve_decomposition(manager::ExperimentManager, instance_name, added_edges, path_opf_ctr, path_opf_mat; resolve=false)
    decomposition = DecompositionDB.get_decomposition(manager.decompositions, instance_name, added_edges)
    instance_name = decomposition["_id"]["instance_name"]
    added_edges = decomposition["_id"]["added_edges"]
    if resolve || (!resolve && !DecompositionDB.is_decomposition_solved(manager.decompositions, instance_name, added_edges))
        cliques = decomposition["cliques"]
        cliquetree = decomposition["cliquetree"]
        @info "Solving"
        time, nb_iter = Solve.solve_sdp(instance_name, cliques, cliquetree, path_opf_ctr, path_opf_mat)
        features = Mongoc.BSON("solver" => Mongoc.BSON("solving_time" => time, "nb_iter" => nb_iter))
        DecompositionDB.set_decomposition_features!(manager.decompositions, instance_name, added_edges, features)
    end
end

function solve_cholesky_decomposition(manager::ExperimentManager; resolve=false)
    path_dict = DecompositionDB.get_opf_path_dict(manager.instances)
    for decomposition in DecompositionDB.get_cholesky_decomposition(manager.decompositions)
        instance_name = decomposition["_id"]["instance_name"]
        added_edges = decomposition["_id"]["added_edges"]
        if resolve || (!resolve && !DecompositionDB.is_decomposition_solved(manager.decompositions, instance_name, added_edges))
            cliques = decomposition["cliques"]
            cliquetree = decomposition["cliquetree"]
            instance_name = decomposition["_id"]["instance_name"]
            path_opf_ctr = path_dict[instance_name]["ctr"]
            path_opf_mat = path_dict[instance_name]["mat"]
            time, nb_iter = Solve.solve_sdp(instance_name, cliques, cliquetree, path_opf_ctr, path_opf_mat)
            features = Mongoc.BSON("solver" => Mongoc.BSON("solving_time" => time, "nb_iter" => nb_iter))
            DecompositionDB.set_decomposition_features!(manager.decompositions, instance_name, decomposition["_id"]["added_edges"], features)
        end
    end
end

# Get features in a dataframe
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
