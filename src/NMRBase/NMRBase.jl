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

# using Reexport: Reexport
# Reexport.@reexport using DimensionalData
using DimensionalData
using DimensionalData.LookupArrays,
      DimensionalData.Dimensions
const DD = DimensionalData

# using DimensionalData: Name, NoName
# using .Dimensions: StandardIndices, DimTuple, Dimension
# using .LookupArrays: LookupArrayTuple

import .LookupArrays: metadata, set, _set, rebuild, basetypeof, Metadata,
    order, span, sampling, locus, val, index, bounds, hasselection, units, SelectorOrInterval
import .Dimensions: dims, refdims, lookup, dimstride, kwdims, hasdim, label, _astuple

include("nuclei.jl")
include("dimensions.jl")
include("windows.jl")
include("nmrdata.jl")
include("metadata.jl")

macro exportinstances(enum)
    eval = GlobalRef(Core, :eval)
    return :($eval($__module__, Expr(:export, map(Symbol, instances($enum))...)))
end

# Nuclei
export Nucleus
@exportinstances Nucleus
export spin
export gyromagneticratio

# NMRData
export AbstractNMRData
export NMRData
# Selectors
export At, Between, Touches, Contains, Near, Where, All, ..
# getter methods
export parent, dims, refdims, lookup, bounds, missingval
# Dimension/Lookup primitives
export dimnum, hasdim, hasselection, otherdims
# utils
export set, rebuild, reorder, modify, broadcast_dims, broadcast_dims!
# NMR properties
export scale

# Dimensions
export NMRDimension
export TimeDim
export FrequencyDim
export QuadratureDim
export GradientDim
export SpatialDim

# Metadata
export AbstractMetadata, Metadata, NoMetadata
export metadata
export defaultmetadata
export metadatahelp
export label, units

# Window functions
export WindowFunction
export NullWindow
export UnknownWindow
export ExponentialWindow

end
