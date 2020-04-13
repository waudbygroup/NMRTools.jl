module NMRTools

using Lazy
using Formatting
using Reexport
using SimpleTraits
@reexport using DimensionalData

export NMRData
export HasPseudoDimension
export X, Y, Z, Ti
export NMRToolsException
export loadnmr
export metadatahelp

include("exceptions.jl")
include("nmrdata.jl")
include("loadnmr.jl")


end # module
