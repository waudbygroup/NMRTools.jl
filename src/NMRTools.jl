module NMRTools

using PrecompileTools
using Reexport: Reexport
using MulticomplexNumbers

include("NMRBase/NMRBase.jl")
include("NMRIO/NMRIO.jl")

Reexport.@reexport using .NMRBase
Reexport.@reexport using .NMRIO
Reexport.@reexport using MulticomplexNumbers

include("precompile.jl")

end
