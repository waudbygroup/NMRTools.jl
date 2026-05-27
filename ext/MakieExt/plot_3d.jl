# ─────────────────────────────────────────────────────────────────────────
# 3D pure-frequency NMR spectra → iso-surface contours on Axis3
# ─────────────────────────────────────────────────────────────────────────

const _Spec3DFreq = NMRData{T,3,<:Tuple{<:FrequencyDimension,
                                         <:FrequencyDimension,
                                         <:FrequencyDimension}} where {T}

function NMRTools.nmrplot(spec::_Spec3DFreq; figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], spec; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          spec::_Spec3DFreq;
                          normalize=true,
                          color=nothing,
                          poscolor=nothing,
                          negcolor=nothing,
                          negcontours=true,
                          base_level=10,
                          nlevels=3,
                          alpha=0.3,
                          title=nothing,
                          xlabel=nothing,
                          ylabel=nothing,
                          zlabel=nothing,
                          axis=NamedTuple(),
                          kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y, z = dims(dfwd)
    defaults = (; xreversed=true,
                yreversed=true,
                zreversed=true,
                xlabel=axislabel(x),
                ylabel=axislabel(y),
                zlabel=axislabel(z),
                title=string(something(label(spec), "")))
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, zlabel, axis)
    ax = Makie.Axis3(gp; ax_kwargs...)
    poscolor = isnothing(poscolor) ? color : poscolor
    plt = NMRTools.nmrplot!(ax, spec; normalize, poscolor, negcolor,
                            negcontours, base_level, nlevels, alpha, kwargs...)
    return Makie.AxisPlot(ax, plt)
end

function NMRTools.nmrplot!(ax::Makie.Axis3, spec::_Spec3DFreq;
                           normalize=true,
                           color=nothing,
                           poscolor=nothing,
                           negcolor=nothing,
                           negcontours=true,
                           base_level=10,
                           nlevels=3,
                           alpha=0.3,
                           kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y, z = dims(dfwd)
    _, σ = _resolve_normalize(dfwd, normalize)

    poscolor = isnothing(poscolor) ? color : poscolor
    if isnothing(poscolor)
        pal = _theme_palette()
        idx = _existing_3d_count(ax) + 1
        poscolor_c = _parse_colorant(pal[mod1(idx, length(pal))])
    else
        poscolor_c = _parse_colorant(poscolor)
    end
    negcolor_c = isnothing(negcolor) ? _derive_negcolor(poscolor_c) :
                 _parse_colorant(negcolor)

    vol = _realdata(dfwd)
    pos_levels = [base_level * σ * 1.7^i for i in 0:(nlevels - 1)]
    # Makie's 3D contour expects (start, stop) endpoint tuples for each
    # axis, not full coordinate vectors (VolumeLike convention).
    xr = (Float64(first(data(x))), Float64(last(data(x))))
    yr = (Float64(first(data(y))), Float64(last(data(y))))
    zr = (Float64(first(data(z))), Float64(last(data(z))))
    plt_pos = Makie.contour!(ax, xr, yr, zr, vol;
                             levels=pos_levels, color=poscolor_c, alpha=alpha,
                             kwargs...)
    if negcontours
        neg_levels = [-l for l in reverse(pos_levels)]
        Makie.contour!(ax, xr, yr, zr, vol;
                       levels=neg_levels, color=negcolor_c, alpha=alpha,
                       kwargs...)
    end
    return plt_pos
end

# Count Volume/Contour plots already in the Axis3 to advance the cycler
# across successive `nmrplot!` calls on 3D spectra.
function _existing_3d_count(ax::Makie.Axis3)
    n = 0
    for p in ax.scene.plots
        p isa Makie.Contour && (n += 1)
    end
    return n ÷ 2
end
