"""
    get_features_instance(graph, path_matpower)

Return the dict of the instances features.
"""
function get_features_instance(graph, path_matpower)
    features = Dict("graph" => ReadFeatures.get_graph_features(graph))
    merge!(features, Dict("OPF" => ReadFeatures.get_OPF_features(path_matpower)))
    merge!(features, Dict("kernel" => ReadFeatures.get_kernel_features(graph)))
    return features
end

"""
    get_features_decomposition(pre_chordal_graph, chordal_graph, nb_added_edges, cliques, cliquetree)

Return the dict of the decompositions features.
"""
function get_features_decomposition(pre_chordal_graph, chordal_graph, nb_added_edges, cliques, cliquetree)
    features = Mongoc.BSON("nb_added_edges_chordal_extension" => nb_added_edges)
    chordal_graph_features = Mongoc.BSON("chordal_graph" => ReadFeatures.get_graph_features(chordal_graph))
    pre_chordal_graph_features = Mongoc.BSON("pre_chordal_graph" => ReadFeatures.get_graph_features(pre_chordal_graph))
    cliques_features = Mongoc.BSON("cliques" => ReadFeatures.get_cliques_features(chordal_graph, cliques))
    kernel_graph_features = Mongoc.BSON("kernel" => ReadFeatures.get_kernel_features(pre_chordal_graph))
    merge!(features, chordal_graph_features, pre_chordal_graph_features, cliques_features, kernel_graph_features)
    return features
end

"""
    get_features_df(collection::Mongoc.Collection)

Build the features dataframe of the collection passed in parameters.
"""
function get_features_df(collection::Mongoc.Collection)
    if collection.name == "instances"
        return DecompositionDB.get_features_df(manager.instances)
    elseif collection.name == "decompositions"
        return DecompositionDB.get_features_df(manager.decompositions)
    end
end

"""
    export_features_df_to_csv(collection::Mongoc.Collection, path="./data/")

Export the features dataframe of `collection` in a csv file.
"""
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
