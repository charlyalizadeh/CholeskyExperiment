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
    paths_matpower = collect(DecompositionDB.getmatpowerpath_all(manager.instances))
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
        if DecompositionDB.isdecomposition(manager.decompositions, name, added_edges)
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
    paths_matpower = collect(DecompositionDB.getmatpowerpath_all(manager.instances))
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
