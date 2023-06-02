module NMRTools

using PrecompileTools
using Reexport: Reexport

include("NMRBase/NMRBase.jl")
include("NMRIO/NMRIO.jl")

Reexport.@reexport using .NMRBase
Reexport.@reexport using .NMRIO

include("precompile.jl")

end
