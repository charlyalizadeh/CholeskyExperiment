function generate_decomposition_all(manager::ExperimentManager, options_src::Dict, options_dst::Dict, nb_edges=15; seed=nothing, verbose=false)
    paths_matpower = collect(DecompositionDB.getmatpowerpath_all(manager.instances))
    paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
    for path in paths_matpower
        name = basename(path)[1:end - 2]
        graph = construct_network_graph(path)
        # Here we add the graph-specific argument we want to pass to the filters
        options_src_copy = fill_options_arguments(options_src, graph)
        options_dst_copy = fill_options_arguments(options_dst, graph)
        # Here we may generate a decomposition which is already in the database, two solutions:
        #     - We just check if the decompositions is in the database and avoid recomputing the cliques (which is computionaly expensive). This the solution for now
        #     - We check if the decompositions is in the database and if so we try to add another set of edges. This solutions may had a lot of computation 
        #       if we have a graph in the database which has almost all the possible decompositions in the database. I have no idea if this a realistic scenario, would need 
        #       to do some combinatorial calcul to get the number of decompositions for a given number of edges added.
        added_edges = Generate.add_edges_by!(graph, options_src_copy, options_dst_copy, nb_edges, seed)
        if DecompositionDB.isdecomposition(manager.decompositions, name, added_edges)
            @warn "Decomposition already on database, cliques computation aborted"
            continue
        end
        cliques, nb_added_edges, chordal_graph = Generate.get_decomposition(graph)
        cliquetree = Generate.get_cliquetree(cliques)
        # Not nice
        options_src_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                    for (key, val) in options_src)
        options_dst_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                    for (key, val) in options_dst)
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
            @warn "The decomposition ($name, $(length(added_edges))) hasn't be inserted to the database"
        else
            DecompositionDB.add_decomposition_in_instance!(manager.instances, name, added_edges)
            verbose && @info "($name, $(length(added_edges))) inserted"
        end
    end
end

function generate_decomposition_all(manager::ExperimentManager, json_file::String; verbose=false)
    config = JSON.parsefile(json_file)
    options_src = convertkeytosymbol(config["src"])
    options_dst = convertkeytosymbol(config["dst"])
    nb_added_edges = config["nb_added_edges"]
    seed = config["seed"]
    generate_decomposition_all(manager, options_src, options_dst, nb_added_edges; seed=seed, verbose=verbose)
end

function generate_decomposition_mult(manager::ExperimentManager, json_file::String, paths_matpower, rank::Union{Int,Nothing}=nothing; verbose=false)
    config = JSON.parsefile(json_file)
    options_src = convertkeytosymbol(config["src"])
    options_dst = convertkeytosymbol(config["dst"])
    nb_added_edges = config["nb_added_edges"]
    seed = config["seed"]
    for (index, path) in enumerate(paths_matpower)
        generate_decomposition(manager, path, options_src, options_dst, nb_added_edges; seed=seed, verbose=verbose)
        verbose && @info "[$rank] $index/$(length(paths_matpower))"
    end
end

function generate_decomposition_all_mult(manager::ExperimentManager, json_file::String; verbose=false)
    config = JSON.parsefile(json_file)
    for (key, val) in config
        options_src = convertkeytosymbol(val["src"])
        options_dst = convertkeytosymbol(val["dst"])
        nb_added_edges = val["nb_added_edges"]
        seed = val["seed"]
        generate_decomposition_all(manager, options_src, options_dst, nb_added_edges; seed=seed, verbose=verbose)
    end
end

function generate_decomposition(manager::ExperimentManager, path, options_src, options_dst, nb_added_edges; seed=nothing, verbose=false)
    name = basename(path)[1:end - 2]
    graph = construct_network_graph(path)
    # Here we add the graph-specific argument we want to pass to the filters
    options_src_copy = fill_options_arguments(options_src, graph)
    options_dst_copy = fill_options_arguments(options_dst, graph)
    added_edges = Generate.add_edges_by!(graph, options_src_copy, options_dst_copy, nb_added_edges, seed)
    if DecompositionDB.isdecomposition(manager.decompositions, name, added_edges)
        @warn "Decomposition already on database, cliques computation aborted"
    end
    cliques, nb_added_edges, chordal_graph = Generate.get_decomposition(graph)
    cliquetree = Generate.get_cliquetree(cliques)
    # Not nice
    options_src_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                for (key, val) in options_src)
    options_dst_features = Dict(String(key) => Dict(String(key2) => val2 for (key2, val2) in val)
                                for (key, val) in options_dst)
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
        @warn "The decomposition ($name, $(length(added_edges))) hasn't be inserted to the database"
    else
        DecompositionDB.add_decomposition_in_instance!(manager.instances, name, added_edges)
        verbose && @info "($name, $(length(added_edges))) inserted"
    end
end

function generate_cholesky_all(manager::ExperimentManager; verbose=false)
    paths_matpower = collect(DecompositionDB.getmatpowerpath_all(manager.instances))
    paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
    for path in paths_matpower
        name = basename(path)[1:end - 2]
        graph = construct_network_graph(path)
        cliques, nb_added_edges, chordal_graph = Generate.get_decomposition(graph)
        cliquetree = Generate.get_cliquetree(cliques)
        features = get_features_decomposition(graph, chordal_graph, nb_added_edges, cliques, cliquetree)
        if !DecompositionDB.push_decomposition!(manager.decompositions,
                                                name,
                                                Vector{Vector{Int}}(undef, 0),
                                                cliques,
                                                cliquetree,
                                                Dict(),
                                                Dict(),
                                                nothing,
                                                features)
            @warn "The decomposition ($name, $(length(added_edges))) hasn't be inserted to the database"
        else
            DecompositionDB.add_decomposition_in_instance!(manager.instances, name, Vector{Vector{Int}}(undef, 0))
            verbose && @info "$name CHOLESKY inserted."
        end
    end
end
