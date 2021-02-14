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
