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
