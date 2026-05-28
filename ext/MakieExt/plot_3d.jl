# ─────────────────────────────────────────────────────────────────────────
# 3D pure-frequency NMR spectra → Makie volume rendering on Axis3
#
# Default algorithm is `:mip` (maximum intensity projection) — an intuitive
# peak-focused view of 3D NMR data. Other choices:
#   :absorption — alpha-blended volume (tune with `absorption=...`)
#   :iso        — iso-surface (set `isovalue=...`, `isorange=...`)
#   :additive   — additive blending
#
# Data is kept in raw (signed) units. The visible window is set with
# `colorrange = (threshold*σ, max)`: values at/below the noise floor map to
# the transparent low end of the colourmap and disappear, while peaks light
# up — the volume analogue of "2D contours start at 5σ". Negative values
# fall below the range and are likewise transparent (fine for the usual
# positive-peak experiments; pass an explicit `colorrange` to change this).
#
# High dynamic range tip: if one strong peak washes the rest out, lower the
# upper bound, e.g. `colorrange = (5σ, 30σ)`.
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
                          colorrange=nothing,
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
                            absorption, threshold, colorrange, kwargs...)
    return Makie.AxisPlot(ax, plt)
end

function NMRTools.nmrplot!(ax::Makie.Axis3, spec::_Spec3DFreq;
                           normalize=true,
                           algorithm=:mip,
                           colormap=:plasma,
                           absorption=4.0,
                           threshold=5,
                           colorrange=nothing,
                           kwargs...)
    dfwd = reorder(spec, ForwardOrdered)
    x, y, z = dims(dfwd)
    σ = _contour_sigma(dfwd, normalize)

    vol = Float32.(_realdata(dfwd))
    vmax = maximum(vol)

    # Lower bound at threshold·σ (noise floor); guard against σ being unset
    # or larger than the data peak.
    lo = (!isnothing(σ) && threshold * σ < vmax) ? Float32(threshold * σ) :
         zero(Float32)
    crange = isnothing(colorrange) ? (lo, Float32(vmax)) : colorrange

    cmap = _fade_low_colormap(colormap)

    # Makie's VolumeLike conversion expects (start, stop) endpoint tuples on
    # each axis, not full coordinate vectors.
    xr = (Float64(first(data(x))), Float64(last(data(x))))
    yr = (Float64(first(data(y))), Float64(last(data(y))))
    zr = (Float64(first(data(z))), Float64(last(data(z))))

    vol_kwargs = if algorithm === :absorption
        (; algorithm=:absorption, absorption=Float32(absorption),
         colormap=cmap, colorrange=crange)
    else
        (; algorithm=algorithm, colormap=cmap, colorrange=crange)
    end
    return Makie.volume!(ax, xr, yr, zr, vol; vol_kwargs..., kwargs...)
end

# Colourmap whose low end fades from fully transparent to opaque over the
# first `framp` fraction of its range. Combined with `colorrange`, this
# makes values near the lower bound disappear smoothly instead of popping
# in — the volume analogue of contours fading in above the noise floor.
function _fade_low_colormap(colormap; framp=0.15)
    cmap = copy(Makie.to_colormap(colormap))
    n = length(cmap)
    nramp = max(1, round(Int, framp * n))
    for i in 1:nramp
        c = cmap[i]
        a = Float32((i - 1) / nramp)
        cmap[i] = Makie.RGBAf(Colors.red(c), Colors.green(c), Colors.blue(c), a)
    end
    return cmap
end
