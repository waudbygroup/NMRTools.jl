module NMRIO

using ..NMRBase
using Artifacts
using ArtifactUtils
using Dates
using LazyArtifacts
using YAML

include("lists.jl")
include("loadnmr.jl")
include("jdx.jl")
include("acqus.jl")
include("nmrpipe.jl")
include("bruker.jl")
include("annotation.jl")
include("ucsf.jl")
include("exampledata.jl")
include("sumexpts.jl")

export loadnmr
export loadjdx
export FQList
export sumexpts

# examples
export exampledata

end
