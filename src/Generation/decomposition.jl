function get_decomposition(graph::AbstractGraph)
    chordal_graph, nb_added_edges = get_cholesky_graph(graph)
    cliques = get_maximal_cliques(chordal_graph)
    return cliques, nb_added_edges, chordal_graph
end
