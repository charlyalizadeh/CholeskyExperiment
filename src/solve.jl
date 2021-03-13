"""
    solve_all_decomposition(manager::ExperimentManager; resolve=false)

Solve all the decompositions in the database.
"""
function solve_all_decomposition(manager::ExperimentManager,
                                 set_cholesky_time_limit::Bool=true;
                                 time_limit=100000,
                                 resolve=false)
    path_dict = DecompositionDB.getOPFpath_all(manager.instances)
    for (index, decomposition) in enumerate(manager.decompositions)
        instance_name = decomposition["_id"]["instance_name"]
        added_edges::Vector{Vector{Int}} = decomposition["_id"]["added_edges"]
        if added_edges == []
            added_edges = Vector{Vector{Int}}(undef, 0)
        elseif set_cholesky_time_limit
            time_limit = DecompositionDB.getcholeskytime(manager.decompositions, instance_name)
            time_limit = parse(Float64, time_limit) * 3.
        end
        @info "$instance_name time limit: $time_limit"
        if resolve || (!resolve && !DecompositionDB.issolved(manager.decompositions, instance_name, added_edges))
            cliques = decomposition["cliques"]
            cliquetree = decomposition["cliquetree"]
            path_opf_ctr = path_dict[instance_name]["ctr"]
            path_opf_mat = path_dict[instance_name]["mat"]
            time, nb_iter = Solve.solve_sdp(instance_name, cliques, cliquetree, path_opf_ctr, path_opf_mat; time_limit=time_limit)
            time = parse(Float64, time)
            features = Mongoc.BSON("solver" => Mongoc.BSON("solving_time" => time, "nb_iter" => nb_iter))
            DecompositionDB.setfeatures_decomposition!(manager.decompositions, instance_name, added_edges, features)
        end
    end
end

"""
    solve_decomposition_by_id(manager::ExperimentManager, instance_name, added_edges; resolve=false)

Retrieve the data from the database and solve one decomposition.
"""
function solve_decomposition(manager::ExperimentManager,
                             instance_name::String,
                             added_edges::AbstractVector{N},
                             set_cholesky_time_limit::Bool=true;
                             time_limit::Float64=100000.,
                             resolve::Bool=false) where N<:AbstractVector{Int}
    paths = DecompositionDB.getOPFpath_one(manager.instances, instance_name)
    path_opf_ctr = paths["ctr"]
    path_opf_mat = paths["mat"]
    solve_decomposition(manager, instance_name, added_edges, path_opf_ctr, path_opf_mat, set_cholesky_time_limit; time_limit=time_limit, resolve=resolve)
end

"""
    solve_decomposition(manager::ExperimentManager, instance_name, added_edges, path_opf_ctr, path_opf_mat; resolve=false)

Solve one decomposition.
"""
function solve_decomposition(manager::ExperimentManager,
                             instance_name::String,
                             added_edges::AbstractVector{N},
                             path_opf_ctr::String,
                             path_opf_mat::String,
                             set_cholesky_time_limit::Bool=true;
                             time_limit::Float64=100000.,
                             resolve::Bool=false) where N<:AbstractVector{Int}
    decomposition = DecompositionDB.getdecomposition(manager.decompositions, instance_name, added_edges)
    instance_name = decomposition["_id"]["instance_name"]
    added_edges::Vector{Vector{Int}} = decomposition["_id"]["added_edges"]
    if added_edges == []
        added_edges = Vector{Vector{Int}}(undef, 0)
    elseif set_cholesky_time_limit
        time_limit = DecompositionDB.getcholeskytime(manager.decompositions, instance_name)
        time_limit = parse(Float64, time_limit) * 3.
        @info "Computing time limit: $instance_name: $time_limit"
    end
    if resolve || (!resolve && !DecompositionDB.issolved(manager.decompositions, instance_name, added_edges))
        cliques = decomposition["cliques"]
        cliquetree = decomposition["cliquetree"]
        time, nb_iter = Solve.solve_sdp(instance_name, cliques, cliquetree, path_opf_ctr, path_opf_mat; time_limit=time_limit)
        time = parse(Float64, time)
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
