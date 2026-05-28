# ─────────────────────────────────────────────────────────────────────────
# Pseudo-2D spectra (one frequency dim + one non-frequency dim)
#
# Styles:
#   :heatmap (default)  — `Makie.heatmap!` with diverging colourmap centred
#                          on zero. Single spectra only — heatmaps don't
#                          overlay sensibly.
#   :flat               — overlaid 1D slices, no vertical offset, with a
#                          zero baseline (regular Axis).
#   :waterfall          — 3D lines, one per slice (Axis3).
# ─────────────────────────────────────────────────────────────────────────

const _SpecPseudo2D_FN = NMRData{T,2,<:Tuple{<:FrequencyDimension,
                                              <:NonFrequencyDimension}} where {T}
const _SpecPseudo2D_NF = NMRData{T,2,<:Tuple{<:NonFrequencyDimension,
                                              <:FrequencyDimension}} where {T}
const _SpecPseudo2D = Union{_SpecPseudo2D_FN,_SpecPseudo2D_NF}

# ──── Constructor (Figure-creating) form ─────────────────────────────────

function NMRTools.nmrplot(spec::_SpecPseudo2D; figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], spec; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

function NMRTools.nmrplot(v::AbstractVector{<:_SpecPseudo2D};
                          figure=NamedTuple(), kwargs...)
    fig = Makie.Figure(; figure...)
    ax, plt = NMRTools.nmrplot(fig[1, 1], v; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, plt)
end

# Non-freq-first → permute to freq-first and re-dispatch.
NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                 spec::_SpecPseudo2D_NF; kwargs...) =
    NMRTools.nmrplot(gp, permutedims(spec, (2, 1)); kwargs...)

# ──── Style dispatch (single spectrum at a layout slot) ───────────────────

function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          spec::_SpecPseudo2D_FN;
                          style=:heatmap, kwargs...)
    if style === :heatmap
        return _pseudo2d_heatmap(gp, spec; kwargs...)
    elseif style === :flat
        return _pseudo2d_flat(gp, spec; kwargs...)
    elseif style === :waterfall
        return _pseudo2d_waterfall(gp, spec; kwargs...)
    else
        throw(ArgumentError("style must be :heatmap, :flat, or :waterfall"))
    end
end

# Vector dispatch — flat and waterfall overlay; heatmap rejected.
function NMRTools.nmrplot(gp::Union{Makie.GridPosition,Makie.GridSubposition},
                          v::AbstractVector{<:_SpecPseudo2D};
                          style=:flat, kwargs...)
    isempty(v) && throw(ArgumentError("nmrplot: empty spectrum vector"))
    if style === :flat
        return _pseudo2d_flat_vector(gp, v; kwargs...)
    elseif style === :waterfall
        return _pseudo2d_waterfall_vector(gp, v; kwargs...)
    elseif style === :heatmap
        throw(ArgumentError("Cannot overlay multiple heatmaps; plot each \
                             pseudo-2D separately."))
    else
        throw(ArgumentError("style must be :flat or :waterfall for vectors"))
    end
end

# ──── Mutating (`nmrplot!`) — dispatch on axis type ──────────────────────

# Permute non-freq-first specs.
NMRTools.nmrplot!(ax::Union{Makie.Axis,Makie.Axis3},
                  spec::_SpecPseudo2D_NF; kwargs...) =
    NMRTools.nmrplot!(ax, permutedims(spec, (2, 1)); kwargs...)

function NMRTools.nmrplot!(ax::Makie.Axis, spec::_SpecPseudo2D_FN;
                           style=:flat, kwargs...)
    style === :flat ||
        throw(ArgumentError("nmrplot!(::Axis, pseudo2D) only supports \
                             style=:flat (got :$style). Use Axis3 for \
                             :waterfall."))
    return _pseudo2d_flat!(ax, spec; kwargs...)
end

function NMRTools.nmrplot!(ax::Makie.Axis3, spec::_SpecPseudo2D_FN;
                           style=:waterfall, kwargs...)
    style === :waterfall ||
        throw(ArgumentError("nmrplot!(::Axis3, pseudo2D) only supports \
                             style=:waterfall (got :$style)."))
    return _pseudo2d_waterfall!(ax, spec; kwargs...)
end

# ──── Heatmap ────────────────────────────────────────────────────────────

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
    sf = _normalization_divisor(dfwd, normalize)
    z = _realdata(dfwd) ./ sf

    if isnothing(colorrange)
        # 99th-percentile clipping so the bar focuses on the bulk of the
        # data rather than spanning rare outliers, and stays centred at 0.
        absz = abs.(vec(z))
        vmax = isempty(absz) ? 1.0 : quantile(absz, 0.99)
        vmax > 0 || (vmax = maximum(abs, z); vmax > 0 || (vmax = 1.0))
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

# ──── Flat (overlaid 1D slices, no offset, with zero baseline) ───────────

function _pseudo2d_flat(gp, spec::_SpecPseudo2D_FN;
                        title=nothing, xlabel=nothing, ylabel=nothing,
                        legend=false, axis=NamedTuple(), kwargs...)
    dim = dims(reorder(spec, ForwardOrdered), 1)
    defaults = (; xreversed=true,
                xlabel=axislabel(dim),
                ylabel="",
                xgridvisible=false,
                ygridvisible=false,
                yticksvisible=false,
                yticklabelsvisible=false,
                xtickalign=1,
                title=string(something(label(spec), "")))
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, axis)
    ax = Makie.Axis(gp; ax_kwargs...)
    plt = _pseudo2d_flat!(ax, spec; kwargs...)
    _apply_legend!(ax, legend)
    return Makie.AxisPlot(ax, plt)
end

function _pseudo2d_flat_vector(gp, v::AbstractVector{<:_SpecPseudo2D};
                               color=nothing, colors=nothing, colormap=nothing,
                               title=nothing, xlabel=nothing, ylabel=nothing,
                               legend=false, axis=NamedTuple(), kwargs...)
    first_spec = first(v) isa _SpecPseudo2D_FN ? first(v) :
                 permutedims(first(v), (2, 1))
    dim = dims(reorder(first_spec, ForwardOrdered), 1)
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

    # For a vector of pseudo-2D, treat colours as one per spectrum (not per
    # slice within a spectrum). All slices of spectrum i share spec_colors[i].
    colors_arg = isnothing(colors) ? color : colors
    spec_colors = _series_poscolors(colors_arg, length(v); colormap)

    local first_plt
    for (i, spec) in enumerate(v)
        plt = NMRTools.nmrplot!(ax, spec; style=:flat,
                                color=spec_colors[i], kwargs...)
        i == 1 && (first_plt = plt)
    end
    _apply_legend!(ax, legend)
    return Makie.AxisPlot(ax, first_plt)
end

function _pseudo2d_flat!(ax::Makie.Axis, spec::_SpecPseudo2D_FN;
                         normalize=true,
                         color=nothing,
                         colors=nothing,
                         colormap=nothing,
                         zeroline=true,
                         kwargs...)
    ax.xreversed = true
    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    sf = _normalization_divisor(dfwd, normalize)
    z = _realdata(dfwd) ./ sf
    n = length(y)

    colors = isnothing(colors) ? color : colors
    is_overlay = !isempty(ax.scene.plots)
    cs = if !isnothing(colors)
        _series_poscolors(colors, n; colormap)
    elseif is_overlay
        # Overlay without explicit colour: use the second Wong colour for all
        # slices so the overlay reads as one spectrum, distinct from the
        # rainbow of the original. Pass `color=...` to customise.
        fill(_parse_colorant(_theme_palette()[2]), n)
    else
        _series_poscolors(nothing, n; colormap)
    end

    # Zero baseline, drawn once (skip when overlaying onto an existing plot).
    if zeroline && !is_overlay
        Makie.hlines!(ax, [0.0]; color=(:gray, 0.7), linewidth=0.8)
    end

    local first_plt
    xvals = data(x)
    yvals = data(y)
    for i in 1:n
        plt = Makie.lines!(ax, xvals, z[:, i];
                           color=cs[i], label=string(yvals[i]), kwargs...)
        i == 1 && (first_plt = plt)
    end
    return first_plt
end

# ──── Waterfall (3D lines on Axis3) ──────────────────────────────────────

function _pseudo2d_waterfall(gp, spec::_SpecPseudo2D_FN;
                             title=nothing, xlabel=nothing, ylabel=nothing,
                             zlabel="Intensity", axis=NamedTuple(), kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    defaults = (; xreversed=true,
                xlabel=axislabel(x),
                ylabel=axislabel(y),
                zlabel=zlabel,
                # Default Axis3 azimuth puts +x going right-back. We rotate
                # by π/2 so the frequency (x) axis sits on the visible
                # left edge of the plot and the non-freq (y) axis on the
                # right edge, matching conventional NMR waterfall layout.
                azimuth=1.275π + π / 2,
                title=string(something(label(spec), "")))
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, zlabel, axis)
    ax = Makie.Axis3(gp; ax_kwargs...)
    plt = _pseudo2d_waterfall!(ax, spec; kwargs...)
    return Makie.AxisPlot(ax, plt)
end

function _pseudo2d_waterfall_vector(gp, v::AbstractVector{<:_SpecPseudo2D};
                                    color=nothing, colors=nothing, colormap=nothing,
                                    title=nothing, xlabel=nothing, ylabel=nothing,
                                    zlabel="Intensity", axis=NamedTuple(),
                                    kwargs...)
    first_spec = first(v) isa _SpecPseudo2D_FN ? first(v) :
                 permutedims(first(v), (2, 1))
    dfwd0 = reorder(first_spec, ForwardOrdered)
    x0, y0 = dims(dfwd0)
    defaults = (; xreversed=true,
                xlabel=axislabel(x0),
                ylabel=axislabel(y0),
                zlabel=zlabel,
                azimuth=1.275π + π / 2,
                title="")
    ax_kwargs = _axis_overrides(defaults; title, xlabel, ylabel, zlabel, axis)
    ax = Makie.Axis3(gp; ax_kwargs...)

    colors_arg = isnothing(colors) ? color : colors
    spec_colors = _series_poscolors(colors_arg, length(v); colormap)

    local first_plt
    for (i, spec) in enumerate(v)
        plt = NMRTools.nmrplot!(ax, spec; style=:waterfall,
                                color=spec_colors[i], kwargs...)
        i == 1 && (first_plt = plt)
    end
    return Makie.AxisPlot(ax, first_plt)
end

function _pseudo2d_waterfall!(ax::Makie.Axis3, spec::_SpecPseudo2D_FN;
                              normalize=true,
                              color=nothing,
                              colors=nothing,
                              colormap=nothing,
                              kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y = dims(dfwd)
    sf = _normalization_divisor(dfwd, normalize)
    z = _realdata(dfwd) ./ sf
    n = length(y)

    colors = isnothing(colors) ? color : colors
    is_overlay = !isempty(ax.scene.plots)
    cs = if !isnothing(colors)
        _series_poscolors(colors, n; colormap)
    elseif is_overlay
        # Overlay without explicit colour: use second Wong colour for all
        # slices so the overlay reads as one spectrum, visually distinct
        # from the rainbow of the original. Pass `color=...` to customise.
        fill(_parse_colorant(_theme_palette()[2]), n)
    else
        _series_poscolors(nothing, n; colormap)
    end

    local first_plt
    xvals = data(x)
    yvals = data(y)
    # Iterate back-to-front so the front-most slice is drawn last (and
    # therefore on top), giving correct visual z-ordering.
    for i in n:-1:1
        plt = Makie.lines!(ax, xvals, fill(yvals[i], length(xvals)), z[:, i];
                           color=cs[i], kwargs...)
        i == n && (first_plt = plt)
    end
    return first_plt
end

