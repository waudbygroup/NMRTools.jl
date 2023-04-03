module NMRTools

using Reexport: Reexport

include("NMRBase/NMRBase.jl")
include("NMRPlots/NMRPlots.jl")

Reexport.@reexport using .NMRBase
Reexport.@reexport using .NMRPlots

end
