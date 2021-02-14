using DelimitedFiles, LightGraphs


function find_numarray(i_start, data)
    i_debut = i_start
    while !isa(data[i_debut, 1], Int)
        i_debut += 1
    end
    i_fin=i_debut
    while !isa(data[i_fin,1], SubString)
        i_fin += 1
    end
    i_debut, i_fin - 1
end

checkfor(data, line_ind, name) = (data[line_ind, 1] == name) || error("Expected ", name, " at line ", line_ind, ", got ", data[line_ind,1], " instead.")

function get_names_buses(data, nb_bus)
    index = 1
    while data[index, 1] != "mpc.bus_name"
        index += 1
    end
    index += 1
    names = [join(data[i, :]) for i in index:index + nb_bus - 1]
    return names
end

function construct_network_graph(instance_path::String)
    "In construct_network_graph $instance_path"
    data = load_matpower(instance_path)
    ## Bus load and shunt information
    i_debut, i_fin = find_numarray(1, data)
    checkfor(data, i_debut - 1, "mpc.bus")
    nb_bus = i_fin - i_debut + 1
    index_bus = Dict( data[i + i_debut - 1,1] => i for i=1:nb_bus)
    if index_bus != Dict( i => i for i=1:nb_bus)
        #println("!!! Specific numerotation of buses !!! \n")
    end
    ## Bus generator information
    i_debut, i_fin = find_numarray(i_fin + 1, data)
    checkfor(data, i_debut - 1, "mpc.gen")
    #initialize network graph G
    G = SimpleGraph(nb_bus)
    ## Link information
    i_debut, i_fin = find_numarray(i_fin + 1, data)
    checkfor(data, i_debut - 1, "mpc.branch")
    for i=i_debut:i_fin
        if data[i, 11] == 0
        #@warn("link $(data[i,1])⟶$(data[i,2]) breaker out of service !")
        else
            orig = index_bus[data[i,1]]
            dest = index_bus[data[i,2]]
            LightGraphs.add_edge!(G, orig, dest)
        end
    end
    return G
end
