module MakieExt

using NMRTools
using NMRTools: NMRData, AbstractNMRData, NMRDimension, FrequencyDimension,
                NonFrequencyDimension
using NMRTools: data, dims, refdims, refdims_title, label, scale, units,
                reorder, ForwardOrdered
using MulticomplexNumbers: Multicomplex, realest
using Makie
using Colors

include("MakieExt/plotutils.jl")
include("MakieExt/plot_1d.jl")
include("MakieExt/plot_2d.jl")

# Convenience: forward `nmrplot!(fig_like, spec)` to the underlying axis so
# the typical workflow `fig = nmrplot(spec); nmrplot!(fig, spec/2)` just
# works without manual destructuring.
NMRTools.nmrplot!(fap::Makie.FigureAxisPlot, args...; kwargs...) =
    NMRTools.nmrplot!(fap.axis, args...; kwargs...)

NMRTools.nmrplot!(ap::Makie.AxisPlot, args...; kwargs...) =
    NMRTools.nmrplot!(ap.axis, args...; kwargs...)

function NMRTools.nmrplot!(fig::Makie.Figure, args...; kwargs...)
    ax = Makie.current_axis(fig)
    isnothing(ax) && throw(ArgumentError("nmrplot!: Figure has no current axis. \
                                          Create one with `nmrplot(fig[1,1], spec)` \
                                          or pass an `Axis` directly."))
    return NMRTools.nmrplot!(ax, args...; kwargs...)
end

# Informative errors for spectrum shapes deferred to a later iteration.
# Pseudo-2D dispatch (one frequency + one non-frequency dim).
function NMRTools.nmrplot(spec::NMRData{<:Any,2,
                                        <:Tuple{<:NonFrequencyDimension,
                                                <:FrequencyDimension}};
                          kwargs...)
    throw(ArgumentError("pseudo-2D nmrplot not yet implemented in MakieExt; \
                         only pure-frequency 2D spectra are supported in this \
                         iteration."))
end
function NMRTools.nmrplot(spec::NMRData{<:Any,2,
                                        <:Tuple{<:FrequencyDimension,
                                                <:NonFrequencyDimension}};
                          kwargs...)
    throw(ArgumentError("pseudo-2D nmrplot not yet implemented in MakieExt; \
                         only pure-frequency 2D spectra are supported in this \
                         iteration."))
end

# 3D not implemented in this iteration.
function NMRTools.nmrplot(spec::NMRData{<:Any,3}; kwargs...)
    throw(ArgumentError("3D nmrplot not yet implemented in MakieExt; consider \
                         plotting a 2D projection via \
                         `maximum(spec; dims=2)[:, 1, :]` or similar."))
end

end # module
