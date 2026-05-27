# ─────────────────────────────────────────────────────────────────────────
# Pseudo-2D spectra (one frequency dim + one non-frequency dim)
#
# Two styles for now:
#   :heatmap (default)  — `Makie.heatmap!` with a diverging colourmap
#                          centred on zero, suitable for signed NMR data.
#   :stack              — overlaid 1D slices with a constant vertical
#                          offset per slice; like vstack for a series.
# :waterfall (3D Axis3) is reserved for a later iteration.
# ─────────────────────────────────────────────────────────────────────────

const _SpecPseudo2D_FN = NMRData{T,2,<:Tuple{<:FrequencyDimension,
                                              <:NonFrequencyDimension}} where {T}
const _SpecPseudo2D_NF = NMRData{T,2,<:Tuple{<:NonFrequencyDimension,
                                              <:FrequencyDimension}} where {T}

function NMRTools.nmrplot(spec::Union{_SpecPseudo2D_FN,_SpecPseudo2D_NF};
                          figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], spec; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

# Non-freq first → permute so freq comes first, re-dispatch.
function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          spec::_SpecPseudo2D_NF; kwargs...)
    return NMRTools.nmrplot(gp, permutedims(spec, (2, 1)); kwargs...)
end

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          spec::_SpecPseudo2D_FN;
                          style=:heatmap,
                          kwargs...)
    if style === :heatmap
        return _pseudo2d_heatmap(gp, spec; kwargs...)
    elseif style === :stack
        return _pseudo2d_stack(gp, spec; kwargs...)
    elseif style === :waterfall
        throw(ArgumentError("pseudo-2D :waterfall style not yet implemented; \
                             use :heatmap (default) or :stack."))
    else
        throw(ArgumentError("style must be :heatmap, :stack, or :waterfall"))
    end
end

function _pseudo2d_heatmap(gp, spec::_SpecPseudo2D_FN;
                           normalize=true,
                           colormap=:RdBu,
                           colorrange=nothing,
                           colorbar=true,
                           title=nothing,
                           xlabel=nothing,
                           ylabel=nothing,
                           axis=NamedTuple(),
                           kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    sf, _ = _resolve_normalize(dfwd, normalize)
    z = _realdata(dfwd) ./ sf

    if isnothing(colorrange)
        vmax = maximum(abs, z)
        colorrange = (-vmax, vmax)
    end

    defaults = (; xreversed=true,
                yreversed=false,
                xlabel=axislabel(x),
                ylabel=axislabel(y),
                xgridvisible=false,
                ygridvisible=false,
                xtickalign=1,
                ytickalign=1,
                title=string(something(label(spec), "")))
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, axis)

    if colorbar
        gl = Makie.GridLayout(gp)
        ax = Makie.Axis(gl[1, 1]; ax_kwargs...)
        plt = Makie.heatmap!(ax, data(x), data(y), z;
                             colormap=colormap, colorrange=colorrange, kwargs...)
        Makie.Colorbar(gl[1, 2], plt)
    else
        ax = Makie.Axis(gp; ax_kwargs...)
        plt = Makie.heatmap!(ax, data(x), data(y), z;
                             colormap=colormap, colorrange=colorrange, kwargs...)
    end
    return Makie.AxisPlot(ax, plt)
end

function _pseudo2d_stack(gp, spec::_SpecPseudo2D_FN;
                         normalize=true,
                         vstack=true,
                         color=nothing,
                         colors=nothing,
                         colormap=nothing,
                         title=nothing,
                         xlabel=nothing,
                         ylabel=nothing,
                         legend=false,
                         axis=NamedTuple(),
                         kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    sf, _ = _resolve_normalize(dfwd, normalize)
    z = _realdata(dfwd) ./ sf
    n = length(y)

    defaults = (; xreversed=true,
                xlabel=axislabel(x),
                ylabel="",
                xgridvisible=false,
                ygridvisible=false,
                yticksvisible=false,
                yticklabelsvisible=false,
                xtickalign=1,
                title=string(something(label(spec), "")))
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, axis)
    ax = Makie.Axis(gp; ax_kwargs...)

    colors = isnothing(colors) ? color : colors
    cs = _series_poscolors(colors, n; colormap)

    vdelta = 0.0
    if vstack isa Bool
        vstack && (vdelta = maximum(abs, z) / n)
    elseif vstack isa Number
        vdelta = maximum(abs, z) / n * vstack
    else
        throw(ArgumentError("vstack must be a Bool or Number"))
    end

    local first_plt
    voffset = 0.0
    xvals = data(x)
    yvals = data(y)
    for i in 1:n
        plt = Makie.lines!(ax, xvals, z[:, i] .+ voffset;
                           color=cs[i],
                           label=string(yvals[i]),
                           kwargs...)
        i == 1 && (first_plt = plt)
        voffset += vdelta
    end
    _apply_legend!(ax, legend)
    return Makie.AxisPlot(ax, first_plt)
end
