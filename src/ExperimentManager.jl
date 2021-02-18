module ExperimentManager


using LightGraphs
using Mongoc
using CSV
import JSON
import MPI

include("DecompositionDB/DecompositionDB.jl")
include("Generate/Generate.jl")
include("Solve/Solve.jl")
include("ReadFeatures/ReadFeatures.jl")
include("utils/chordalextension.jl")
include("utils/constructgraph.jl")
include("utils/misc.jl")

struct ExperimentManager
    instances::Mongoc.Collection
    decompositions::Mongoc.Collection
end

function ExperimentManager(port::String="mongodb://localhost:27017")
    client = Mongoc.Client(port)
    try
        Mongoc.ping(client)
    catch err
        if isa(err, MethodError)
            error("You need to have a MongoDB daemon running.")
        end
    end
    instances = DecompositionDB.getcollection("choleskyexp", "instances", client)
    decompositions = DecompositionDB.getcollection("choleskyexp", "decompositions", client)
    return ExperimentManager(instances, decompositions)
end

include("./getfeatures.jl")
include("./loadinstance.jl")
include("./generate.jl")
include("./solve.jl")


end # module
