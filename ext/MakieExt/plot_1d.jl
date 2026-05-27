# ─────────────────────────────────────────────────────────────────────────
# 1D frequency-domain spectra → lines
# ─────────────────────────────────────────────────────────────────────────

const _Spec1DFreq = NMRData{T,1,<:Tuple{<:FrequencyDimension}} where {T}
const _Spec1DNonFreq = NMRData{T,1,<:Tuple{<:NonFrequencyDimension}} where {T}

function NMRTools.nmrplot(spec::_Spec1DFreq; figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], spec; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          spec::_Spec1DFreq;
                          normalize=true,
                          title=nothing,
                          xlabel=nothing,
                          ylabel=nothing,
                          legend=false,
                          axis=NamedTuple(),
                          kwargs...)
    Afwd = reorder(spec, ForwardOrdered)
    dim = dims(Afwd, 1)
    title_str = isempty(refdims(Afwd)) ? string(something(NMRTools.label(Afwd), "")) :
                refdims_title(Afwd)
    defaults = (; xreversed=true,
                xlabel=axislabel(dim),
                ylabel="",
                xgridvisible=false,
                ygridvisible=false,
                yticksvisible=false,
                yticklabelsvisible=false,
                xtickalign=1,
                title=title_str)
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, axis)
    ax = Makie.Axis(gp; ax_kwargs...)
    plt = NMRTools.nmrplot!(ax, spec; normalize, kwargs...)
    _apply_legend!(ax, legend)
    return Makie.AxisPlot(ax, plt)
end

function NMRTools.nmrplot!(ax::Makie.Axis, spec::_Spec1DFreq;
                           normalize=true, kwargs...)
    ax.xreversed = true
    Afwd = reorder(spec, ForwardOrdered)
    sf, _ = _resolve_normalize(Afwd, normalize)
    x = data(dims(Afwd, 1))
    y = _realdata(Afwd) ./ sf
    return Makie.lines!(ax, x, y;
                        label=string(something(NMRTools.label(Afwd), "")),
                        kwargs...)
end

# ─────────────────────────────────────────────────────────────────────────
# 1D non-frequency-domain spectra → scatter
# ─────────────────────────────────────────────────────────────────────────

function NMRTools.nmrplot(spec::_Spec1DNonFreq; figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], spec; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          spec::_Spec1DNonFreq;
                          normalize=true,
                          title=nothing,
                          xlabel=nothing,
                          ylabel=nothing,
                          legend=false,
                          axis=NamedTuple(),
                          kwargs...)
    Afwd = reorder(spec, ForwardOrdered)
    dim = dims(Afwd, 1)
    title_str = isempty(refdims(Afwd)) ? string(something(NMRTools.label(Afwd), "")) :
                refdims_title(Afwd)
    defaults = (; xlabel=axislabel(dim),
                ylabel="Intensity",
                xgridvisible=false,
                ygridvisible=false,
                xtickalign=1,
                ytickalign=1,
                title=title_str)
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, axis)
    ax = Makie.Axis(gp; ax_kwargs...)
    plt = NMRTools.nmrplot!(ax, spec; normalize, kwargs...)
    _apply_legend!(ax, legend)
    return Makie.AxisPlot(ax, plt)
end

function NMRTools.nmrplot!(ax::Makie.Axis, spec::_Spec1DNonFreq;
                           normalize=true, kwargs...)
    Afwd = reorder(spec, ForwardOrdered)
    sf, _ = _resolve_normalize(Afwd, normalize)
    x = data(dims(Afwd, 1))
    y = _realdata(Afwd) ./ sf
    return Makie.scatter!(ax, x, y;
                          label=string(something(NMRTools.label(Afwd), "")),
                          kwargs...)
end

# ─────────────────────────────────────────────────────────────────────────
# Vector of 1D spectra (overlay or vertical stack)
# ─────────────────────────────────────────────────────────────────────────

function NMRTools.nmrplot(v::AbstractVector{<:NMRData{<:Any,1,
                                                      <:Tuple{<:FrequencyDimension}}};
                          figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], v; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          v::AbstractVector{<:NMRData{<:Any,1,
                                                      <:Tuple{<:FrequencyDimension}}};
                          normalize=true,
                          vstack=false,
                          color=nothing,
                          colors=nothing,
                          colormap=nothing,
                          title=nothing,
                          xlabel=nothing,
                          ylabel=nothing,
                          legend=false,
                          axis=NamedTuple(),
                          kwargs...)
    isempty(v) && throw(ArgumentError("nmrplot: empty spectrum vector"))
    dim = dims(reorder(first(v), ForwardOrdered), 1)
    defaults = (; xreversed=true,
                xlabel=axislabel(dim),
                ylabel="",
                xgridvisible=false,
                ygridvisible=false,
                yticksvisible=false,
                yticklabelsvisible=false,
                xtickalign=1,
                title="")
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, axis)
    ax = Makie.Axis(gp; ax_kwargs...)
    colors = isnothing(colors) ? color : colors
    plt = _plot_1d_series!(ax, v; normalize, vstack, colors, colormap, kwargs...)
    _apply_legend!(ax, legend)
    return Makie.AxisPlot(ax, plt)
end

function _plot_1d_series!(ax::Makie.Axis, v;
                          normalize=true, vstack=false,
                          colors=nothing, colormap=nothing, kwargs...)
    n = length(v)
    cs = _series_poscolors(colors, n; colormap)

    vdelta = 0.0
    if vstack isa Bool
        if vstack
            vdelta = maximum(maximum(abs.(_realdata(A))) /
                             _resolve_normalize(A, normalize)[1] for A in v) / n
        end
    elseif vstack isa Number
        vdelta = maximum(maximum(abs.(_realdata(A))) /
                         _resolve_normalize(A, normalize)[1] for A in v) / n * vstack
    else
        throw(ArgumentError("vstack must be a Bool or Number"))
    end

    local first_plt
    voffset = 0.0
    for (i, A) in enumerate(v)
        Afwd = reorder(A, ForwardOrdered)
        sf, _ = _resolve_normalize(Afwd, normalize)
        x = data(dims(Afwd, 1))
        y = _realdata(Afwd) ./ sf .+ voffset
        plt = Makie.lines!(ax, x, y; color=cs[i],
                           label=string(something(NMRTools.label(Afwd), "")),
                           kwargs...)
        i == 1 && (first_plt = plt)
        voffset += vdelta
    end
    return first_plt
end
