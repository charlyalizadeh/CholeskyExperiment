using LightGraphs: degree, vertices, rem_vertex!
using DelimitedFiles

"""
source: https://discourse.julialang.org/t/get-the-argument-names-of-an-function/32902/3
I modified this function to retrieve the keyword arguments.
"""
function method_argnames(m::Method)
    argnames = ccall(:jl_uncompress_argnames, Vector{Symbol}, (Any,), m.slot_syms)
    isempty(argnames) && return argnames
    return argnames[m.nargs:end]
end

function fill_options_arguments(options, graph)
    # TODO: I don't know what but I need to do something for this line
    filled_options = Dict(key => convert(Dict{Symbol,Union{Int64, Base.OneTo{Int64}, AbstractGraph, Array{Int}, Array{Any}}}, val) for (key, val) in options)
    for option in collect(keys(filled_options))
        ms = collect(methods(Generation.dst_options[option]))
        argnames = Generation.method_argnames(last(ms))[2:end]
        cliques_arg = :cliques in argnames
        choleskygraph_arg = :choleskygraph in argnames
        if cliques_arg || choleskygraph_arg
            if !cliques_arg
                filled_options[option][:choleskygraph] = SimpleGraph(get_cholesky_graph(graph)[1])
            else
                cliques, nb_added_edges, choleskygraph = Generation.get_decomposition(graph)
                filled_options[option][:cliques] = cliques
                choleskygraph_arg && (filled_options[option][:choleskygraph] = SimpleGraph(choleskygraph))
            end
        end
        if :graph in argnames
            filled_options[option][:graph] = graph
        end
    end
    return filled_options
end

function remove_vertices_by_degree!(graph::G, deg=1) where G<:AbstractGraph
    graphdegrees = degree(graph)
    for vertex in filter(x -> graphdegrees[x] == deg, vertices(graph))
        rem_vertex!(graph, vertex)
    end
end

function kernel(graph::AbstractGraph)
    kernel_graph = copy(graph)
    remove_vertices_by_degree!(kernel_graph)
    remove_vertices_by_degree!(kernel_graph)
    return kernel_graph
end

function kernel!(graph::AbstractGraph)
    remove_vertices_by_degree!(graph)
    remove_vertices_by_degree!(graph)
end

function find_numarray(i_start, data)
    i_debut = i_start
    while !isa(data[i_debut, 1], Int)
        i_debut += 1
    end
    i_fin=i_debut
    while !isa(data[i_fin, 1], SubString)
        i_fin += 1
    end
    i_debut, i_fin - 1
end

checkfor(data, line_ind, name) = (data[line_ind, 1] == name) || error("Expected ", name, " at line ", line_ind, ", got ", data[line_ind, 1], " instead.")

function load_matpower(filename)
    instance_name = split(filename, '.')[1]
    touch(instance_name * ".temp")
    f = open(filename)
    out = open(instance_name * ".temp", "w")
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

    data = DelimitedFiles.readdlm(instance_name * ".temp")
    rm(instance_name * ".temp")
    return data
end
