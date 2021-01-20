using LightGraphs

"""
    degreeisgreater(graph::AbstractGraph, vertex, deg)

Check if the degree of `vertex` is greater than `deg`.
"""
function degreeisgreater(graph::AbstractGraph, vertex, deg)
    return degree(graph)[vertex] >= deg
end

"""
    degreeislesser(graph::AbstractGraph, vertex, deg)

Check if the degree of `vertex` is lesser than `deg`.
"""
function degreeislesser(graph::AbstractGraph, vertex, deg)
    return degree(graph)[vertex] <= deg
end

"""
    degreeis(graph::AbstractGraph, vertex, degrees)

Check if the degree of `vertex` is contained in `degrees`.
"""
function degreeis(graph::AbstractGraph, vertex, degrees)
    return degree(graph)[vertex] in degrees
end

"""
    getmaxsize(arrays) 
    
Return the maximum size of subarrays contained in `arrays`.
"""
function getmaxsize(arrays) 
    try
        return maximum([length(array) for array in arrays])
    catch err
        if isa(err, ArgumentError)
            return -1
        end
    end
end

"""
    getminsize(arrays) 
    
Return the minimum size of subarrays contained in `arrays`.
"""
function getminsize(arrays)  
    try
        return minimum([length(array) for array in arrays])
    catch err
        if isa(err, ArgumentError)
            return -1 
        end
    end
end


"""
    getsubset(arrays, values)

Return the subset of arrays contained in `arrays` wich contains `values`.
"""
function getsubset(arrays, values)
    return filter(array -> issubset(values, array), arrays)
end
