"""
    getcollection(db_name::String, collection_name::String, client=Mongoc.Client())

Return a `Mongoc.Collection` object corresponding to a MongoDB collection.
"""
function getcollection(db_name::String, collection_name::String, client=Mongoc.Client())
    db = client[db_name]
    return db[collection_name]
end

"""
    isinstance(collection::Mongoc.Collection, instance_name::String)

Check if an instance with "_id" == `instance_name` exists in `collection`.
See also [`getinstance`].
"""
function isinstance(collection::Mongoc.Collection, instance_name::String)
    document = Mongoc.BSON("_id" => instance_name)
    return Mongoc.count_documents(collection, document) >= 1
end

"""
    isdecomposition(collection::Mongoc.Collection, instance_name::String, added_edges::AbstractVector{N})) where N<:AbstractVector{Int}

Check if a decomposition with "_id" = {"instance_name" : `instance_name`, "added_edges" : `added_edges`} exists in `collection`.
See also [`getdecomposition`].
"""
function isdecomposition(collection::Mongoc.Collection, instance_name::String, added_edges::AbstractVector{N}) where N<:AbstractVector{Int}
    added_edges = map(x -> sort(x), added_edges)
    sort!(added_edges, by=x -> x[1])
    document = Mongoc.BSON("_id" => Mongoc.BSON("instance_name" => instance_name, "added_edges" => added_edges))
    return Mongoc.count_documents(collection, document) >= 1
end

"""
    push_instance!(collection::Mongoc.Collection,
                   instance_name::String,
                   paths::Union{T, AbstractVector{T}}=Mongoc.BSON(),
                   features::AbstractDict=Mongoc.BSON()) where T<:AbstractDict

Insert an instance in `collection`.
"""
function push_instance!(collection::Mongoc.Collection,
                        instance_name::String,
                        paths::Union{T, AbstractVector{T}}=Mongoc.BSON(),
                        features::AbstractDict=Mongoc.BSON()) where T<:AbstractDict
    if !isinstance(collection, instance_name)
        document = Mongoc.BSON("_id" => instance_name, "paths" => paths, "decompositions" => [], "features" => features)
        push!(collection, document)
        return true
    else
        return false
    end
end

"""
    push_decomposition!(collection::Mongoc.Collection,
                        instance_name::String, 
                        added_edges::Vector{Vector{Int}},
                        cliques::Vector{Vector{Int}},
                        cliquetree::Vector{Vector{Int}},
                        options_src::Dict,
                        options_dst::Dict,
                        path_MOSEK::Union{Nothing,String}=nothing,
                        features::AbstractDict=Mongoc.BSON())


Insert a decomposition in `collection`.
"""
function push_decomposition!(collection::Mongoc.Collection,
                             instance_name::String, 
                             added_edges::AbstractVector{N},
                             cliques::AbstractVector{N},
                             cliquetree::AbstractVector{N},
                             options_src::Dict,
                             options_dst::Dict,
                             path_MOSEK::Union{Nothing,String}=nothing,
                             features::AbstractDict=Mongoc.BSON()) where N<:AbstractVector{Int}
    added_edges = map(sort, added_edges)
    sort!(added_edges, by=x -> x[1])
    if !isdecomposition(collection, instance_name, added_edges)
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
    add_decomposition_in_instance!(collection::Mongoc.Collection, instance_name::String, added_edges::AbstractVector{N}) where N<:AbstractVector{Int}

Add `added_edges` to the decompositions field.
"""
function add_decomposition_in_instance!(collection::Mongoc.Collection, instance_name::String, added_edges::AbstractVector{N}) where N<:AbstractVector{Int}
    added_edges = map(x -> sort(x), added_edges)
    sort!(added_edges, by=x -> x[1])
    decomposition = Mongoc.BSON("added_edges" => added_edges)
    selector = Mongoc.BSON("_id" => instance_name)
    update = Mongoc.BSON("\$addToSet" => Mongoc.BSON("decompositions" => decomposition))
    Mongoc.update_one(collection, selector, update)
end

"""
    setfeatures!(collection::Mongoc.Collection, selector::AbstractDict, features::AbstractDict)

Add/Update the field "features" in the document corresponding to `selector` in the collection `collection`.
"""
function setfeatures!(collection::Mongoc.Collection, selector::AbstractDict, features::AbstractDict)
    formated_dict_features = Dict("features.$(first(item))" => last(item) for item in features)
    update = Mongoc.BSON("\$set" => formated_dict_features)
    Mongoc.update_one(collection, selector, update)
end

"""
    setfeatures_instance!(collection::Mongoc.Collection, instance_name::String, features::AbstractDict)

Add/Update/Replace the field "features" in the document corresponding to "_id" == `instance_name`.
"""
function setfeatures_instance!(collection::Mongoc.Collection, instance_name::String, features::AbstractDict)
    selector = Mongoc.BSON("_id" => instance_name)
    set_features!(collection, selector, features)
end

"""
    setfeatures_decomposition!(collection::Mongoc.Collection, instance_name::String, added_edges::Vector{Vector{Int}}, features::AbstractDict)

Add/Update/Replace the field "features" in the document corresponding to "_id" == {"instance_name" : `instance_name`, "added_edges" : `added_edges`}.
"""
function setfeatures_decomposition!(collection::Mongoc.Collection, instance_name::String, added_edges::AbstractVector{N}, features::AbstractDict) where N<:AbstractVector{Int}
    selector = Mongoc.BSON("_id" => Mongoc.BSON("instance_name" => instance_name, "added_edges" => added_edges))
    set_features!(collection, selector, features)
end

"""
    getinstance(collection::Mongoc.Collection, instance_name::String)

Return a `Mongoc.BSON` corresponding to the document in `collection` with "_id" == `instance_name`. Return `nothing` if document does not exist.
"""
function getinstance(collection::Mongoc.Collection, instance_name::String)
    selector = Mongoc.BSON("_id" => instance_name)
    return Mongoc.find_one(collection, selector)
end

"""
    getdecomposition(collection::Mongoc.Collection, instance_name::String, added_edges::Vector{Vector{Int}})

Return a `Mongoc.BSON` correspong to the document in `collection` width "_id" == { "instance_name" : `instance_name`, "added_edges" : `added_edges`}. Return `nothing` if document does not exist.
"""
function getdecomposition(collection::Mongoc.Collection, instance_name::String, added_edges::AbstractVector{N}) where N<:AbstractVector{Int}
    selector = Mongoc.BSON("_id" => Mongoc.BSON("instance_name" => instance_name, "added_edges" => added_edges))
    return Mongoc.find_one(collection, selector)
end


"""
    issolved(collection::Mongoc.Collection, instance_name::String, added_edges::Vector{Vector{Int}})

Check if the field `features.solver.solving_time` exists in the specified decomposition.
"""
function issolved(collection::Mongoc.Collection, instance_name::String, added_edges::AbstractVector{N}) where N<:AbstractVector{Int}
    document = Mongoc.BSON("_id" => Mongoc.BSON("instance_name" => instance_name, "added_edges" => added_edges),
                           "features.solver.solving_time" => Mongoc.BSON("\$exists" => true))
    return Mongoc.count_documents(collection, document) >= 1
end

"""
    getOPFpath_all(collection::Mongoc.Collection)

Return a dict containing the fields "paths.OPF_ctr" and "paths.OPF_mat" for each instance.

# Examples
```julia-repl
julia> getOPFpath_all(instances)
Dict{Any,Any} with 2 entries:
  "case1354pegase" => Dict("mat"=>"path/to/OPF/mat","ctr"=>"path/to/OPF/ctr")
  "case9241pegase" => Dict("mat"=>"path/to/OPF/mat","ctr"=>"path/to/OPF/ctr")
```
"""
function getOPFpath_all(collection::Mongoc.Collection)
    query = Mongoc.BSON("""
        { "paths.OPF_ctr": { "\$exists": true },
          "paths.OPF_mat": { "\$exists": true }
        }""")
    options = Mongoc.BSON("""
        { "projection": 
            { 
                "features": false,
                "paths.matpower": false,
                "decompositions": false
            }
        }""")
    path_dict = Dict()
    for instance in Mongoc.find(collection, query; options=options)
        path_dict[instance["_id"]] = Dict("ctr" => instance["paths"]["OPF_ctr"],
                                           "mat" => instance["paths"]["OPF_mat"])
    end
    return path_dict
end

"""
    getOPFpath_one(collection::Mongoc.Collection, instance_name::String)

Return a dict containing the path of the specified instance.

```julia-repl
julia> getOPFpath_one(instances, "case118mod")
Dict{String, String} with 2 entries:
  "mat" => "path/to/OPF/ctr"
  "ctr" => "path/to/OPF/ctr"
```
"""
function getOPFpath_one(collection::Mongoc.Collection, instance_name::String)
    query = Mongoc.BSON("_id" => instance_name)
    options = Mongoc.BSON("projection" => Mongoc.BSON("paths" => true))
    path_dict = Mongoc.find_one(collection, query; options=options)["paths"]
    path_dict = Dict("ctr" => path_dict["OPF_ctr"], "mat" => path_dict["OPF_mat"])
    return path_dict
end

"""
    getcholesky(collection::Mongoc.Collection)

Return an array of BSON document where each BSON document is a decomposition where no edges has been added
(called "cholesky graph" in the context of this experiment).
"""
function getcholesky(collection::Mongoc.Collection)
    query = Mongoc.BSON("_id.added_edges" => [])
    return Mongoc.find(collection, query)
end

"""
    get_all_matpower_path(collection::Mongoc.Collection)

Get all the matpower path field in `collection` in the form of an array of `Mongoc.BSON` object.
"""
function getmatpowerpath_all(collection::Mongoc.Collection)
    return Mongoc.find(collection, Mongoc.BSON(); options=Mongoc.BSON("projection" => Mongoc.BSON("paths.matpower" => true)))
end

"""
    getunsolved_index(collection::Mongoc.Collection)

Get the index in the collect(collection) array of all unsolved decomposition.
"""
function getunsolved_index(collection::Mongoc.Collection)
    indexes = []
    for (index, document) in enumerate(collection)
        if !haskey(document["features"], "solver") || !haskey(document["features"]["solver"], "solving_time")
            push!(indexes, index)
        end
    end
    return indexes
end
