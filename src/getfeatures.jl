"""
    get_features_instance(graph, path_matpower)

Return the dict of the instances features.
"""
function get_features_instance(graph, path_matpower)
    features = Dict("graph" => ReadFeatures.getfeatures_graph(graph))
    merge!(features, Dict("OPF" => ReadFeatures.getfeatures_OPF(path_matpower)))
    merge!(features, Dict("kernel" => ReadFeatures.getfeatures_kernel(graph)))
    return features
end

"""
    get_features_decomposition(pre_chordal_graph, chordal_graph, nb_added_edges, cliques, cliquetree)

Return the dict of the decompositions features.
"""
function get_features_decomposition(pre_chordal_graph, chordal_graph, nb_added_edges, cliques, cliquetree)
    features = Mongoc.BSON("nb_added_edges_chordal_extension" => nb_added_edges)
    chordal_graph_features = Mongoc.BSON("chordal_graph" => ReadFeatures.getfeatures_graph(chordal_graph))
    pre_chordal_graph_features = Mongoc.BSON("pre_chordal_graph" => ReadFeatures.getfeatures_graph(pre_chordal_graph))
    cliques_features = Mongoc.BSON("cliques" => ReadFeatures.getfeatures_cliques(chordal_graph, cliques))
    kernel_graph_features = Mongoc.BSON("kernel" => ReadFeatures.getfeatures_kernel(pre_chordal_graph))
    merge!(features, chordal_graph_features, pre_chordal_graph_features, cliques_features, kernel_graph_features)
    return features
end

"""
    export_features_df_to_csv(collection::Mongoc.Collection, path="./data/")

Export the features dataframe of `collection` in a csv file.
"""
function export_features_df_to_csv(collection::Mongoc.Collection, path="./data/"; recompute_keys=true)
    filepath = joinpath(path, "$(collection.name)_features.csv")
    recompute_keys && Mongoc.drop(collection.database["$(collection.name)_keys"])
    df = DecompositionDB.getfeaturesdf(collection)
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
