
***!!EARLY DEVELOPMENT!!***

# CholeskyExperiment

Julia project to experiment with Cholesky decompositions in order to improve optimal power flow (OPF) computation performances.

One way to solve an OPF instance is to relax it into a SDP problem. To improve the solving time of a SDP problem we can take advantage of the coefficients matrix sparsity and decompose it into multiple smaller matrices. One step in the decomposition is to compute the chordal extension of a graph thanks to a Cholesky factorization, this step is deterministic and will always gives us the same result for a given input. The resulted chordal extension has a big impact on the reformulation of the SDP problem and so on the solving time. Our goal is to build a machine learning model that can select the best decomposition between multiple ones. For that we need to generate a dataset of decomposition with their solving time.

>> For the following parts when we talk about the *Cholesky graph* we talk about the chordal extension of a graph where we didn't add any edges before applying the Cholesky factorisation.


## Requirements

 * [MongoDB](https://www.mongodb.com/fr) >= 3.0 
 * [Julia](https://julialang.org/) >= 1.3

### Julia packages

 * [Mongoc](https://github.com/felipenoris/Mongoc.jl)
 * [DataFrames](https://github.com/JuliaData/DataFrames.jl)
 * [LightGraphs](https://github.com/JuliaGraphs/LightGraphs.jl)

## Installation

Go to the directory where you want to install this module.  

```bash
$ cd path/to/install/
```

Clone this repository.  

```bash
$ git clone https://github.com/charlyalizadeh/CholeskyExperiment
```

## Project structure (susceptible to changes)

* **DecompositionDB**: A MongoDB API to manage the decomposition storage
* **Generate**: Code managing the selection of edges and the generation of decomposition
* **Solve**: Code managing the solve of the decompositions
* **ReadFeature**: Code managing the features gathering
* **VisualizeFeature**: Code managing the visualization of the features



## Generate

### Filtering edges

When adding edges to a graph to test the impact on the solving time we could in theory add them randomly, but it may takes a long time. So we try to add edges given some condition. We use the following filter to select the edges:
* Vertex degree
* Biggest/Smallest clique size in the Cholesky graph
* Vertex distance between the source and the destination
* Whether or not the source and destination of an edge are in the same clique in the Cholesky graph
* Whether or not the source and destination of an edge have an edge connecting them in the Cholesky graph



## DecompositionDB

### Usage

The `DecompositionDB` module is intended to be used with two [MongoDB collection](https://docs.mongodb.com/manual/core/databases-and-collections/) with the following schema:

```BSON
{
    "_id": "caseExample",
    "paths": [
        { "path_name": "OPF", "path": "path/to/OPF" },
        { "path_name": "Matpower", "path": "path/to/Matpower" }
    ],
    "features": {
        "OPF": { "opf_features": 1, "opf_features2": 2, ... },
        "graph": { "graph_features1": 1, "graph_features2": 2, ... }
    }
}
```

```BSON
{
    "_id": { "instance_name": "caseExample", added_edge: [[], []], ...] },
    "path_MOSEK_log": "path/to/Moseklog",
    "features": {
        "clique": { "clique_features1": 1, "clique_features2": 2, ... },
        "solve": { "solve_features1": 1, "solve_features2": 2, ... },
        "options_src": { "options_src1": {}, "options_src2": {}, ...},
        "options_dst": { "options_dst1": {}, "options_dst2": {}, ...}
    }
}
```

>> Note that none of those two schemas are forced, they are only how **we** use it. You could use it in another way but it may not make a lot of sense.

We use it this way:

```julia
include("DecompositionDB.jl/src/DecompositionDB.jl")
using DecompositionDB

instance_collection = get_collection("cholesky", "instance")
decomposition_collection = get_collection("cholesky", "decomposition")

# Instance insertion
push_instance!(instance_collection,
              "case1354", # Instance name
              Mongoc.BSON("OPF" => Dict("opf1" => 1, "opf2" => 2),
                          "graph" => Dict("graph1" => 1, "graph2" => 2)
                        ) # Instance features
              )

# Decomposition insertion
push_decomposition!(decomposition_collection,
                    "case1354", # Instance name
                    [[1,5], [6,7]], # Added edges
                    [[1,2,3], [4,5,6,7]], # Cliques
                    Dict("clique" => Dict("clique1" => 1, "clique2" => 2),
                         "solve" => Dict("solve1" => 1, "solve2" => 2),
                         "options_src" => Dict("options_src1" => Dict(), "options_src2" => Dict())
                         "options_dst" => Dict("options_dst1" => Dict(),  "options_dst2" => Dict())
                        ) # Decomposition features
                    )
```

## TODO

* [X] DecompositionDB
    * [X] Process data   
    * [X] Basic queries
* [ ] Generate
    * [X] Filter the edges
    * [ ] Generate a decomposition given some options and a given number of edges
* [ ] Solve
    * [ ] Build a MOSEK model from the database
* [ ] ReadFeatures
* [ ] VisualizeFeatures
