# ─────────────────────────────────────────────────────────────────────────
# 2D pure-frequency spectra → ± contour plots
# ─────────────────────────────────────────────────────────────────────────

const _Spec2DFreq = NMRData{T,2,<:Tuple{<:FrequencyDimension,
                                         <:FrequencyDimension}} where {T}

function NMRTools.nmrplot(spec::_Spec2DFreq; figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], spec; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          spec::_Spec2DFreq;
                          normalize=true,
                          color=nothing,
                          poscolor=nothing,
                          negcolor=nothing,
                          negcontours=true,
                          title=nothing,
                          xlabel=nothing,
                          ylabel=nothing,
                          legend=false,
                          axis=NamedTuple(),
                          kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    defaults = (; xreversed=true,
                yreversed=true,
                xlabel=axislabel(x),
                ylabel=axislabel(y),
                xgridvisible=false,
                ygridvisible=false,
                xtickalign=1,
                ytickalign=1,
                title=string(something(label(spec), "")))
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, axis)
    ax = Makie.Axis(gp; ax_kwargs...)
    poscolor = isnothing(poscolor) ? color : poscolor
    plt = NMRTools.nmrplot!(ax, spec; normalize, poscolor, negcolor,
                            negcontours, kwargs...)
    _apply_legend!(ax, legend)
    return Makie.AxisPlot(ax, plt)
end

function NMRTools.nmrplot!(ax::Makie.Axis, spec::_Spec2DFreq;
                           normalize=true,
                           color=nothing,
                           poscolor=nothing,
                           negcolor=nothing,
                           negcontours=true,
                           label=nothing,
                           kwargs...)
    ax.xreversed = true
    ax.yreversed = true

    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    _, σ = _resolve_normalize(dfwd, normalize)

    poscolor = isnothing(poscolor) ? color : poscolor
    poscolor_c = isnothing(poscolor) ? _theme_palette()[1] : _parse_colorant(poscolor)
    negcolor_c = isnothing(negcolor) ? _derive_negcolor(poscolor_c) :
                 _parse_colorant(negcolor)

    label_str = isnothing(label) ? string(something(NMRTools.label(dfwd), "")) :
                string(label)

    z = _realdata(dfwd)
    pos_levels = collect(5σ .* contourlevels())
    plt_pos = Makie.contour!(ax, data(x), data(y), z;
                             levels=pos_levels, color=poscolor_c,
                             label=label_str, kwargs...)
    if negcontours
        neg_levels = collect(-5σ .* reverse(collect(contourlevels())))
        Makie.contour!(ax, data(x), data(y), z;
                       levels=neg_levels, color=negcolor_c, kwargs...)
    end
    return plt_pos
end

# ─────────────────────────────────────────────────────────────────────────
# Vector of 2D pure-frequency spectra
# ─────────────────────────────────────────────────────────────────────────

function NMRTools.nmrplot(v::AbstractVector{<:_Spec2DFreq};
                          figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], v; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          v::AbstractVector{<:_Spec2DFreq};
                          normalize=true,
                          color=nothing,
                          colors=nothing,
                          negcolors=nothing,
                          colormap=nothing,
                          negcontours=true,
                          title=nothing,
                          xlabel=nothing,
                          ylabel=nothing,
                          legend=false,
                          axis=NamedTuple(),
                          kwargs...)
    isempty(v) && throw(ArgumentError("nmrplot: empty spectrum vector"))
    dfwd0 = reorder(first(v), ForwardOrdered)
    x0, y0 = dims(dfwd0)
    defaults = (; xreversed=true,
                yreversed=true,
                xlabel=axislabel(x0),
                ylabel=axislabel(y0),
                xgridvisible=false,
                ygridvisible=false,
                xtickalign=1,
                ytickalign=1,
                title="")
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, axis)
    ax = Makie.Axis(gp; ax_kwargs...)

    n = length(v)
    colors = isnothing(colors) ? color : colors
    poscolors = _series_poscolors(colors, n; colormap)
    negc = _series_negcolors(negcolors, poscolors)

    refnorm = (normalize === true) ? first(v) : normalize
    local first_plt
    for (i, d) in enumerate(v)
        dfwd = reorder(d, ForwardOrdered)
        x, y = dims(dfwd)
        _, σ = _resolve_normalize(dfwd, refnorm)
        z = _realdata(dfwd)
        pos_levels = collect(5σ .* contourlevels())
        plt_pos = Makie.contour!(ax, data(x), data(y), z;
                                 levels=pos_levels, color=poscolors[i],
                                 label=string(something(NMRTools.label(dfwd), "")),
                                 kwargs...)
        i == 1 && (first_plt = plt_pos)
        if negcontours
            neg_levels = collect(-5σ .* reverse(collect(contourlevels())))
            Makie.contour!(ax, data(x), data(y), z;
                           levels=neg_levels, color=negc[i],
                           kwargs...)
        end
    end
    _apply_legend!(ax, legend)
    return Makie.AxisPlot(ax, first_plt)
end
