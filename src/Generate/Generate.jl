module Generate


using LightGraphs
using Random
import Base:occursin

include("../utils/filters.jl")
include("../utils/maximalcliques.jl")
include("../utils/misc.jl")
include("../utils/chordalextension.jl")
include("filteredges.jl")

export filter_vertices_degree_max, filter_vertices_degree_min, filter_vertices_degree,
       filter_vertices_size_biggest_clique_max, filter_vertices_size_biggest_clique_min, filter_vertices_size_biggest_clique,
       filter_vertices_size_smallest_clique_max, filter_vertices_size_smallest_clique_min, filter_vertices_size_smallest_clique,
       filter_vertices_distance_max, filter_vertices_distance_min, filter_vertices_distance,
       filter_vertices_same_clique, filter_vertices_no_same_clique,
       filter_vertices_no_edge, filter_vertices_has_edge

include("addedges.jl")

export add_edges_by!

include("decomposition.jl")

export get_decomposition


end # module
