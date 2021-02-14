using LightGraphs, MetaGraphs, LinearAlgebra, SparseArrays, SuiteSparse

function load_matpower(filename)
    instance_name = split(filename, '.')[1]
    touch(instance_name*".temp")
    f = open(filename)
    out = open(instance_name*".temp", "w")
    # removing all ';' at end of lines
    while !eof(f)
        line = readline(f)
        if length(line) > 0 && line[1] != '%' && line[1] != 'f'
            s = split(line, ";")
            println(out, s[1])
        end
    end
    close(f)
    close(out)
    data = DelimitedFiles.readdlm(instance_name*".temp")
    rm(instance_name*".temp")
    return data
end

function find_numarray(i_start, data)
    i_debut = i_start
    while !isa(data[i_debut, 1], Int)
        i_debut+=1
    end
    i_fin=i_debut
    while !isa(data[i_fin,1], SubString)
        i_fin += 1
    end
    i_debut, i_fin-1
end

function checkfor(data, line_ind, name) 
    (data[line_ind, 1] == name) || error("Expected ", name, " at line ", line_ind, ", got ", data[line_ind,1], " instead.")
end

function read_sparsity_pattern(instance_path::String)
    data = load_matpower(instance_path)
    ## Bus load and shunt information
    i_debut, i_fin = find_numarray(1, data)
    checkfor(data, i_debut-1, "mpc.bus")
    nb_bus = i_fin-i_debut+1
    index_bus = Dict( data[i+i_debut-1,1] => i for i=1:nb_bus)
    ## Bus generator information
    i_debut, i_fin = find_numarray(i_fin+1, data)
    checkfor(data, i_debut-1, "mpc.gen")
    #initialize network graph G
    sp = spzeros(nb_bus,nb_bus)
    ## Link information
    i_debut, i_fin = find_numarray(i_fin+1, data)
    checkfor(data, i_debut-1, "mpc.branch")
    for i=i_debut:i_fin
        if data[i, 11] == 0
        #@warn("link $(data[i,1])⟶$(data[i,2]) breaker out of service !")
        else
            orig = index_bus[data[i,1]]
            dest = index_bus[data[i,2]]
            sp[orig,dest] = 1
        end
    end
    sp_sym = sp + sp'
    diag = zeros(nb_bus)
    for i=1:nb_bus
        sum_col = sum(sp_sym[i,:])
        diag[i] = Int(sum_col + 1)
    end
    return sp_sym + Diagonal(diag)
    # return sp+sp'+nb_bus*sparse(I, nb_bus, nb_bus)
end

function read_sparsity_pattern(graph::AbstractGraph)
    sparsity_pattern = adjacency_matrix(graph)
    for i in 1:nv(graph)
        sparsity_pattern[i, i] = length(neighbors(graph, i)) + 1
    end
    return sparsity_pattern
end

function chordal_ext_cholesky(sparsity_pattern)
    A = sparsity_pattern
    nb_edges_A = (nnz(A) - size(A,1))/2
    #computing cholesky factorisation of A NOTE: AMD ordering by default
    F = cholesky(A) #NOTE: order = F.p
    # computing L + LT
    L = sparse(F.L)
    nb_edges_L = nnz(L) - size(A,1)
    nb_added_edges = nb_edges_L - nb_edges_A
    SP = L + L'
    #inverting permutation to get chordal extension of sparsity_pattern
    H = SP[invperm(F.p), invperm(F.p)]
    return H, F.p, nb_added_edges
end

function construct_graph_from_matrix(L)
    n = size(L,1)
    H = MetaGraph(n)
    for i in 1:n
        set_props!(H, i, Dict(:name => "node$i"))
    end
    for i in 1:n
        for j in 1:i
            if L[i,j] != 0
                MetaGraphs.add_edge!(H,i,j)
            end
        end
    end
    return H
end

function chordal_ext_cholesky(graph::AbstractGraph)
    sparsity_pattern = read_sparsity_pattern(graph)
    return chordal_ext_cholesky(sparsity_pattern)
end

function get_cholesky_graph(graph::AbstractGraph)
    matrix, permutation, nb_added_edges = chordal_ext_cholesky(graph)
    return construct_graph_from_matrix(matrix), nb_added_edges
end
