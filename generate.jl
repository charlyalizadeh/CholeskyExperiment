include("ExperimentManager.jl")
import MPI
import JSON


println("Inside")
MPI.Init()
comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
size = MPI.Comm_size(comm)
println("Rank: $rank")
println("Size: $size")
#run(`lsof`)
manager = ExperimentManager("mongodb://$(ARGS[1]):27017")
Mongoc.ping(Mongoc.Client("mongodb://$(ARGS[1]):27017"))
println("mongodb://$(ARGS[1]):27017")
root = 0

if rank == root
    paths_matpower = collect(DecompositionDB.get_all_matpower_path(manager.instances))
    paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
    println("[$rank] Spliting the generation between the taks")
    nb_instance_by_task = trunc(Int, length(paths_matpower) / size)
    println("[$rank] Tasks: $size")
    println("[$rank] Instance(s): $(length(paths_matpower))")
    println("[$rank] Instance(s) by taks: $(nb_instance_by_task)")
    for i in 1:size
        start = (i - 1) * nb_instance_by_task + 1
        if i == size
            stop = length(paths_matpower)
        else
            stop = i * nb_instance_by_task
        end
        println("[$rank] Stop: $stop   Start: $start")
        MPI.Isend([start, stop], i - 1, 0, comm)
    end
end
MPI.Barrier(comm)

paths_matpower = collect(DecompositionDB.get_all_matpower_path(manager.instances))
paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
println("[$rank] Retrieving number of instances")
status = MPI.Probe(0, 0, comm)
count = MPI.Get_count(status, Int)
println("[$rank] Count: $count")
paths_matpower_index = Array{Int}(undef, count)
println("[$rank] Retrieving decompositions indexes")
MPI.Irecv!(paths_matpower_index, 0, 0, comm)
start, stop = paths_matpower_index
println("[$rank] Generating...")
generate_decomposition_mult(manager, "/home/dist/charly-kyan.alizadeh/config.json", paths_matpower[start:stop])
