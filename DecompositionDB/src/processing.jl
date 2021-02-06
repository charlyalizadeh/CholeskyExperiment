using Mongoc
using DataFrames
using Statistics



## Source: https://stackoverflow.com/questions/2997004/using-map-reduce-for-mapping-the-properties-in-a-collection
## ## It's a little mess.
## ## This way of finding the key names is not nice but it works.
## ## TODO: Find a better way to do this
function compute_features_keys(collection::Mongoc.Collection)
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


function get_feature(document, feature_name::String)
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

function get_features_df_decompositions(collection::Mongoc.Collection, collection_keys::Mongoc.Collection)
    features_name = [feature["_id"] for feature in collection_keys]
    documents = collect(collection)
    colnames = Dict(val => String[] for val in features_name)
    colnames["instance_name"] = String[]
    colnames = convert(Dict{String, Union{Array{String}, Array{Int}}}, colnames) # TODO: find another way to do this
    colnames["nb_added_edges"] = Int[]
    df = DataFrame(colnames)
    allowmissing!(df)
    fill_features_df_decompositions!(df, documents, features_name)
    return df
end

function fill_features_df_decompositions!(df::DataFrame, documents, features_name)
    for document in documents
        features = Dict("instance_name" => document["_id"]["instance_name"],
                        "nb_added_edges" => length(document["_id"]["added_edges"]))
        for feature_name in features_name
            feature = get_feature(document, feature_name)
            features[feature_name] = ismissing(feature) ? feature : string(feature)
        end
        push!(df, features)
    end
end

function get_features_df_instances(collection::Mongoc.Collection, collection_keys::Mongoc.Collection)
    features_name = [feature["_id"] for feature in collection_keys]
    documents = collect(collection)
    colnames = Dict(val => String[] for val in features_name)
    colnames["instance_name"] = String[]
    df = DataFrame(colnames)
    allowmissing!(df)
    fill_features_df_instances!(df, documents, features_name)
    return df
end

function fill_features_df_instances!(df::DataFrame, documents, features_name)
    for document in documents
        features = Dict("instance_name" => document["_id"])
        for feature_name in features_name
            feature = get_feature(document, feature_name)
            features[feature_name] = ismissing(feature) ? feature : string(feature)
        end
        push!(df, features)
    end
end

function get_features_df(collection::Mongoc.Collection, compute_key::Bool=true)
    if compute_key
        compute_features_keys(collection)
    end
    collection_keys = collection.database["$(collection.name)_keys"]
    if collection.name == "instances"
        return get_features_df_instances(collection, collection_keys)
    else
        return get_features_df_decompositions(collection, collection_keys)
    end
end

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

function get_df_features_std(collection::Mongoc.Collection)
    df = get_features_df(collection)
    std_df = DataFrame()
    for name in names(df)
        name = Symbol(name)
        name == Symbol("instance_name") && continue
        df[!,name] = parse.(Float64,df[!,name])
        #println(df[:, name])
        df[:, name] = map(x -> (x - minimum(df[:, name])) / (maximum(df[:, name]) - minimum(df[:, name])), df[:, name])
        print(std(df[:, name]))
        std_df[:, name] = [std(df[:, name])]
    end
    return std_df
end




# 
