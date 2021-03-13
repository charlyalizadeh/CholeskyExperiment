## Source: https://stackoverflow.com/questions/2997004/using-map-reduce-for-mapping-the-properties-in-a-collection
## ## It's a little mess.
## ## This way of finding the key names is not nice but it works.
## ## TODO: Find a better way to do this
"""
    computefeatureskeys(collection::Mongoc.Collection)

Compute the features keys of a collection with a max depth of 2 (I couldn't get the expected results for a depth > 3).
The keys are stored in another collection named `\$(collection.name)_keys`.
"""
function computefeatureskeys(collection::Mongoc.Collection)
        mapper = Mongoc.BSONCode(""" 
            function(){
              for(var key in this["features"]) {
                if(typeof this["features"][key] == 'object'){
                    for(var subkey in this["features"][key]) {
                        emit(key + "." + subkey, null);
                    }
                }
                else {
                    emit(key, null);
                }
              }
            }
        """)
    reducer = Mongoc.BSONCode("""function(key, stuff) { return null; }""")
    map_reduce_command = Mongoc.BSON()
    map_reduce_command["mapReduce"] = collection.name
    map_reduce_command["map"] = mapper
    map_reduce_command["reduce"] = reducer
    map_reduce_command["out"] = "$(collection.name)_keys"
    result = Mongoc.read_command(collection.database, map_reduce_command)
    return result
end

"""
    getfeature(document::Mongoc.BSON, feature_name::String)

Retrieve the value of a feature inside a BSON document. Return `missing` if the field doesn't exists.
"""
function getfeature(document::Mongoc.BSON, feature_name::String)
    feature_name_split = split(feature_name, ".")
    features = document["features"]
    for feature_name_level in feature_name_split
        if !haskey(features, feature_name_level)
            return missing
        elseif typeof(features[feature_name_level]) <: Dict
            features = features[feature_name_level]
        else
            return features[feature_name_level]
        end
    end
end

"""
    getcolnamesdict(collection_fields::Mongoc.Collection; collectiontype::Symbol=:name)

Construct the dict featcres of a collection (either instances or decompositions). 
See also [`getfeaturesdf`]
"""
function getcolnamesdict(collection_keys::Mongoc.Collection, features_name::Vector{String}; collectiontype::Symbol=:name)
    collectiontype == :name && (collectiontype = getcollectiontype(collection_keys))
    colnames = Dict(val => Vector{Union{Missing,String}}(undef,0) for val in features_name)
    colnames["instance_name"] = Vector{Union{Missing,String}}(undef,0)
    if collectiontype == :decompositions
        colnames["nb_added_edges"] = Vector{Union{Missing,String}}(undef,0)
    end
    return colnames
end

"""
    getcollectiontype(collection::Mongoc.Collection)

Retrieve the collection content type of `collection`. 
"""
function getcollectiontype(collection::Mongoc.Collection)
    if issubset("instances", collection.name)
        return :instances
    elseif issubset("decompositions", collection.name)
        return :decompositions
    else
        throw(ArgumentError("Could not retrieve if $(collection) corresponds to the instances or decompositions collection."))
    end
end

function parsecolumns!(type::Type, df::DataFrame, exclude::Vector{String}=["solver.nb_iter", "solver.solving_time"])
    for name in names(df)
        name in exclude && continue
        values = tryparse.(type, df[!,name])
        if !(typeof(values) in [Array{Union{Nothing,type},1}, Array{Nothing,1}])
            df[!,name] = values
        end
    end
end


"""
    fillfeatures!(df::DataFrame, documents::Vector{AbstractDict}, features_name::Vector{String}, collectiontype::Symbol)

Populate `df` with the features of the documents in `documents`.
"""
function fillfeatures!(df::DataFrame, documents::Vector{N}, features_name::Vector{String}, collectiontype::Symbol) where N<:AbstractDict
    for document in documents
        features = Dict{String,Union{String,Missing}}()
        if collectiontype == :instances
            features["instance_name"] = document["_id"]
        else
            features["instance_name"] = document["_id"]["instance_name"]
            features["nb_added_edges"] = string(length(document["_id"]["added_edges"]))
        end
        for feature_name in features_name
            feature = getfeature(document, feature_name)
            features[feature_name] = ismissing(feature) ? feature : string(feature)
        end
        push!(df, features)
    end
end


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
    fillfeatures!(df, collect(collection), features_name, collectiontype)
    types = eltype.(eachcol(df))
    parsecolumns!(Float64, df)
    return df
end

"""
    get_df_features_std(collection::Mongoc.Collection)

Return a dataframe where each row is an instance and each column represents a feature standard devieation.
"""
function get_df_features_std(collection::Mongoc.Collection)
    df = getfeaturesdf(collection)
    colnames = filter(col -> typeof(df[!,col]) == Vector{Float64},  names(df))
    combine(groupby(df, :instance_name), colnames .=> std) 
end
