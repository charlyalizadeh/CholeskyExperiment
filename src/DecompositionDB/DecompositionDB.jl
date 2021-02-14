module DecompositionDB


using Mongoc
using DataFrames
using Statistics

include("basicqueries.jl")
include("processing.jl")


export getcollection,
       isinstance, isdecomposition,
       push_instance!, push_decomposition!,
       add_decomposition_in_instance!,
       setfeatures!, setfeatures_instance!, setfeatures_decomposition!,
       getinstance, getdecomposition,
       issolved,
       getOPFpath_all, getOPFpath_one,
       getcholesky,
       getmatpowerpath_all,
       getunsolved_index,
       getfeaturesdf


end # module
