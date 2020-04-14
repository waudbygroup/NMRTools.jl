module NMRTools

using Lazy
using Formatting
using Reexport
using SimpleTraits
using DimensionalData

export HasPseudoDimension
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
