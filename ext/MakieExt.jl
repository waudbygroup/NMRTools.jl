module MakieExt

"""
notes on testing:
]activate --temp
]dev .
]add Plots
using NMRTools, Plots
"""

using NMRTools
using Makie
using SimpleTraits

@info "Loading MakieExt.jl"

function Makie.plottype(::D) where {D<:NMRData}
    @info "Determining plot type for NMR data of type $(D)"
    return _plottype(D)
end

_plottype(::Type{<:NMRData{T,3}}) where {T} = Makie.Volume  # 3D NMR defaults to volume

function _plottype(::Type{D}) where {D<:NMRData{T,1}} where {T}
    @info "Determining plot type for NMR data of type $(D)"
    return _plottype_1d(SimpleTraits.trait(HasNonFrequencyDimension{D}), D)
end

# 1D frequency data (Not{HasNonFrequencyDimension})
_plottype_1d(::Type{Not{HasNonFrequencyDimension{D}}}, ::Type{D}) where {D} = Makie.Lines

# 1D non-frequency data  
_plottype_1d(::Type{HasNonFrequencyDimension{D}}, ::Type{D}) where {D} = Makie.Scatter  # or Lines, depending on your preference

# 2D data
function _plottype(::Type{D}) where {D<:NMRData{T,2}} where {T}
    return _plottype_2d(SimpleTraits.trait(HasNonFrequencyDimension{D}), D)
end

# Pure frequency 2D data (Not{HasNonFrequencyDimension})
_plottype_2d(::Type{Not{HasNonFrequencyDimension{D}}}, ::Type{D}) where {D} = Makie.Contour

# Mixed or non-frequency 2D data
_plottype_2d(::Type{HasNonFrequencyDimension{D}}, ::Type{D}) where {D} = Makie.Heatmap

end