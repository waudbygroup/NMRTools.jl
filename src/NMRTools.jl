module NMRTools

using DimensionalData
#using Lazy
#using Reexport
using SimpleTraits
using OffsetArrays
using Plots

import Base.getindex, Base.setindex!
import DimensionalData.refdims, DimensionalData.data, DimensionalData.name, DimensionalData.metadata, DimensionalData.label, DimensionalData.rebuild
import DimensionalData.X, DimensionalData.Y, DimensionalData.Z, DimensionalData.Ti

export NMRData
export X, Y, Z, Ti
export haspseudodimension, HasPseudoDimension
export NMRToolsException
export loadnmr
export data, label, label!, metadata, metadatahelp
export WindowFunction, NullWindow, UnknownWindow, ExponentialWindow, SineWindow, GaussWindow

# type definitions
include("exceptions.jl")
include("nmrdata.jl")
include("windows.jl")

# routines
include("loadnmr.jl")
include("plotrecipes.jl")

end # module
