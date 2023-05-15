module NMRIO

using ..NMRBase

include("loadnmr.jl")
include("loadnmrpipe.jl")
include("jdx.jl")
include("acqus.jl")

export loadnmr
export loadjdx

end
