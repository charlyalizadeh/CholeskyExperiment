"""
    getvalue(document::Mongoc.BSON, feature_name::String)

Retrieve the value of a feature inside a BSON document. Return `missing` if the field doesn't exist.
"""
function getvalue(document::Mongoc.BSON, feature_name::String)
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

Construct the dict with the format ("features names" => []) of a collection (either instances or decompositions).
See also [`getfeaturesdf`]
"""
function getcolnamesdict(collection_keys::Mongoc.Collection, names::Vector{String}; collectiontype::Symbol=:name)
    collectiontype == :name && (collectiontype = getcollectiontype(collection_keys))
    colnames = Dict(val => Vector{Union{Missing,String}}(undef,0) for val in names)
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


"""
    fill!(df::DataFrame, documents::Vector{AbstractDict}, names::Vector{String}, collectiontype::Symbol)

Populate `df` with the values in `documents`.
"""
function fill!(df::DataFrame, documents::Vector{N}, names::Vector{String}, collectiontype::Symbol) where N<:AbstractDict
    for document in documents
        features = Dict{String,Union{String,Missing}}()
        if collectiontype == :instances
            features["instance_name"] = document["_id"]
        else
            features["instance_name"] = document["_id"]["instance_name"]
            features["nb_added_edges"] = string(length(document["_id"]["added_edges"]))
        end
        for feature_name in names
            feature = getvalue(document, feature_name)
            features[feature_name] = ismissing(feature) ? feature : string(feature)
        end
        push!(df, features)
    end
end
