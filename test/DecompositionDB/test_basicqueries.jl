using Test
using Mongoc

include("../../DecompositionDB/src/basicqueries.jl")

# TODO: Update the test
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

@testset "basicqueries" begin
    db = get_test_database()
    instances = db["instances"]
    decompositions = db["decompositions"]
    construct_test_instances(instances)
    construct_test_decompositions(decompositions)
    @testset "instance_in_db" begin
        @test instance_in_db(instances, "case1354")
        @test instance_in_db(instances, "case118")
        @test !(instance_in_db(instances, "case118mod"))
    end
    @testset "decomposition_in_db" begin
        @test decomposition_in_db(decompositions, "case1354", [[1, 5], [6, 7]])
        @test decomposition_in_db(decompositions, "case1354", [[5, 8], [3, 2]])
        @test decomposition_in_db(decompositions, "case118", [[6, 7]])
        @test !decomposition_in_db(decompositions, "case118", [[6, 7], [5, 8]])
        @test !decomposition_in_db(decompositions, "case1354", [[1, 5], [6, 5]])
    end
    @testset "push_instance!" begin
        push_instance!(instances, "case118mod")
        @test instance_in_db(instances, "case118mod")
    end
    @testset "push_decomposition!" begin
        push_decomposition!(decompositions, "case118mod", [[1, 2],[3, 5]], [], [])
        @test decomposition_in_db(decompositions, "case118mod", [[1, 2],[3, 5]])
    end
    @testset "set_instance_features!" begin
        set_instance_features!(instances,
                               "case118mod",
                               Mongoc.BSON("graph" => Mongoc.BSON("testgraph1" => 1, "testgraph2" => 3),
                                           "OPF" => Mongoc.BSON("testOPF1" => "2", "testOPF2" => "4")))
        instance = get_instance(instances, "case118mod")
        @test instance["features"]["graph"]["testgraph1"] == 1
        @test instance["features"]["graph"]["testgraph2"] == 3
        @test instance["features"]["OPF"]["testOPF1"] == "2"
        @test instance["features"]["OPF"]["testOPF2"] == "4"

        set_instance_features!(instances,
                               "case118mod",
                               Mongoc.BSON("graph" => Mongoc.BSON("testgraph1" => 2, "testgraph2" => 4),
                                           "OPF" => Mongoc.BSON("testOPF1" => "1", "testOPF2" => "3")))
        instance = get_instance(instances, "case118mod")
        @test instance["features"]["graph"]["testgraph1"] == 2
        @test instance["features"]["graph"]["testgraph2"] == 4
        @test instance["features"]["OPF"]["testOPF1"] == "1"
        @test instance["features"]["OPF"]["testOPF2"] == "3"
    end
    @testset "set_decomposition_features!" begin
        set_decomposition_features!(decompositions,
                                    "case118mod",
                                    [[1, 2],[3, 5]],
                                    Mongoc.BSON("clique" => Mongoc.BSON("testclique1" => 1, "testclique2" => 3),
                                                "solve" => Mongoc.BSON("testsolve1" => "2", "testsolve2" => "4")))
        decomposition = get_decomposition(decompositions, "case118mod", [[1, 2],[3, 5]])
        @test decomposition["features"]["clique"]["testclique1"] == 1
        @test decomposition["features"]["clique"]["testclique2"] == 3
        @test decomposition["features"]["solve"]["testsolve1"] == "2"
        @test decomposition["features"]["solve"]["testsolve2"] == "4"

        set_decomposition_features!(decompositions,
                                    "case118mod",
                                    [[1, 2],[3, 5]],
                                    Mongoc.BSON("clique" => Mongoc.BSON("testclique1" => 2, "testclique2" => 4),
                                                "solve" => Mongoc.BSON("testsolve1" => "1", "testsolve2" => "3")))
        decomposition = get_decomposition(decompositions, "case118mod", [[1, 2],[3, 5]])
        @test decomposition["features"]["clique"]["testclique1"] == 2
        @test decomposition["features"]["clique"]["testclique2"] == 4
        @test decomposition["features"]["solve"]["testsolve1"] == "1"
        @test decomposition["features"]["solve"]["testsolve2"] == "3"
    end
end
