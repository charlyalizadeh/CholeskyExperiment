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
    colnames = Dict(val => String[] for val in features_name)
    colnames["instance_name"] = String[]
    if collectiontype == :decompositions
        colnames = convert(Dict{String, Union{Vector{String}, Vector{Int}}}, colnames) # TODO: find another way to do this
        colnames["nb_added_edges"] = Int[]
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


"""
    fillfeatures!(df::DataFrame, documents::Vector{AbstractDict}, features_name::Vector{String}, collectiontype::Symbol)

Populate `df` with the features of the documents in `documents`.
"""
function fillfeatures!(df::DataFrame, documents::Vector{AbstractDict}, features_name::Vector{String}, collectiontype::Symbol)
    for document in documents
        features = collectiontype == :instances ?
                        Dict("instance_name" => document["_id"]) :
                        Dict("instance_name" => document["_id"]["instance_name"],
                             "nb_added_edges" => length(document["_id"]["added_edges"]))
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
    return df
end

"""
TODO: Under development
"""
function build_features_stats_collection(collection::Mongoc.Collection, compute_key::Bool=true)
    if compute_key
        compute_features_keys(collection)
    end
    collection_keys = collection.database["$(collection.name)_keys"]
    features_name = [feature["_id"] for feature in collection_keys]
    accumulators = ""
    for (index, key) in enumerate(features_name)
        accumulator_name = replace(key, "." => "_")
        accumulators = string(accumulators, """"$(accumulator_name)" : { "\$stdDevPop": "\$features.$(key)" }""")
        if index < length(features_name)
            accumulators = string(accumulators, ",")
        end
    end
    aggregation = Mongoc.BSON("""[
            { "\$group" : {
                "_id": "\$_id.instance_name",
                $(accumulators)
            }}
        ]""")
    stats_collection = collection.database["$(collection.name)_stats"]
    for d in Mongoc.aggregate(collection, aggregation)
        push!(stats_collection, d)
    end
end

"""
TODO: Under development
"""
function get_df_features_std(collection::Mongoc.Collection)
    df = get_features_df(collection)
    std_df = DataFrame()
    for name in names(df)
        name = Symbol(name)
        name == Symbol("instance_name") && continue
        df[!,name] = parse.(Float64,df[!,name])
        df[:, name] = map(x -> (x - minimum(df[:, name])) / (maximum(df[:, name]) - minimum(df[:, name])), df[:, name])
        std_df[:, name] = [std(df[:, name])]
    end
    return std_df
end
