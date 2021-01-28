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
