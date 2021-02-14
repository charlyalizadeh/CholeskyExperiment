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

include("repos/CholeskyExperiment/ExperimentManager.jl")
import MPI


MPI.Init()
comm = MPI.COMM_WORLD
manager = ExperimentManager("mongodb://$(ARGS[1]):27017")
root = 0
rank = MPI.Comm_rank(comm)
size = MPI.Comm_size(comm)

# Send data to all other comm
if rank == root
    @info "[$rank] Spliting resolution between the tasks"
    decompositions_index = DecompositionDB.get_unsolved_decompositions_index(manager.decompositions)
    nb_decomposition_unsolved = length(decompositions_index)
    nb_decomposition_by_task = nb_decomposition_unsolved / size
    @info "[$rank]    Tasks: $size"
    @info "[$rank]    Decomposition(s): $nb_decomposition_unsolved"
    @info "[$rank]    Decomposition(s) by taks: $nb_decomposition_by_task"
    for i in 1:size
        start = (i - 1) * nb_decomposition_by_task + 1
        stop = i * nb_decomposition_by_task
        stop = stop > nb_decomposition_unsolved ? nb_decomposition_unsolved : stop
        MPI.Isend(decompositons_index[start:stop], i - 1, 0, comm)
    end
end
MPI.Barrier(comm)

@info "[$rank] Retrieving number of decompositions"
status = MPI.Probe(0, 0, comm)
count = MPI.Get_count(status, Int)
@info "[$rank] Count: $count"
decompositions_indexes = Array{Int}(undef, count)
@info "[$rank] Retrieving decompositions indexes"
MPI.Irecv!(decompositions_indexes, 0, 0, comm)
decompositions = collect(manager.decompositions)
@info "[$rank] Solving..."
for index in decompositions_indexes
    instance_name = decompositions[index]["_id"]["instance_name"]
    added_edges = decompositions[index]["_id"]["added_edges"]
    solve_decomposition(manager, instance_name, added_edges)
end