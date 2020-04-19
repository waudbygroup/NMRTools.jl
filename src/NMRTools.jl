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
import DimensionalData.dims, DimensionalData.refdims, DimensionalData.data, DimensionalData.name, DimensionalData.metadata, DimensionalData.label, DimensionalData.rebuild
import DimensionalData.X, DimensionalData.Y, DimensionalData.Z, DimensionalData.Ti
import DimensionalData.Between, DimensionalData.At, DimensionalData.Near

export NMRData
export dims, X, Y, Z, Ti
export xval, yval, zval, tval
export At, Near, Between
export haspseudodimension, HasPseudoDimension
export NMRToolsException
export loadnmr
export data, acqus, label, label!, metadata, metadatahelp, scale
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
