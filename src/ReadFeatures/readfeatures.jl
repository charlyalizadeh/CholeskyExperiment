"""
    getfeatures_graph(graph::AbstractGraph, vweights=ones(nv(graph)))

Get the graph features `graph`. Some features (denoted (w)) can be weighted per vertex using `vweights`.
Those features are:
    * Number of vertex
    * Number of edges
    * Degree mean (w)
    * Degree variation (w)
    * Degree max
    * Degree min
    * Density
"""
function getfeatures_graph(graph::AbstractGraph, vweights=ones(nv(graph)))
    graph_features = Dict()
    graph_features["nv"] = nv(graph)
    graph_features["ne"] = ne(graph)
    graph_features["degree_mean"] = mean(degree(graph), weights(vweights))
    graph_features["degree_var"] = var(degree(graph), weights(vweights))
    graph_features["degree_max"] = Δ(graph)
    graph_features["degree_min"] = δ(graph)
    graph_features["density"] = density(graph)
    return graph_features
end

"""
    getfeatures_cliques(graph::AbstractGraph, cliques, cweights=ones(length(cliques)))

Get the cliques features of `graph`. Some features (denoted (w)) can be weighted per vertex using `vweights`.
Those features are:
    * Number of cliques
    * Clique size mean (w)
    * Clique size variation (w)
    * Clique size max
    * Clique size min
"""
function getfeatures_cliques(graph::AbstractGraph, cliques, cweights=ones(length(cliques)))
    cliques_features = Dict()
    cliques_features["nb"] = length(cliques)
    cliques_size = [length(clique) for clique in cliques]
    cliques_features["size_mean"] = mean(cliques_size, weights(cweights)) 
    cliques_features["size_var"] = var(cliques_size, weights(cweights)) 
    cliques_features["size_max"] = maximum(cliques_size) 
    cliques_features["size_min"] = minimum(cliques_size) 
    return cliques_features
end

"""
    getfeatures_kernel(graph::AbstractGraph, vweights=ones(nv(graph)))

Get the kernel features of `graph`. The kernel being a subgraph of `graph` those features corresponds to graph features.
See also [`get_graph_features`].
"""
function getfeatures_kernel(graph::AbstractGraph, vweights=ones(nv(graph)))
    kernel_graph = kernel(graph)
    return get_graph_features(kernel_graph)
end

"""
    getfeatures_OPF(path_matpower)

Get the OPF features from a matpower file.
Those features are:
    * The generators costs
    * The loads
    * The shunts
    * The voltage bounds
    * The realpower bounds
    * The max current
    * The generators density
"""
function getfeatures_OPF(path_matpower)
    costs_generators, loads, shunts, bounds_voltage, bounds_realpower, bounds_imagpower, max_current, generator_density = get_data_OPF(path_matpower)
    costs_generators = [[parse(Int, key[5:end]), costs_generators[key]...] for key in keys(costs_generators)]
    shunts = [[parse(Int, key[5:end]), real(shunts[key]), imag(shunts[key])] for key in keys(shunts)]
    loads = [[parse(Int, key[5:end]), real(loads[key]), imag(loads[key])] for key in keys(loads)]
    bounds_voltage = [[parse(Int, key[5:end]), bounds_voltage[key]...] for key in keys(bounds_voltage)]
    bounds_realpower = [[parse(Int, key[5:end]), bounds_realpower[key]...] for key in keys(bounds_realpower)]
    max_current = [[parse(Int, key[1][5:end]), parse(Int, key[2][5:end]), max_current[key]] for key in keys(max_current)]
    features = Dict("costs_generators" => costs_generators,
                    "loads" => loads,
                    "shunts" => shunts,
                    "bounds_voltage" => bounds_voltage,
                    "bounds_realpower" => bounds_realpower,
                    "max_current" => max_current,
                    "generator_density" => generator_density
                   )
    return features
end

"""
    get_data_OPF(instance_path::String)

Retrieve the OPF related data from a matpower file.
"""
function get_data_OPF(instance_path::String)
    data = load_matpower(instance_path)
    costs_generators = Dict{String, Tuple{Float64, Float64}}() # bus g => (cg, kg)
    loads = Dict{String, Complex}() # bus => Sl= Pl + im*Ql
    shunts = Dict{String, Complex}() # bus n => g - im *b
    bounds_voltage = Dict{String, Tuple{Float64, Float64}}() # bus => (vmin, vmax)
    bounds_realpower = Dict{String, Tuple{Float64, Float64}}() # bus => (Pmin, Pmax)
    bounds_imagpower = Dict{String, Tuple{Float64, Float64}}() # bus => (Qmin, Qmax)
    max_current = Dict{Tuple{String, String}, Float64}() # line=(bus, bus) => imax
    bus_id_line=SortedDict{Int, Int}()
    bus_id_name=SortedDict{Int, String}()
    checkfor(data, 2, "mpc.baseMVA")
    baseMVA = data[2, 3]
    ## Building bus load and shunt information
    i_debut, i_fin = find_numarray(1, data)
    bustype = data[i_debut:i_fin, 2]                # weather bus is 1:"PQ" (generators are not accounted for) or 2:"PV"
    checkfor(data, i_debut-1, "mpc.bus")
    for i in i_debut:i_fin
        id = i-i_debut+1
        busname = "BUS_$id"
        bounds_voltage[busname] = (data[i, 13], data[i, 12])
        loads[busname] = data[i, 3] + im * data[i, 4]
        if data[i, 5] == data[i, 6] == 0
            #no shunts
        else
            shunts[busname] = data[i, 5] - im * data[i, 6]
        end
        bus_id_line[data[i, 1]] = id
        bus_id_name[data[i, 1]] = busname
    end
    ## Adding bus generator information
    gen2bus = SortedDict{Int, Int}()
    line2busgen = SortedDict{Int, Tuple{Int, Int}}()
    i_debut, i_fin = find_numarray(i_fin + 1, data)
    checkfor(data, i_debut - 1, "mpc.gen")
    genind, prevgen = 0, 0
    for i=i_debut:i_fin
        gen2bus[i - i_debut + 1] = bus_id_line[data[i, 1]]
        busname = bus_id_name[data[i, 1]]
        S_min = S_max = 0
        if data[i, 1] == prevgen
            genind += 1
            (Pmin, Pmax) = bounds_realpower[busname]
            (Qmin, Qmax) = bounds_imagpower[busname]
            S_min = Pmin + im * Qmin
            S_max = Pmax + im * Qmax
        else
            prevgen = data[i, 1]
            genind = 1
        end
        line2busgen[i - i_debut + 1] = (data[i, 1], genind)
        if data[i, 8] > 0 #generator is on
            S_min += data[i, 10] + im * data[i, 5] #Smin = Pmin + i Qmin
            S_max += data[i, 9] + im * data[i, 4] #Smax = Pmax + i Qmax
        end
        bounds_realpower[busname] = (real(S_min), real(S_max))
        bounds_imagpower[busname] = (imag(S_min), imag(S_max))
    end
    ## building link information
    i_debut, i_fin = find_numarray(i_fin + 1, data)
    checkfor(data, i_debut - 1, "mpc.branch")
    for i=i_debut:i_fin
        if data[i, 11] == 0
            #@warn("$link $(linkname.orig)⟶$(linkname.dest) breaker out of service !")
        else
            rs, xs, bc = data[i, 3:5]
            Smax = data[i, 6]
            τ, θ = data[i, 9:10]
            if Smax != 0
                max_current[(bus_id_name[data[i, 1]], bus_id_name[data[i, 2]])] = Smax / baseMVA
            end
        end
    end
    i_debut, i_fin = find_numarray(i_fin+1, data)
    if data[i_debut - 1, 1] == "mpc.areas"
        @warn("Not loading mpc.areas data.")
        i_debut = i_fin + 1
        i_debut, i_fin = find_numarray(i_fin + 1, data)
    end
    bus_line_id = SortedDict([val=>key for (key, val) in bus_id_line])
    ## Adding generator cost information
    checkfor(data, i_debut - 1, "mpc.gencost")
    genind, cur_genind = 0, data[i_debut, 1]
    for i = i_debut:i_fin
        buslineid, _ = line2busgen[i - i_debut+1]
        busid = bus_id_line[buslineid]
        busname = "BUS_$busid"
        cost_degree = data[i, 4]
        cost_coeffs = data[i, 5:(5+cost_degree-1)]
        if cost_degree == 2
            costs_generators[busname] = (cost_coeffs[1], cost_coeffs[2])
        elseif cost_degree == 3
            costs_generators[busname] = (cost_coeffs[2], cost_coeffs[3])
        end
    end
    return costs_generators, loads, shunts, bounds_voltage, bounds_realpower, bounds_imagpower, max_current, NaN
end

