module NMRTools

using Lazy
using Reexport
using SimpleTraits
using OffsetArrays
using DimensionalData

export isnmrdata, IsNMRData
export haspseudodimension, HasPseudoDimension
export NMRToolsException
export loadnmr
export metadatahelp
export WindowFunction, NullWindow, UnknownWindow, ExponentialWindow, SineWindow, GaussWindow

# type definitions
include("exceptions.jl")
include("nmrdata.jl")
include("windows.jl")

# routines
include("loadnmr.jl")

end # module
