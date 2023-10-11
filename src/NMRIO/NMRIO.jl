module NMRIO

using ..NMRBase

include("types.jl")
include("loadnmr.jl")
include("jdx.jl")
include("acqus.jl")
include("nmrpipe.jl")
include("bruker.jl")

export loadnmr
export loadjdx
export FQ

end
