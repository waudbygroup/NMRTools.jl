# ─────────────────────────────────────────────────────────────────────────
# 3D pure-frequency NMR spectra → iso-surface contours on Axis3
#
# Two iso-surfaces by default — one positive at +level·σ and one negative
# at −level·σ (level = 20) — coloured exactly like 2D contour plots:
# `poscolor` cycles the Wong palette (or is taken from `color`/`poscolor`),
# `negcolor` is derived from it unless given. σ uses the same
# `_contour_sigma` logic as the 2D plots, so reference normalisation and
# overlays of multiple 3D spectra behave just like the 2D case.
# ─────────────────────────────────────────────────────────────────────────

const _Spec3DFreq = NMRData{T,3,
                            <:Tuple{<:FrequencyDimension,
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
                          level=20,
                          title=nothing,
                          xlabel=nothing,
                          ylabel=nothing,
                          zlabel=nothing,
                          xlims=nothing,
                          ylims=nothing,
                          zlims=nothing,
                          axis=NamedTuple(),
                          kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y, z = dims(dfwd)
    defaults = (; xreversed=false,
                yreversed=false,
                zreversed=false,
                xlabel=axislabel(x),
                ylabel=axislabel(y),
                zlabel=axislabel(z),
                title=string(something(label(spec), "")))
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, zlabel, axis)
    ax = Makie.Axis3(gp; ax_kwargs...)
    poscolor = isnothing(poscolor) ? color : poscolor
    plt = NMRTools.nmrplot!(ax, spec; normalize, poscolor, negcolor,
                            negcontours, level, kwargs...)
    _apply_axis_limits!(ax, xlims, ylims, zlims)
    return Makie.AxisPlot(ax, plt)
end

function NMRTools.nmrplot!(ax::Makie.Axis3, spec::_Spec3DFreq;
                           normalize=true,
                           color=nothing,
                           poscolor=nothing,
                           negcolor=nothing,
                           negcontours=true,
                           level=20,
                           kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y, z = dims(dfwd)
    σ = _contour_sigma(dfwd, normalize)

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
    # Makie's 3D contour (VolumeLike) wants (start, stop) endpoint tuples.
    xr = (Float64(first(data(x))), Float64(last(data(x))))
    yr = (Float64(first(data(y))), Float64(last(data(y))))
    zr = (Float64(first(data(z))), Float64(last(data(z))))

    plt_pos = Makie.contour!(ax, xr, yr, zr, vol;
                             levels=[level * σ], color=poscolor_c, kwargs...)
    if negcontours
        Makie.contour!(ax, xr, yr, zr, -vol;
                       levels=[level * σ], color=negcolor_c, kwargs...)
    end

    return plt_pos
end

# Count Contour plots already on the Axis3 (pos+neg per spectrum) so the
# Wong colour cycle advances across successive `nmrplot!` overlays.
function _existing_3d_count(ax::Makie.Axis3)
    n = 0
    for p in ax.scene.plots
        p isa Makie.Contour && (n += 1)
    end
    return n ÷ 2
end

# ─────────────────────────────────────────────────────────────────────────
# Vector of 3D spectra (overlay)
# ─────────────────────────────────────────────────────────────────────────

function NMRTools.nmrplot(v::AbstractVector{<:_Spec3DFreq};
                          figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], v; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          v::AbstractVector{<:_Spec3DFreq};
                          normalize=true,
                          color=nothing,
                          colors=nothing,
                          negcolors=nothing,
                          colormap=nothing,
                          negcontours=true,
                          level=20,
                          title=nothing,
                          xlabel=nothing,
                          ylabel=nothing,
                          zlabel=nothing,
                          xlims=nothing,
                          ylims=nothing,
                          zlims=nothing,
                          axis=NamedTuple(),
                          kwargs...)
    isempty(v) && throw(ArgumentError("nmrplot: empty spectrum vector"))
    dfwd0 = reorder(first(v), ForwardOrdered)
    x0, y0, z0 = dims(dfwd0)
    defaults = (; xreversed=false,
                yreversed=false,
                zreversed=false,
                xlabel=axislabel(x0),
                ylabel=axislabel(y0),
                zlabel=axislabel(z0),
                title="")
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, zlabel, axis)
    ax = Makie.Axis3(gp; ax_kwargs...)

    n = length(v)
    colors = isnothing(colors) ? color : colors
    poscolors = _series_poscolors(colors, n; colormap)
    negc = _series_negcolors(negcolors, poscolors)
    refnorm = (normalize === true) ? first(v) : normalize

    local first_plt
    for (i, d) in enumerate(v)
        plt = NMRTools.nmrplot!(ax, d; normalize=refnorm, poscolor=poscolors[i],
                                negcolor=negc[i], negcontours, level, kwargs...)
        i == 1 && (first_plt = plt)
    end
    _apply_axis_limits!(ax, xlims, ylims, zlims)
    return Makie.AxisPlot(ax, first_plt)
end
