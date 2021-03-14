function plotfeatures(df::DataFrame, feature_name::String)
    sort!(df, feature_name)
    groupdf = groupby(df, :instance_name)
    plots = []
    for g in groupdf
        p = plot(g[!, feature_name], g[!, "solver.solving_time"], title=g[!, "instance_name"][1])
        push!(plots, p)
    end
    plot(plots...,
         layout=length(plots),
         size = (700, 700),
         xtickfontsize=5,
         ytickfontsize=5,
         titlefontsize=5,
         legend=false)
end

function plotfeatures_all(df::DataFrame)
    colnames = filter(col -> typeof(df[!,col]) == Vector{Float64},  names(df))
    plots = []
    for feature in colnames
        sort!(df, feature)
        p = plot(df[!, feature], df[!, "solver.solving_time"], title=feature)
        push!(plots, p)
    end
    plot(plots...,
         layout=length(plots),
         size = (700, 700),
         xtickfontsize=5,
         ytickfontsize=5,
         titlefontsize=5,
         legend=false)
end

function interact(df::DataFrame)
    w = Window()
    body!(w, dataviewer(df))
end
