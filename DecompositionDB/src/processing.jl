using Mongoc
using DataFrames

"""
    get_subsubdocuments_keys(documents, name_doc1, name_doc2, assymbols=false)

Get all the keys of the documents corresponding to `documents[name_doc1][name_doc2]`.
"""
function get_subsubdocuments_keys(documents, name_doc1, name_doc2; assymbols=false)
    field_name = []
    for document in documents
        append!(field_name, keys(document[name_doc1][name_doc2]))
    end
    unique_keys = unique(field_name)
    if assymbols
        return [Symbol(key) for key in unique_keys]
    end
    return unique_keys
end

"""
    get_id_names(document)

Return the field names of the `_id` field in a document.
"""
function get_id_names(document; assymbols=false)
    id_names = typeof(document["_id"]) <: Dict ? collect(keys(document["_id"])) : ["instance_name"]
    if assymbols
        return [Symbol(id_name) for id_name in id_names]
    end
    return id_names
end

"""
    get_features_df(collection::AbstractArray, feature::String)

Return a DataFrame containing the list of document with the specified feature.
"""
function get_features_df(documents::AbstractArray, feature::String)
    columns = get_subsubdocuments_keys(documents, "features", feature)
    dict_features = Dict(key => [] for key in columns)
    id_names = get_id_names(documents[1])
    for id_name in id_names
        dict_features[id_name] = []
    end
    for instance in documents
        for id_name in id_names
            element = length(id_names) > 1 ?  instance["_id"][id_name] : instance["_id"]
            push!(dict_features[id_name], element)
        end
        for key in columns
            if haskey(instance["features"][feature], key)
                push!(dict_features[key], instance["features"][feature][key])
            else
                push!(dict_features[key], missing)
            end
        end
    end
    dict_features = Dict(Symbol(key) => dict_features[key] for key in keys(dict_features))
    df = DataFrame(; dict_features...)
    return df
end

"""
    get_features_df(documents::AbstractArray, feature::AbstractArray)

Return a DataFrame containing the list of document with the specified features.
"""
function get_features_df(documents::AbstractArray, feature::AbstractArray)
    id_names = get_id_names(documents[1]; assymbols=true)
    df = get_features_df(documents, feature[1])
    for name in feature[2:end]
        df = innerjoin(df, get_features_df(documents, name); on = id_names)
    end
    return df
end


"""
    get_features_df(collection::Mongoc.Collection, feature)

Return a DataFrame containing the list of document with the specified features.
"""
function get_features_df(collection::Mongoc.Collection, feature)
    documents = get_all_document(collection)
    return get_features_df(documents, feature)
end

"""
    get_instance_decomposition_df(instance,
                                  decomposition,
                                  instance_feature,
                                  decomposition_feature)

Return a DataFrame containing the the innerjoin on `:instance_name` between the collections `instance` and `decomposition`.
"""
function get_instance_decomposition_df(instance,
                                       decomposition,
                                       instance_feature=["graph", "OPF"],
                                       decomposition_feature=["clique", "solve", "options_src", "options_dst"])
    instance_df = get_features_df(instance, instance_feature)
    decomposition_df = get_features_df(decomposition, decomposition_feature)
    return innerjoin(instance_df, decomposition_df, on = (:instance_name))
end
