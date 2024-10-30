module NMRTools

using PrecompileTools
using Reexport: Reexport

include("NMRBase/NMRBase.jl")
include("NMRIO/NMRIO.jl")

Reexport.@reexport using .NMRBase
Reexport.@reexport using .NMRIO

include("precompile.jl")

export nmrplot, nmrplot!, nmrcontour, nmrcontour!, nmrheatmap, nmrheatmap!, nmrsurface, nmrsurface!
function nmrplot end
function nmrplot! end
function nmrcontour end
function nmrcontour! end
function nmrheatmap end
function nmrheatmap! end
function nmrsurface end
function nmrsurface! end

end
