# In this script we want to find all the decompositions unsolved in the database and solve them.
# The basic idea is that we split the decompositions between the different task thanks to the MPI API.
# The problem is that the MPI API is more efficient if we use basic data type for the send and revieve provess
# (because it will knows the byte size of the data sent, at least that's what I understood)
# and the minimal way to uniquely identify a decomposition in the database is to use the instance name and the list of 
# added edges. But the added edges field is an array of array of int. And the size of this array can vary from one decompositions
# to another. We have two possibles solutions to this problem.
#   -> We use an hash function to generate the id of the decompositions in the form `hash(instance_name, added_edges) = decahsh`.
#      This will let us uniquely identify a decomposition thanks to a string. Therefore we could send an array of string to a task
#      in order to tell to the task which decompositions it needs to solve. But I'm not sure if an hash function to hash 
#      long array of array of integers exists, I'll have to look into that.
#   -> We retrieve the index of the unsolved decompositions in the array of BSON document that the ExperimentManager stores in manager.decompositions 
#      (using collect to convert it to an array). This solution is far from being elegent but it's easier and faster to implement.
# In the following script I choose the second solution. The first solution is a very good solution but I need some results in two days and don't have the time
# to implement it (on paper it sounds simple to implement but I feel it's quite a rabbit hole, maybe I'm wrong)
#
# Edit: I realize that even with an hash function I'm not sure I can use MPI to send array of string. Maybe if I send an array of fixed size string.

"""
    mpigenerate(manager::ExperimentManager)

Generate decompositions using MPI and the options specified in the file `configfile`
"""
function mpigenerate(manager::ExperimentManager, configfile::String="./config.json")
    MPI.Init()
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    size = MPI.Comm_size(comm)
    @info "Rank: $rank"
    rank == 0 && (@info "Size: $size")
    #run(`lsof`)
    manager = ExperimentManager("mongodb://$(ARGS[1]):27017")
    Mongoc.ping(Mongoc.Client("mongodb://$(ARGS[1]):27017"))
    @info "[$rank] Connected to mongodb://$(ARGS[1]):27017)"
    root = 0
    if rank == root
        paths_matpower = collect(DecompositionDB.getmatpowerpath_all(manager.instances))
        paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
        @info "[$rank] Spliting the generation between the taks"
        nb_instance_by_task = trunc(Int, length(paths_matpower) / size)
        @info "[$rank] Tasks: $size"
        @info "[$rank] Instance(s: $(length(paths_matpower))"
        @info "[$rank] Instance(s by taks: $(nb_instance_by_task)"
        if length(paths_matpower) < size
            size = length(paths_matpower)
            nb_instance_by_task = 1
        end
        for i in 1:size
            start = (i - 1) * nb_instance_by_task + 1
            if i == size
                stop = length(paths_matpower)
            else
                stop = i * nb_instance_by_task
            end
            @info "[$rank] Rank $i: $start => $stop"
            MPI.Isend([start, stop], i - 1, 0, comm)
        end
    end
    MPI.Barrier(comm)
    paths_matpower = collect(DecompositionDB.getmatpowerpath_all(manager.instances))
    paths_matpower = [path["paths"]["matpower"] for path in paths_matpower]
    @info "[$rank] Retrieving number of instances"
    status = MPI.Probe(0, 0, comm)
    count = MPI.Get_count(status, Int)
    @info "[$rank] Count: $count"
    paths_matpower_index = Array{Int}(undef, count)
    @info "[$rank] Retrieving decompositions indexes"
    MPI.Irecv!(paths_matpower_index, 0, 0, comm)
    start, stop = paths_matpower_index
    @info "[$rank] Generating..."
    generate_decomposition_mult(manager, configfile, paths_matpower[start:stop], rank; verbose=true)
    MPI.Finalize()
end

"""
    mpisolve(manager::ExperimentManager)

Solve decompositions using MPI.
"""
function mpisolve(manager::ExperimentManager; resolve=false, cholesky=false)
    MPI.Init()
    comm = MPI.COMM_WORLD
    manager = ExperimentManager("mongodb://$(ARGS[1]):27017")
    root = 0
    rank = MPI.Comm_rank(comm)
    size = MPI.Comm_size(comm)

    # Send data to all other comm
    if rank == root
        @info "[$rank] Spliting resolution between the tasks"
        decompositions_index = DecompositionDB.getdecompositions_index(manager.decompositions; unsolved=!resolve, cholesky=cholesky)
        nb_decomposition = length(decompositions_index)
        nb_decomposition_by_task = trunc(Int, nb_decomposition/ size)
        @info "[$rank]    Tasks: $size"
        @info "[$rank]    Decomposition(s): $nb_decomposition"
        if length(decompositions_index) < size
            size = length(decompositions_index)
            nb_instance_by_task = 1
        end
        @info "[$rank]    Decomposition(s) by taks: $nb_decomposition_by_task"
        for i in 1:size
            start = (i - 1) * nb_decomposition_by_task + 1
            stop = i * nb_decomposition_by_task
            stop = stop > nb_decomposition ? nb_decomposition : stop
            if i == size
                stop = nb_decomposition
            end
            @info typeof(decompositions_index)
            @info "[$rank] [$(i - 1)]: $start -> $stop"
            MPI.Isend(decompositions_index[start:stop], i - 1, 0, comm)
        end
    end
    #@info "[$rank] Retrieving number of decompositions"
    status = MPI.Probe(0, 0, comm)
    count = MPI.Get_count(status, Int)
    #@info "[$rank] Count: $count"
    decompositions_index = Array{Int}(undef, count)
    #@info "[$rank] Retrieving decompositions indexes"
    MPI.Irecv!(decompositions_index, 0, 0, comm)
    decompositions = collect(manager.decompositions)
    #@info "[$rank] Solving..."
    for (i, index) in enumerate(decompositions_index)
        instance_name = decompositions[index]["_id"]["instance_name"]
        added_edges::Vector{Vector{Int}} = decompositions[index]["_id"]["added_edges"]
        @info "[$rank] Solving $(instance_name): $(length(added_edges))"
        solve_decomposition(manager, instance_name, added_edges, true, resolve=resolve)
        @info "[$rank] $i / $(length(decompositions_index)) $(instance_name): $(length(added_edges)) solved."
    end
    MPI.Barrier(comm)
    MPI.Finalize()
end
