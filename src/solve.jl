"""
    solve_all_decomposition(manager::ExperimentManager; resolve=false)

Solve all the decompositions in the database.
"""
function solve_all_decomposition(manager::ExperimentManager; resolve=false)
    path_dict = DecompositionDB.getOPFpath_all(manager.instances)
    for (index, decomposition) in enumerate(manager.decompositions)
        instance_name = decomposition["_id"]["instance_name"]
        added_edges = decomposition["_id"]["added_edges"]
        @info "Solving $index/$(length(manager.decompositions)): $instance_name, $(decomposition["features"]["chordal_graph"]["ne"]))"
        if decomposition["features"]["chordal_graph"]["ne"] > 10000
            continue
        end
        if resolve || (!resolve && !DecompositionDB.issolved(manager.decompositions, instance_name, added_edges))
            cliques = decomposition["cliques"]
            cliquetree = decomposition["cliquetree"]
            instance_name = decomposition["_id"]["instance_name"]
            path_opf_ctr = path_dict[instance_name]["ctr"]
            path_opf_mat = path_dict[instance_name]["mat"]
            time, nb_iter = Solve.solve_sdp(instance_name, cliques, cliquetree, path_opf_ctr, path_opf_mat)
            features = Mongoc.BSON("solver" => Mongoc.BSON("solving_time" => time, "nb_iter" => nb_iter))
            DecompositionDB.setfeatures_decomposition!(manager.decompositions, instance_name, decomposition["_id"]["added_edges"], features)
        end
    end
end

"""
    solve_decomposition(manager::ExperimentManager, instance_name, added_edges; resolve=false)

Retrieve the data from the database and solve one decomposition.
"""
function solve_decomposition(manager::ExperimentManager, instance_name, added_edges; resolve=false)
    paths = DecompositionDB.getOPFpath_one(manager.instances, instance_name)
    path_opf_ctr = paths["OPF_ctr"]
    path_opf_mat = paths["OPF_mat"]
    solve_decomposition(manager, instance_name, added_edges, path_opf_ctr, path_opf_mat; resolve=resolve)
end

"""
    solve_decomposition(manager::ExperimentManager, instance_name, added_edges, path_opf_ctr, path_opf_mat; resolve=false)

Solve one decomposition.
"""
function solve_decomposition(manager::ExperimentManager, instance_name, added_edges, path_opf_ctr, path_opf_mat; resolve=false)
    decomposition = DecompositionDB.getdecomposition(manager.decompositions, instance_name, added_edges)
    instance_name = decomposition["_id"]["instance_name"]
    added_edges = decomposition["_id"]["added_edges"]
    if resolve || (!resolve && !DecompositionDB.issolved(manager.decompositions, instance_name, added_edges))
        cliques = decomposition["cliques"]
        cliquetree = decomposition["cliquetree"]
        @info "Solving"
        time, nb_iter = Solve.solve_sdp(instance_name, cliques, cliquetree, path_opf_ctr, path_opf_mat)
        features = Mongoc.BSON("solver" => Mongoc.BSON("solving_time" => time, "nb_iter" => nb_iter))
        DecompositionDB.setfeatures_decomposition!(manager.decompositions, instance_name, added_edges, features)
    end
end

"""
    solve_cholesky_decomposition(manager::ExperimentManager; resolve=false)

Solve all the decompositions in the database where `_id.added_edges` is an empty array.
"""
function solve_cholesky_decomposition(manager::ExperimentManager; resolve=false)
    path_dict = DecompositionDB.getOPFpath_one(manager.instances)
    for decomposition in DecompositionDB.getcholesky(manager.decompositions)
        instance_name = decomposition["_id"]["instance_name"]
        added_edges = decomposition["_id"]["added_edges"]
        if resolve || (!resolve && !DecompositionDB.issolved(manager.decompositions, instance_name, added_edges))
            cliques = decomposition["cliques"]
            cliquetree = decomposition["cliquetree"]
            instance_name = decomposition["_id"]["instance_name"]
            path_opf_ctr = path_dict[instance_name]["ctr"]
            path_opf_mat = path_dict[instance_name]["mat"]
            time, nb_iter = Solve.solve_sdp(instance_name, cliques, cliquetree, path_opf_ctr, path_opf_mat)
            features = Mongoc.BSON("solver" => Mongoc.BSON("solving_time" => time, "nb_iter" => nb_iter))
            DecompositionDB.setfeatures_decomposition!(manager.decompositions, instance_name, decomposition["_id"]["added_edges"], features)
        end
    end
end
