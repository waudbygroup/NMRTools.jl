module NMRIO

using ..NMRBase
using Artifacts
using ArtifactUtils

include("lists.jl")
include("loadnmr.jl")
include("jdx.jl")
include("acqus.jl")
include("nmrpipe.jl")
include("bruker.jl")
include("ucsf.jl")
include("exampledata.jl")


export loadnmr
export loadjdx
export FQList, getppm, getoffset

# examples
export exampledata

end
