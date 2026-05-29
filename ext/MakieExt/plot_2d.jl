# ─────────────────────────────────────────────────────────────────────────
# 2D pure-frequency spectra → ± contour plots
# ─────────────────────────────────────────────────────────────────────────

const _Spec2DFreq = NMRData{T,2,<:Tuple{<:FrequencyDimension,
                                         <:FrequencyDimension}} where {T}

# Maps a main contour Axis to its (top, right) projection-strip axes (or
# `nothing` if absent). Used so `nmrplot!` overlays can add projection
# lines to the same strips as the original plot.
const _PROJECTION_STRIPS = WeakKeyDict{Makie.Axis,NamedTuple}()

function NMRTools.nmrplot(spec::_Spec2DFreq; figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ap = NMRTools.nmrplot(fig[1, 1], spec; kwargs...)
    return Makie.FigureAxisPlot(fig, ap.axis, ap.plot)
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
                          xlims=nothing,
                          ylims=nothing,
                          legend=false,
                          axis=NamedTuple(),
                          kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    title_str = !isnothing(title) ? title :
                string(something(label(spec), ""))
    has_xproj = !isnothing(xprojection)
    has_yproj = !isnothing(yprojection)
    main_title = has_xproj ? "" : title_str
    defaults = (; xreversed=true,
                yreversed=true,
                xlabel=axislabel(x),
                ylabel=axislabel(y),
                xgridvisible=false,
                ygridvisible=false,
                xtickalign=1,
                ytickalign=1,
                title=main_title)
    ax_kwargs = _axis_overrides(defaults; title=nothing, xlabel, ylabel, axis)

    if has_xproj || has_yproj
        ax = _build_projection_layout(gp, ax_kwargs; has_xproj, has_yproj,
                                      top_title=has_xproj ? title_str : "")
    else
        ax = Makie.Axis(gp; ax_kwargs...)
    end

    poscolor = isnothing(poscolor) ? color : poscolor
    plt = NMRTools.nmrplot!(ax, spec; normalize, poscolor, negcolor,
                            negcontours, xprojection, yprojection, kwargs...)
    _apply_contour_legend!(ax, legend,
                           [string(something(NMRTools.label(spec), ""))],
                           [plt.color[]])
    _apply_axis_limits!(ax, xlims, ylims)
    return Makie.AxisPlot(ax, plt)
end

# Create the nested GridLayout with optional projection strip axes. The
# strips are constructed with decorations hidden and linked to the main
# axis. The (top, right) strip handles are stashed in _PROJECTION_STRIPS
# so subsequent `nmrplot!` calls can overlay onto them.
function _build_projection_layout(gp, main_ax_kwargs; has_xproj, has_yproj,
                                  top_title="")
    gl = Makie.GridLayout(gp; rowgap=4, colgap=4)
    main_row = has_xproj ? 2 : 1
    ax = Makie.Axis(gl[main_row, 1]; main_ax_kwargs...)

    ax_top = nothing
    ax_right = nothing

    if has_xproj
        ax_top = Makie.Axis(gl[1, 1]; xreversed=true, title=top_title)
        # Hide everything except the title.
        Makie.hidedecorations!(ax_top)
        Makie.hidespines!(ax_top)
        Makie.linkxaxes!(ax_top, ax)
        Makie.rowsize!(gl, 1, Makie.Relative(0.18))
    end

    if has_yproj
        ax_right = Makie.Axis(gl[main_row, 2]; yreversed=true)
        Makie.hidedecorations!(ax_right)
        Makie.hidespines!(ax_right)
        Makie.linkyaxes!(ax_right, ax)
        Makie.colsize!(gl, 2, Makie.Relative(0.18))
    end

    _PROJECTION_STRIPS[ax] = (; top=ax_top, right=ax_right)
    return ax
end

function _plot_xprojection!(ax_top, spec_2d, proj, normalize, color)
    if proj isa AbstractNMRData
        Afwd = reorder(proj, ForwardOrdered)
        sf = _normalization_divisor(Afwd, normalize)
        x = data(dims(Afwd, 1))
        y = _realdata(Afwd) ./ sf
    else
        dfwd = reorder(spec_2d, ForwardOrdered)
        x = data(dims(dfwd, 1))
        z = _realdata(dfwd)
        reducer = _resolve_projection_reducer(proj)
        y = vec(reducer(z; dims=2))
    end
    return Makie.lines!(ax_top, x, y; color=color)
end

function _plot_yprojection!(ax_right, spec_2d, proj, normalize, color)
    if proj isa AbstractNMRData
        Afwd = reorder(proj, ForwardOrdered)
        sf = _normalization_divisor(Afwd, normalize)
        y = data(dims(Afwd, 1))
        x = _realdata(Afwd) ./ sf
    else
        dfwd = reorder(spec_2d, ForwardOrdered)
        y = data(dims(dfwd, 2))
        z = _realdata(dfwd)
        reducer = _resolve_projection_reducer(proj)
        x = vec(reducer(z; dims=1))
    end
    return Makie.lines!(ax_right, x, y; color=color)
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
                           xprojection=nothing,
                           yprojection=nothing,
                           label=nothing,
                           spacing=1.7,
                           levels=12,
                           kwargs...)
    ax.xreversed = true
    ax.yreversed = true

    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    σ = _contour_sigma(dfwd, normalize)

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

    state = _get_or_create_contour_state!(ax, Float64(spacing))
    _register_contour_keyboard!(ax)
    lm = state.level_mult
    z = _realdata(dfwd)
    pos_base = levels isa AbstractVector ?
               collect(Float64, levels) :
               collect(5σ .* contourlevels(spacing, levels))
    neg_base = -reverse(pos_base)
    pos_levels_obs = @lift($lm .* pos_base)
    neg_levels_obs = @lift($lm .* neg_base)
    plt_pos = Makie.contour!(ax, data(x), data(y), z;
                             levels=pos_levels_obs, color=poscolor_c,
                             label=label_str, kwargs...)
    if negcontours
        Makie.contour!(ax, data(x), data(y), z;
                       levels=neg_levels_obs, color=negcolor_c, kwargs...)
    end

    # Optional projection overlays. Look up the strip axes registered when
    # the axis was created; warn if the user asked for projections but
    # none exist.
    if !isnothing(xprojection) || !isnothing(yprojection)
        strips = get(_PROJECTION_STRIPS, ax, nothing)
        if isnothing(strips)
            @warn "nmrplot!: projection requested but this axis has no \
                   projection strips. Call `nmrplot(spec; xprojection=...)` \
                   first to set up the side strips."
        else
            if !isnothing(xprojection) && !isnothing(strips.top)
                _plot_xprojection!(strips.top, spec, xprojection,
                                   normalize, poscolor_c)
            end
            if !isnothing(yprojection) && !isnothing(strips.right)
                _plot_yprojection!(strips.right, spec, yprojection,
                                   normalize, poscolor_c)
            end
        end
    end

    return plt_pos
end

# ─────────────────────────────────────────────────────────────────────────
# Vector of 2D pure-frequency spectra
# ─────────────────────────────────────────────────────────────────────────

function NMRTools.nmrplot(v::AbstractVector{<:_Spec2DFreq};
                          figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ap = NMRTools.nmrplot(fig[1, 1], v; kwargs...)
    return Makie.FigureAxisPlot(fig, ap.axis, ap.plot)
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
                          xlims=nothing,
                          ylims=nothing,
                          legend=false,
                          axis=NamedTuple(),
                          spacing=1.7,
                          levels=12,
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
        plt = NMRTools.nmrplot!(ax, d; normalize=refnorm, poscolor=poscolors[i],
                                negcolor=negc[i], negcontours, spacing, levels,
                                kwargs...)
        i == 1 && (first_plt = plt)
        push!(labels, string(something(NMRTools.label(reorder(d, ForwardOrdered)), "")))
    end
    _apply_contour_legend!(ax, legend, labels, poscolors)
    _apply_axis_limits!(ax, xlims, ylims)
    return Makie.AxisPlot(ax, first_plt)
end
