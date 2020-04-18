module NMRTools

using Colors
using DimensionalData
using OffsetArrays
using Optim
using Plots
using SimpleTraits
using SpecialFunctions
using Statistics

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
export estimatenoise!

# type definitions
include("util.jl")
include("exceptions.jl")
include("nmrdata.jl")
include("windows.jl")

# routines
include("noise.jl")
include("loadnmr.jl")
include("plotrecipes.jl")

end # module
