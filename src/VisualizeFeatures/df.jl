"""
    getfeaturesdf(collection::Mongoc.Collection; collection_keys=collection.database["\$(collection.name)_keys"], collectiontype::Symbol=:name)

Build a dataframe from the "features" field in `collection`.
"""
function getfeaturesdf(collection::Mongoc.Collection; collection_keys=collection.database["$(collection.name)_keys"], collectiontype::Symbol=:name)
    isempty(collection_keys) && computefeatureskeys(collection)
    collectiontype == :name && (collectiontype = getcollectiontype(collection_keys))
    features_name = [feature["_id"] for feature in collection_keys]
    colnames = getcolnamesdict(collection_keys, features_name, collectiontype=collectiontype)
    df = DataFrame(colnames)
    allowmissing!(df)
    fill!(df, collect(collection), features_name, collectiontype)
    types = eltype.(eachcol(df))
    parsecolumns!(Float64, df)
    return df
end


"""
    get_df_features_std(collection::Mongoc.Collection)

Return a dataframe where each row is an instance and each column represents a feature standard devieation.
"""
function getfeaturesdf_std(collection::Mongoc.Collection)
    df = getfeaturesdf(collection)
    colnames = filter(col -> typeof(df[!,col]) == Vector{Float64},  names(df))
    combine(groupby(df, :instance_name), colnames .=> std) 
end

