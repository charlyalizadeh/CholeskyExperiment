"""
    export_features_df_to_csv(collection::Mongoc.Collection, path="./data/")

Export the features dataframe of `collection` in a csv file.
"""
function export_features_df_to_csv(collection::Mongoc.Collection, path="./data/"; recompute_keys=true)
    filepath = joinpath(path, "$(collection.name)_features.csv")
    recompute_keys && Mongoc.drop(collection.database["$(collection.name)_keys"])
    df = VisualizeFeatures.getfeaturesdf(collection)
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
