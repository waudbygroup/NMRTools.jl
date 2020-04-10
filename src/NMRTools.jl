module NMRTools

using Lazy
using Reexport
using SimpleTraits
@reexport using DimensionalData

export NMRData
export HasPseudoDimension
export X, Y, Z, Ti
export NMRToolsException
export loadnmr

include("exceptions.jl")
include("nmrdata.jl")
include("loadnmr.jl")


end # module
