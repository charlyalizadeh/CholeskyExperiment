"""
source: https://discourse.julialang.org/t/get-the-argument-names-of-an-function/32902/3
I modified this function to retrieve the keyword arguments.
"""
function method_argnames(m::Method)
    argnames = ccall(:jl_uncompress_argnames, Vector{Symbol}, (Any,), m.slot_syms)
    isempty(argnames) && return argnames
    return argnames[m.nargs:end]
end

