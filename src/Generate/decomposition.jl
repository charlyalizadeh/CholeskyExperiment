"""
    get_decomposition(graph::AbstractGraph)

Generate the cliques decomposition of `graph` and returns the cliques, number of edges added to get a chordal graph
and the resulted chordal graph.
"""
function get_decomposition(graph::AbstractGraph)
    chordal_graph, nb_added_edges = get_cholesky_graph(graph)
    cliques = get_maximal_cliques(chordal_graph)
    return cliques, nb_added_edges, chordal_graph
end
