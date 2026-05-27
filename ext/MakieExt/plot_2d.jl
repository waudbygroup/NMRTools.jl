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
                          xprojection=nothing,
                          yprojection=nothing,
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

    has_xproj = !isnothing(xprojection)
    has_yproj = !isnothing(yprojection)
    if has_xproj || has_yproj
        ax = _build_2d_with_projections!(gp, spec, ax_kwargs;
                                         xprojection, yprojection, normalize)
    else
        ax = Makie.Axis(gp; ax_kwargs...)
    end

    poscolor = isnothing(poscolor) ? color : poscolor
    plt = NMRTools.nmrplot!(ax, spec; normalize, poscolor, negcolor,
                            negcontours, kwargs...)
    _apply_contour_legend!(ax, legend,
                           [string(something(NMRTools.label(spec), ""))],
                           [plt.color[]])
    return Makie.AxisPlot(ax, plt)
end

# Build a main Axis with optional top (x) and right (y) projection strips
# inside a nested GridLayout. Returns the main Axis.
function _build_2d_with_projections!(gp, spec, main_ax_kwargs;
                                     xprojection, yprojection, normalize)
    has_xproj = !isnothing(xprojection)
    has_yproj = !isnothing(yprojection)
    gl = Makie.GridLayout(gp; rowgap=2, colgap=2)
    main_row = has_xproj ? 2 : 1
    ax = Makie.Axis(gl[main_row, 1]; main_ax_kwargs...)

    if has_xproj
        ax_top = Makie.Axis(gl[1, 1]; xreversed=true)
        _plot_xprojection!(ax_top, spec, xprojection, normalize)
        Makie.hidedecorations!(ax_top)
        Makie.hidespines!(ax_top)
        Makie.linkxaxes!(ax_top, ax)
        Makie.rowsize!(gl, 1, Makie.Relative(0.18))
        # Suppress main axis title (use top strip's space instead if title set).
    end

    if has_yproj
        ax_right = Makie.Axis(gl[main_row, 2]; yreversed=true)
        _plot_yprojection!(ax_right, spec, yprojection, normalize)
        Makie.hidedecorations!(ax_right)
        Makie.hidespines!(ax_right)
        Makie.linkyaxes!(ax_right, ax)
        Makie.colsize!(gl, 2, Makie.Relative(0.18))
    end

    return ax
end

function _plot_xprojection!(ax_top, spec_2d, proj, normalize)
    if proj isa AbstractNMRData
        Afwd = reorder(proj, ForwardOrdered)
        sf, _ = _resolve_normalize(Afwd, normalize)
        x = data(dims(Afwd, 1))
        y = _realdata(Afwd) ./ sf
    else
        dfwd = reorder(spec_2d, ForwardOrdered)
        x = data(dims(dfwd, 1))
        z = _realdata(dfwd)
        reducer = _resolve_projection_reducer(proj)
        y = vec(reducer(z; dims=2))
    end
    return Makie.lines!(ax_top, x, y; color=:black)
end

function _plot_yprojection!(ax_right, spec_2d, proj, normalize)
    if proj isa AbstractNMRData
        Afwd = reorder(proj, ForwardOrdered)
        sf, _ = _resolve_normalize(Afwd, normalize)
        y = data(dims(Afwd, 1))
        x = _realdata(Afwd) ./ sf
    else
        dfwd = reorder(spec_2d, ForwardOrdered)
        y = data(dims(dfwd, 2))
        z = _realdata(dfwd)
        reducer = _resolve_projection_reducer(proj)
        x = vec(reducer(z; dims=1))
    end
    return Makie.lines!(ax_right, x, y; color=:black)
end

function _resolve_projection_reducer(proj)
    proj === true && return maximum
    proj === :max && return maximum
    proj === :sum && return sum
    proj isa Function && return proj
    throw(ArgumentError("projection must be true, :max, :sum, a function, or a 1D NMRData"))
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
    if isnothing(poscolor)
        pal = _theme_palette()
        idx = _existing_2d_count(ax) + 1
        poscolor_c = _parse_colorant(pal[mod1(idx, length(pal))])
    else
        poscolor_c = _parse_colorant(poscolor)
    end
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
    labels = String[]
    for (i, d) in enumerate(v)
        dfwd = reorder(d, ForwardOrdered)
        x, y = dims(dfwd)
        _, σ = _resolve_normalize(dfwd, refnorm)
        z = _realdata(dfwd)
        pos_levels = collect(5σ .* contourlevels())
        plt_pos = Makie.contour!(ax, data(x), data(y), z;
                                 levels=pos_levels, color=poscolors[i],
                                 kwargs...)
        i == 1 && (first_plt = plt_pos)
        push!(labels, string(something(NMRTools.label(dfwd), "")))
        if negcontours
            neg_levels = collect(-5σ .* reverse(collect(contourlevels())))
            Makie.contour!(ax, data(x), data(y), z;
                           levels=neg_levels, color=negc[i],
                           kwargs...)
        end
    end
    _apply_contour_legend!(ax, legend, labels, poscolors)
    return Makie.AxisPlot(ax, first_plt)
end
