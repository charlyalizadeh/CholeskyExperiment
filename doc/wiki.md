# CholeskyExperiment Wiki

## Project structure

* **DecompositionDB**: A MongoDB API to manage the decomposition storage
* **Generate**: Code managing the selection of edges and the generation of decomposition
* **Solve**: Code managing the solve of the decompositions
* **ReadFeature**: Code managing the features gathering
* **VisualizeFeature**: Code managing the visualization of the features
* **ExperimentManager.jl**: The interface used manage the experiments

## DecompositionDB

### Description

This module is decomposed into to file `basicqueries.jl` containing all the queries used in the project and `processing.jl` that contains function that allow the construction of more complex data about the database (such as a dataframe composed of all the features by instance).

### Usage

The `DecompositionDB` module is intended to be used with two [MongoDB collection](https://docs.mongodb.com/manual/core/databases-and-collections/) with the following schema:

```BSON
{
    "_id": "caseExample",
    "paths": [
        { "OPF_mat": "path/to/OPF_mat" },
        { "OPF_ctr": "path/to/OPF_mat" },
        { "matpower": "path/to/matpower" },
    ],
    "features": {
        "OPF": { "opf_features": 1, "opf_features2": 2, ... },
        "graph": { "graph_features1": 1, "graph_features2": 2, ... },
        ...
    }
    "decompositions": [
       {"added_edges": [[1,4],[5,120],[44,2]]},
       {"added_edges": [[3,4]]},
       ...
    ]
}
```

```BSON
{
    "_id": { "instance_name": "caseExample", "added_edge": [[], []...], ...] },
    "path_MOSEK_log": "path/to/Moseklog",
    "cliques": [[], []],
    "cliquetree": [[], []],
    "options_src": { "options_src1": {}, "options_src2": {}, ...},
    "options_dst": { "options_dst1": {}, "options_dst2": {}, ...}
    "features": {
        "clique": { "clique_features1": 1, "clique_features2": 2, ... },
        "solves": { "solve_features1": 1, "solve_features2": 2, ... },
        ...
    }
}
```


```julia
include("DecompositionDB.jl/DecompositionDB.jl")
using DecompositionDB

instance_collection = getcollection("choleskyexp", "instance")
decomposition_collection = getcollection("choleskyexp", "decomposition")

# Instance insertion
push_instance!(instance_collection, # Decomposition collection
              "case1354", # Instance name
              [Mongoc.BSON("OPF_mat" => "path/to/OPF_mat"),
               Mongoc.BSON("OPF_ctr" => "path/to/OPF_ctr"),
               Mongoc.BSON("matpower" => "path/to/matpower")] # Paths
              Mongoc.BSON("OPF" => Dict("opf1" => 1, "opf2" => 2),
                          "graph" => Dict("graph1" => 1, "graph2" => 2)
                        ) # Instance features
              )

# Decomposition insertion
push_decomposition!(decomposition_collection, # Decomposition collection
                    "case1354", # Instance name
                    [[1, 5], [6, 7]], # Added edges
                    [[1, 2, 3], [4, 5, 6, 7]], # Cliques
                    [[1, 2]], # Clique Tree
                    Dict("options_src1" => Dict(), "options_src2" => Dict()) # Options src
                    Dict("options_dst1" => Dict(),  "options_dst2" => Dict()) # Options dst
                    Dict("clique" => Dict("clique1" => 1, "clique2" => 2),
                         "solve" => Dict("solve1" => 1, "solve2" => 2)
                        ) # Decomposition features
                    )
```


## Generate

## Description

When adding edges to a graph to test the impact on the solving time we could in theory add them randomly, but it may takes a long time. So we try to add edges given some condition. We use the following filter to select the edges:
* Vertex degree
* Biggest/Smallest clique size in the Cholesky graph
* Vertex distance between the source and the destination
* Whether or not the source and destination of an edge are in the same clique in the Cholesky graph
* Whether or not the source and destination of an edge have an edge connecting them in the Cholesky graph
All the functions in the `filteredges.jl` file takes as input a vector of vertices and return the vertices in this vector validating some condition(s). Because of the way the implementation of inserting edges inside a graph works all the parameter for the filters functions are keyword arguments.
