using Mongoc


"""
    get_collection(db_name, collection_name, client=Mongoc.Client())

Return a `Mongoc.Collection` type object correspong to a MongoDB collection.
"""
function get_collection(db_name, collection_name, client=Mongoc.Client())
    db = client[db_name]
    return db[collection_name]
end

"""
    instance_in_db(collection::Mongoc.Collection, instance_name::String)

Check if an instance with "_id" == `instance_name` exists in `collection`.
See also [`get_instance`].
"""
function instance_in_db(collection::Mongoc.Collection, instance_name::String)
    document = Mongoc.BSON("_id" => instance_name)
    return Mongoc.count_documents(collection, document) >= 1
end

"""
    decomposition_in_db(collection::Mongoc.Collection, instance_name::String, added_edges)

Check if a decomposition with "_id" = {"instance_name" : `instance_name`, "added_edges" : `added_edges`} exists in `collection`.
See also [`get_decomposition`].
"""
function decomposition_in_db(collection::Mongoc.Collection, instance_name::String, added_edges)
    document = Mongoc.BSON("_id" => Mongoc.BSON("instance_name" => instance_name, "added_edges" => added_edges))
    return Mongoc.count_documents(collection, document) >= 1
end

"""
    push_instance!(collection::Mongoc.Collection, instance_name::String, paths=Mongoc.BSON(), features=Mongoc.BSON())

Insert an instance in `collection`.
"""
function push_instance!(collection::Mongoc.Collection, instance_name::String, paths=Mongoc.BSON(), features=Mongoc.BSON())
    if !instance_in_db(collection, instance_name)
        document = Mongoc.BSON("_id" => instance_name, "paths" => paths, "features" => features)
        push!(collection, document)
        return true
    else
        return false
    end
end

"""
    push_decomposition!(collection::Mongoc.Collection,
                        instance_name::String, 
                        added_edges,
                        cliques,
                        cliquetree,
                        options_src,
                        options_dst,
                        path_MOSEK=nothing,
                        features=Mongoc.BSON())

Insert a decomposition in `collection`.
"""
function push_decomposition!(collection::Mongoc.Collection,
                             instance_name::String, 
                             added_edges::Array,
                             cliques::Array,
                             cliquetree::Array,
                             options_src::Dict,
                             options_dst::Dict,
                             path_MOSEK=nothing,
                             features=Mongoc.BSON())
    if !decomposition_in_db(collection, instance_name, added_edges)
        document = Mongoc.BSON("_id" => Mongoc.BSON("instance_name" => instance_name, "added_edges" => added_edges),
                               "path_MOSEK_log" => path_MOSEK,
                               "cliques" => cliques,
                               "cliquetree" => cliquetree,
                               "options_src" => options_src,
                               "options_dst" => options_dst,
                               "features" => features)
        push!(collection, document)
        return true
    else
        return false
    end
end

"""
    set_features!(collection::Mongoc.Collection, selector, features)

Add/Update the field "features" in the document corresponding to `selector` in the collection `collection`.
"""
function set_features!(collection::Mongoc.Collection, selector, features)
    formated_dict_features = Dict("features.$(first(item))" => last(item) for item in features)
    update = Mongoc.BSON("\$set" => formated_dict_features)
    Mongoc.update_one(collection, selector, update)
end

"""
    set_instance_features!(collection::Mongoc.Collection, instance_name::String, features, replace::Bool=false)

Add/Update/Replace the field "features" in the document corresponding to "_id" == `instance_name`.
"""
function set_instance_features!(collection::Mongoc.Collection, instance_name::String, features)
    selector = Mongoc.BSON("_id" => instance_name)
    set_features!(collection, selector, features)
end

"""
    set_decomposition_features!(collection::Mongoc.Collection, instance_name::String, added_edges, features, replace::Bool=false)

Add/Update/Replace the field "features" in the document corresponding to "_id" == {"instance_name" : `instance_name`, "added_edges" : `added_edges`}.
"""
function set_decomposition_features!(collection::Mongoc.Collection, instance_name::String, added_edges, features)
    selector = Mongoc.BSON("_id" => Mongoc.BSON("instance_name" => instance_name, "added_edges" => added_edges))
    set_features!(collection, selector, features)
end

"""
    get_instance(collection::Mongoc.Collection, instance_name::String)

Return a `Mongoc.BSON` corresponding to the document in `collection` with "_id" == `instance_name`. Return `nothing` if document does not exist.
"""
function get_instance(collection::Mongoc.Collection, instance_name::String)
    selector = Mongoc.BSON("_id" => instance_name)
    return Mongoc.find_one(collection, selector)
end

"""
    get_decomposition(collection::Mongoc.Collection, instance_name::String, added_edges)

Return a `Mongoc.BSON` correspong to the document in `collection` width "_id" == { "instance_name" : `instance_name`, "added_edges" : `added_edges`}. Return `nothing` if document does not exist.
"""
function get_decomposition(collection::Mongoc.Collection, instance_name::String, added_edges)
    selector = Mongoc.BSON("_id" => Mongoc.BSON("instance_name" => instance_name, "added_edges" => added_edges))
    return Mongoc.find_one(collection, selector)
end

"""
    get_all_matpower_path(collection::Mongoc.Collection)

Get all the matpower path field in `collection` in the form of an array of `Mongoc.BSON` object.
"""
function get_all_matpower_path(collection::Mongoc.Collection)
    return Mongoc.find(collection, Mongoc.BSON(); options=Mongoc.BSON("projection" => Mongoc.BSON("paths.matpower" => true)))
end
