module NMRIO

using ..NMRBase

include("lists.jl")
include("loadnmr.jl")
include("jdx.jl")
include("acqus.jl")
include("nmrpipe.jl")
include("bruker.jl")
include("ucsf.jl")

export loadnmr
export loadjdx
export FQList, getppm, getoffset

end
