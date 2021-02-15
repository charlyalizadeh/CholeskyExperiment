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
 * [JuMP](https://github.com/jump-dev/JuMP.jl)
 * [Mosek](https://github.com/MOSEK/Mosek.jl)
 * [MosekTools](https://github.com/jump-dev/MosekTools.jl)
 * [DataStructures](https://github.com/JuliaCollections/DataStructures.jl)
 * [StatsBase](https://github.com/JuliaStats/StatsBase.jl)
 * [MPI](https://github.com/JuliaParallel/MPI.jl)
 * [JSON](https://github.com/JuliaIO/JSON.jl)
 * [CSV](https://github.com/JuliaData/CSV.jl)

## Installation

Go to the directory where you want to install this module.  

```bash
$ cd path/to/install/
```

Clone this repository.  

```bash
$ git clone https://github.com/charlyalizadeh/CholeskyExperiment
```

## Documentation

[Wiki](https://github.com/charlyalizadeh/CholeskyExperiment/tree/master/doc/wiki.md)
[Style Guide](https://github.com/charlyalizadeh/CholeskyExperiment/blob/master/doc/styleguide.md)
