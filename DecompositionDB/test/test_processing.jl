using Mongoc
using Test

include("../src/basicqueries.jl")
include("../src/processing.jl")

function construct_test_instances(collection::Mongoc.Collection)
    push_instance!(collection,
                   "case1354",
                   [Mongoc.BSON("path_name" => "OPF", "path" => "path/to/OPF"),
                    Mongoc.BSON("path_name" => "Matpower", "path" => "path/to/Matpower")],
                   Mongoc.BSON("OPF" => Mongoc.BSON("opf1" => 1, "opf2" => 2),
                               "graph" => Mongoc.BSON("graph1" => 1, "graph2" => 4)))
    push_instance!(collection,
                   "case118",
                   [Mongoc.BSON("path_name" => "OPF", "path" => "path/to/OPF"),
                    Mongoc.BSON("path_name" => "Matpower", "path" => "path/to/Matpower")],
                   Mongoc.BSON("OPF" => Mongoc.BSON("opf1" => 1, "opf2" => 2),
                               "graph" => Mongoc.BSON("graph1" => 1, "graph2" => 4)))
end

function construct_test_decompositions(collection::Mongoc.Collection)
    push_decomposition!(collection,
                        "case1354",
                        [[1, 5], [6, 7]],
                        [[1, 2, 3], [4, 5, 6, 7], [8, 7]],
                        [[1, 2], [2, 3]],
                        Mongoc.BSON("clique" => Mongoc.BSON("clique1" => 1, "clique2" => 2), 
                             "solve" => Mongoc.BSON("solve1" => 1, "solve2" => 2),
                             "options_src" => Mongoc.BSON("options_src1" => 1, "options_src2" => 2),
                             "options_dst" => Mongoc.BSON("options_dst1" => 1, "options_dst2" => 2))
                       )
    push_decomposition!(collection,
                        "case1354",
                        [[5, 8], [3, 2]], 
                        [[1, 2], [2, 3, 4], [3, 4, 5], [5, 6, 7, 8]],
                        [[1, 2], [2, 3], [3, 4]],
                        Mongoc.BSON("clique" => Mongoc.BSON("clique1" => 1, "clique2" => 2), 
                             "solve" => Mongoc.BSON("solve1" => 1, "solve2" => 2),
                             "options_src" => Mongoc.BSON("options_src1" => 1, "options_src2" => 2),
                             "options_dst" => Mongoc.BSON("options_dst1" => 1, "options_dst2" => 2))
                       )
    push_decomposition!(collection,
                        "case118",
                        [[6, 7]],
                        [[1, 2, 3], [4, 5, 6, 7], [8, 7]],
                        [[1, 2], [2, 3]],
                        Mongoc.BSON("clique" => Mongoc.BSON("clique1" => 1, "clique2" => 2), 
                             "solve" => Mongoc.BSON("solve1" => 1, "solve2" => 2),
                             "options_src" => Mongoc.BSON("options_src1" => 1, "options_src2" => 2),
                             "options_dst" => Mongoc.BSON("options_dst1" => 1, "options_dst2" => 2))
                       )
end

function get_test_database()
    client = Mongoc.Client() # Default "mongodb://localhost:27017"
    Mongoc.ping(client) # Will throw an error if no mongodb daemon running
    db = client["choleskytest"]
    # I tried to use multiple different function from Mongoc to make this cleaner but none worked.
    isempty(db["instances"]) || Mongoc.drop(db["instances"])
    isempty(db["decompositions"]) || Mongoc.drop(db["decompositions"])
    return db
end

@testset "processing" begin
    db = get_test_database()
    instances = db["instances"]
    decompositions = db["decompositions"]
    construct_test_instances(instances)
    construct_test_decompositions(decompositions)
    @testset "get_subsubdocuments_keys" begin
        document_instances = get_all_document(instances)
        unique_keys = get_subsubdocuments_keys(document_instances, "features", "OPF")
        @test issubset(unique_keys, ["opf1", "opf2"])
    end
    @testset "get_id_names" begin
        document_instances = get_all_document(instances)
        document_decompositions = get_all_document(decompositions)
        @test issubset(get_id_names(document_instances[1]), ["instance_name"])
        @test issubset(get_id_names(document_decompositions[1]), ["instance_name", "added_edges"])
    end
    #TODO test for the dataframes methods
end
