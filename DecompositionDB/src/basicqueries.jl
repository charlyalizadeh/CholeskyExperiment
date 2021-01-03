using Mongoc

"""DEBUG"""
function construct_debug_instances(collection::Mongoc.Collection)
    push_instance!(collection, "case1354", Mongoc.BSON("OPF" => Dict("opf1" => 1, "opf2" => 2), "graph" => Dict("graph1" => 1, "graph2" => 4)))
    push_instance!(collection, "case118", Mongoc.BSON("OPF" => Dict("opf1" => 1, "opf2" => 2), "graph" => Dict("graph1" => 1, "graph2" => 4)))
    push_instance!(collection, "case118mod", Mongoc.BSON("OPF" => Dict("opf1" => 1, "opf2" => 2), "graph" => Dict("graph1" => 1, "graph2" => 4)))
    push_instance!(collection, "case14", Mongoc.BSON("OPF" => Dict("opf1" => 1, "opf2" => 2), "graph" => Dict("graph1" => 1, "graph2" => 4)))
end

"""DEBUG"""
function construct_debug_decompositions(collection::Mongoc.Collection)
    push_decomposition!(collection, "case1354", [[1,5], [6,7]], [[1,2,3], [4,5,6,7], [8,7]], [[1,2], [2,3]], Dict("clique" => Dict("clique1" => 1, "clique2" => 2), 
                                                                                                                  "solve" => Dict("solve1" => 1, "solve2" => 2),
                                                                                                                  "options_src" => Dict("options_src1" => 1, "options_src2" => 2),
                                                                                                                  "options_dst" => Dict("options_dst1" => 1, "options_dst2" => 2)
                                                                                                                 ))
    push_decomposition!(collection, "case1354", [[6,7]], [[1,2,3], [4,5,6,7], [8,7]], [[1,2], [2,3]], Dict("clique" => Dict("clique1" => 1, "clique2" => 2), 
                                                                                                                  "solve" => Dict("solve1" => 1, "solve2" => 2),
                                                                                                                  "options_src" => Dict("options_src1" => 1, "options_src2" => 2),
                                                                                                                  "options_dst" => Dict("options_dst1" => 1, "options_dst2" => 2)
                                                                                                                 ))
    push_decomposition!(collection, "case118", [[1,5], [6,7]], [[4,5,6,7], [8,7]], [[1,2], [2,3]], Dict("clique" => Dict("clique1" => 1, "clique2" => 2), 
                                                                                                        "solve" => Dict("solve1" => 1, "solve2" => 2),
                                                                                                        "options_src" => Dict("options_src1" => 1, "options_src2" => 2),
                                                                                                        "options_dst" => Dict("options_dst1" => 1, "options_dst2" => 2)
                                                                                                       ))
    push_decomposition!(collection, "case118mod", [[6,7]], [[1,2,3], [4,5,6,7], [8,7]], [[1,2], [2,3]], Dict("clique" => Dict("clique1" => 1, "clique2" => 2), 
                                                                                                             "solve" => Dict("solve1" => 1, "solve2" => 2),
                                                                                                             "options_src" => Dict("options_src1" => 1, "options_src2" => 2),
                                                                                                             "options_dst" => Dict("options_dst1" => 1, "options_dst2" => 2)
                                                                                                            ))
    push_decomposition!(collection, "case14", [[1,5]], [[1,2,3], [4,5,6,7], [8,7]], [[1,2], [2,3]], Dict("clique" => Dict("clique1" => 1, "clique2" => 2), 
                                                                                                         "solve" => Dict("solve1" => 1, "solve2" => 2),
                                                                                                         "options_src" => Dict("options_src1" => 1, "options_src2" => 2),
                                                                                                         "options_dst" => Dict("options_dst1" => 1, "options_dst2" => 2)
                                                                                                        ))
end

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
    decomposition_in_db(collection::Mongoc.Collection, instance_name::String, added_edge)

Check if a decomposition with "_id" = {"instance_name" : `instance_name`, "added_edge" : `added_edge`} exists in `collection`.
See also [`get_decomposition`].
"""
function decomposition_in_db(collection::Mongoc.Collection, instance_name::String, added_edge)
    document = Mongoc.BSON("_id" => Dict("instance_name" => instance_name, "added_edge" => added_edge))
    return Mongoc.count_documents(collection, document) >= 1
end

"""
    push_instance!(collection::Mongoc.Collection, instance_name::String, features=Dict())

Insert an instance in `collection`.
"""
function push_instance!(collection::Mongoc.Collection, instance_name::String, features=Dict())
    if !instance_in_db(collection, instance_name)
        document = Mongoc.BSON("_id" => instance_name, "features" => features)
        push!(collection, document)
    end
end

"""
    push_decomposition!(collection::Mongoc.Collection, instance_name::String, added_edge, blocks, cliquetree, features=Dict())

Insert a decomposition in `collection`.
"""
function push_decomposition!(collection::Mongoc.Collection, instance_name::String, added_edge, blocks, cliquetree, features=Dict())
    if !decomposition_in_db(collection, instance_name, added_edge)
        document = Mongoc.BSON("_id" => Dict("instance_name" => instance_name, "added_edge" => added_edge), "features" => features)
        push!(collection, document)
    end
end

"""
    set_features!(collection::Mongoc.Collection, selector, features, replace::Bool=false)

Add/Update/Replace the field "features" in the document corresponding to `selector` in the collection `collection`.
"""
function set_features!(collection::Mongoc.Collection, selector, features, replace::Bool=false)
    formated_dict_features = features
    if !replace
        formated_dict_features = Dict("features.$(first(item))" => last(item) for item in features)
    end
    update = Mongoc.BSON("\$set" => formated_dict_features)
    Mongoc.update_one(collection, selector, update)
end

"""
    set_instance_features!(collection::Mongoc.Collection, instance_name::String, features, replace::Bool=false)

Add/Update/Replace the field "features" in the document corresponding to "_id" == `instance_name`.
"""
function set_instance_features!(collection::Mongoc.Collection, instance_name::String, features, replace::Bool=false)
    selector = Mongoc.BSON("_id" => instance_name)
    set_features!(collection, selector, features, replace)
end

"""
    set_decomposition_features!(collection::Mongoc.Collection, instance_name::String, added_edge, features, replace::Bool=false)

Add/Update/Replace the field "features" in the document corresponding to "_id" == {"instance_name" : `instance_name`, "added_edge" : `added_edge`}.
"""
function set_decomposition_features!(collection::Mongoc.Collection, instance_name::String, added_edge, features, replace::Bool=false)
    selector = Mongoc.BSON("_id" => Dict("instance_name" => instance_name, "added_edge" => added_edge))
    set_features!(collection, selector, features, replace)
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
    get_decomposition(collection::Mongoc.Collection, instance_name::String, added_edge)

Return a `Mongoc.BSON` correspong to the document in `collection` width "_id" == { "instance_name" : `instance_name`, "added_edge" : `added_edge`}. Return `nothing` if document does not exist.
"""
function get_decomposition(collection::Mongoc.Collection, instance_name::String, added_edge)
    selector = Mongoc.BSON("_id" => Dict("instance_name" => instance_name, "added_edge" => added_edge))
    return Mongoc.find_one(collection, selector)
end

"""
    get_all_document(collection::Mongoc.Collection)

Get all the documents in `collection` in the form of an array of `Mongoc.BSON` object.
"""
function get_all_document(collection::Mongoc.Collection)
    return collect(collection)
end
