module NMRBase

const EXPERIMENTAL = """
    WARNING: This feature is experimental. It may change in future versions, and may
    not be 100% reliable in all cases. Please file github issues if problems occur.
    """

# DimensionalData documentation urls
const DDdocs = "https://rafaqz.github.io/DimensionalData.jl/stable/api"
const DDdimdocs = joinpath(DDdocs, "#DimensionalData.Dimension")
const DDarraydocs = joinpath(DDdocs, "#DimensionalData.AbstractDimensionalArray")
# const DDabssampleddocs = joinpath(DDdocs, "#DimensionalData.AbstractSampled")
# const DDsampleddocs = joinpath(DDdocs, "#DimensionalData.Sampled")
# const DDlocusdocs = joinpath(DDdocs, "#DimensionalData.Locus")
# const DDselectordocs = joinpath(DDdocs, "#DimensionalData.Selector")
# const DDtidocs = joinpath(DDdocs, "#DimensionalData.Ti")

using SimpleTraits

# using Reexport: Reexport
# Reexport.@reexport using DimensionalData
using DimensionalData
using DimensionalData.LookupArrays,
      DimensionalData.Dimensions
const DD = DimensionalData

# using DimensionalData: Name, NoName
# using .Dimensions: StandardIndices, DimTuple, Dimension
# using .LookupArrays: LookupArrayTuple

import DimensionalData.refdims_title
import .LookupArrays: metadata, set, _set, rebuild, basetypeof, Metadata,
    order, span, sampling, locus, val, index, bounds, hasselection, units, SelectorOrInterval,
    ForwardOrdered
import .Dimensions: dims, refdims, lookup, dimstride, kwdims, hasdim, label, _astuple

include("exceptions.jl")
include("nuclei.jl")
include("coherences.jl")
include("dimensions.jl")
include("windows.jl")
include("nmrdata.jl")
include("metadata.jl")

macro exportinstances(enum)
    eval = GlobalRef(Core, :eval)
    return :($eval($__module__, Expr(:export, map(Symbol, instances($enum))...)))
end

# Exceptions
export NMRToolsException

# Nuclei
export Nucleus
@exportinstances Nucleus
export spin
export gyromagneticratio

# coherences
export Coherence
export SQ, MQ
export coherenceorder
export γeff

# NMRData
export AbstractNMRData
export NMRData
# Selectors
export At, Between, Touches, Contains, Near, Where, All, ..
# getter methods
export data, parent, dims, refdims, lookup, bounds, missingval
# traits
export hasnonfrequencydimension, HasNonFrequencyDimension
# Dimension/Lookup primitives
export dimnum, hasdim, hasselection, otherdims
# utils
export refdims_title
export set, rebuild, reorder, modify, broadcast_dims, broadcast_dims!, ForwardOrdered
# NMR properties
export scale

# Dimensions
export NMRDimension
export TimeDimension
export FrequencyDimension
export QuadratureDimension
export UnknownDimension
export F1Dim, F2Dim, F3Dim, F4Dim
export T1Dim, T2Dim, T3Dim, T4Dim
export TrelaxDim, TkinDim
export Q1Dim, Q2Dim, Q3Dim, Q4Dim
export X1Dim, X2Dim, X3Dim, X4Dim
# export GradientDim
# export SpatialDim

# Metadata
export AbstractMetadata, Metadata, NoMetadata
export metadata
export defaultmetadata
export metadatahelp
export label, label!, units
export acqus

# Window functions
export WindowFunction
export NullWindow
export UnknownWindow
export ExponentialWindow
export SineWindow
export GeneralSineWindow, CosWindow, Cos²Window
export GaussWindow
export GeneralGaussWindow, LorentzToGaussWindow

end
