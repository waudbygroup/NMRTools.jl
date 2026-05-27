# ─────────────────────────────────────────────────────────────────────────
# 3D pure-frequency NMR spectra → Makie volume rendering on Axis3
#
# Default algorithm is `:mip` (maximum intensity projection) which gives
# an intuitive peak-focused view of NMR 3D data. Other choices:
#   :absorption — alpha-blended volume (set `absorption=...`)
#   :iso        — iso-surface (set `isovalue=...` and `isorange=...`)
#   :additive   — additive blending
# NMR signed data is rendered via |z| / max|z|; below `threshold` σ the
# colormap is forced fully transparent so noise drops out.
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
                          algorithm=:mip,
                          colormap=:plasma,
                          absorption=4.0,
                          threshold=5,
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
    plt = NMRTools.nmrplot!(ax, spec; normalize, algorithm, colormap,
                            absorption, threshold, kwargs...)
    return Makie.AxisPlot(ax, plt)
end

function NMRTools.nmrplot!(ax::Makie.Axis3, spec::_Spec3DFreq;
                           normalize=true,
                           algorithm=:mip,
                           colormap=:plasma,
                           absorption=4.0,
                           threshold=5,
                           kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y, z = dims(dfwd)
    _, σ = _resolve_normalize(dfwd, normalize)

    vol_raw = _realdata(dfwd)
    avol = abs.(vol_raw)
    vmax = maximum(avol)
    vmax > 0 || (vmax = 1.0)
    normed = Float32.(avol ./ vmax)

    cmap = _transparent_low_colormap(colormap, σ, vmax, threshold)

    # Makie's VolumeLike conversion expects (start, stop) endpoint tuples
    # on each axis, not full coordinate vectors.
    xr = (Float64(first(data(x))), Float64(last(data(x))))
    yr = (Float64(first(data(y))), Float64(last(data(y))))
    zr = (Float64(first(data(z))), Float64(last(data(z))))

    vol_kwargs = if algorithm === :absorption
        (; algorithm=:absorption, absorption=Float32(absorption), colormap=cmap)
    else
        (; algorithm=algorithm, colormap=cmap)
    end
    return Makie.volume!(ax, xr, yr, zr, normed; vol_kwargs..., kwargs...)
end

# Build a colormap with its low end made fully transparent up to the
# normalised threshold level (threshold * σ / vmax). This is the volume
# analogue of "contours start at 5σ" — values below the threshold
# disappear into the background.
function _transparent_low_colormap(colormap, σ, vmax, threshold)
    cmap = copy(Makie.to_colormap(colormap))
    thr_norm = !isnothing(σ) ? Float64(threshold * σ / vmax) : 0.0
    n_transparent = if 0 < thr_norm < 1
        max(1, ceil(Int, thr_norm * length(cmap)))
    else
        1
    end
    for i in 1:min(n_transparent, length(cmap))
        c = cmap[i]
        cmap[i] = Makie.RGBAf(Colors.red(c), Colors.green(c), Colors.blue(c), 0.0f0)
    end
    return cmap
end
