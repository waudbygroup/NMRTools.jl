# MakieExt.jl
module MakieExt

@info "Loading MakieExt"

using Makie
using NMRTools
# using NMRTools.NMRBase
using SimpleTraits

import NMRTools: nmrplot, nmrplot!
import NMRTools: nmrcontour, nmrcontour!  
import NMRTools: nmrheatmap, nmrheatmap!
import NMRTools: nmrsurface, nmrsurface!

# Helper functions (as before)
function get_axis_label(ax::NMRDimension)
    label = ax[:label]
    units = ax[:units]
    if !isnothing(units)
        return "$label ($units)" 
    end
    return label
end

function scale_data(spec::NMRData)
    data(spec) ./ scale(spec)
end

# 1D Recipe
@recipe(NMRPlot) do scene
    Attributes(
        color = :black,
        linewidth = 1,
        label = nothing,
        normalized = true
    )
end
# argument_names(::Type{<:NMRPlot}) = (:spec,)
conversion_trait(::Type{<:NMRPlot}) = PointBased()

function Makie.plot!(p::NMRPlot{<:Tuple{<:NMRData{T,1}}}) where T
    spec = p[1][]
    x = data(spec, dims(spec,1))
    y = p.normalized[] ? scale_data(spec) : data(spec)
        
    ax = current_axis()
    if ax === nothing
        ax = Axis(current_figure()[1,1])
    end
    
    # Configure frequency axes
    if dims(spec,1) isa FrequencyDimension
        ax.xreversed = true
        ax.xlabel = get_axis_label(dims(spec,1))
    end
    
    lines!(p, x, y; color=p.color, linewidth=p.linewidth, label=p.label)
    
    return p
end

function Makie.get_plots(plot::NMRPlot)
    return plot.plots
end

# Multiple 1D spectra
function Makie.plot!(p::NMRPlot{<:Tuple{<:Vector{<:NMRData{T,1}}}}) where T
    specs = p[1][]
    isempty(specs) && return p

    ax = current_axis()
    if ax === nothing
        ax = Axis(current_figure()[1,1])
    end

    # Configure frequency axes from first spectrum
    if dims(first(specs),1) isa FrequencyDimension
        ax.xreversed = true 
        ax.xlabel = get_axis_label(dims(first(specs),1))
    end

    # colors = Makie.default_palettes.color[]
    for (i, spec) in enumerate(specs)
        x = data(spec, dims(spec,1))
        y = p.normalized[] ? scale_data(spec) : data(spec)
        
        # color = colors[mod1(i, length(colors))]
        lines!(p, x, y; linewidth=p.linewidth, label=label(spec))
    end

    return p
end


# 2D Recipe
@recipe(NMRContour) do scene
    Attributes(
        # levels = @inherit levels 11,
        # colormap = @inherit colormap :viridis,
        levels = :automatic,
        # colormap = :viridis,
        # colorrange = :automatic,
        normalized = true
    )
end
argument_names(::Type{<:NMRContour}) = (:spec,)

function Makie.plot!(p::NMRContour{<:Tuple{<:NMRData{T,2}}}) where T
    spec = p[1][]
    
    # Check dimensions
    if !all(d -> d isa FrequencyDimension, dims(spec))
        error("Contour plots only supported for 2D frequency domain data")
    end
    
    ax = current_axis()
    if ax === nothing
        ax = Axis(current_figure()[1,1])
    end
    
    # Configure frequency axes
    ax.xreversed = true
    ax.yreversed = true
    ax.xlabel = get_axis_label(dims(spec,1))
    ax.ylabel = get_axis_label(dims(spec,2))
    
    x = data(spec, dims(spec,1))
    y = data(spec, dims(spec,2))
    scaling = p.normalized[] ? 1/scale(spec) : 1
    z = scaling * data(spec)
    
    # Set default contour levels based on noise if not specified
    if p.levels[] == :automatic
        noise = spec[:noise]
        levels = scaling * [5*noise * 1.4^n for n in 1:20]
        # Plot positive and negative contours
        cont_neg = contour!(p, x, y, z, levels=-levels, color=:red)
        cont_pos = contour!(p, x, y, z, levels=levels, color=:blue)
    else
        cont = contour!(p, x, y, z, levels=scaling * p.levels) #colormap=p.colormap,
                    #    colorrange=p.colorrange)
        # Colorbar(current_figure()[1,2], cont)
    end
    
    return p
end

# Heatmap recipe for pseudo-2D
@recipe(NMRHeatmap) do scene
    Attributes(
        colormap = :viridis,
        # colorrange = automatic,
        normalized = true
    )
end
argument_names(::Type{<:NMRHeatmap}) = (:spec,)

function Makie.plot!(p::NMRHeatmap{<:Tuple{<:NMRData{T,2}}}) where T
    spec = p[1][]
    
    ax = current_axis()
    if ax === nothing
        ax = Axis(current_figure()[1,1])
    end
    
    # Configure axes
    if dims(spec,1) isa FrequencyDimension
        ax.xreversed = true
    end
    if dims(spec,2) isa FrequencyDimension
        ax.yreversed = true
    end
    ax.xlabel = get_axis_label(dims(spec,1))
    ax.ylabel = get_axis_label(dims(spec,2))
    
    x = data(spec, dims(spec,1))
    y = data(spec, dims(spec,2))
    z = p.normalized[] ? scale_data(spec) : data(spec)
    
    hm = heatmap!(p, x, y, z, colormap=p.colormap)#, colorrange=p.colorrange)
    Colorbar(current_figure()[1,2], hm)
    
    return p
end

# Surface recipe 
@recipe(NMRSurface) do scene
    Attributes(
        colormap = :viridis,
        colorrange = Makie.automatic,
        normalized = true,
        shading = Makie.automatic
    )
end
argument_names(::Type{<:NMRSurface}) = (:spec,)
Makie.args_preferred_axis(::Type{<: NMRSurface}) =  Axis3

function Makie.plot!(p::NMRSurface{<:Tuple{<:NMRData{T,2}}}) where T
    spec = p[1][]
    
    ax = current_axis()
    if ax === nothing
        ax = Axis3(current_figure()[1,1])
    end
    
    x = data(spec, dims(spec,1))
    y = data(spec, dims(spec,2))
    z = p.normalized[] ? scale_data(spec) : data(spec)
    
    # Configure axes
    if dims(spec,1) isa FrequencyDimension
        ax.xreversed = true
    end
    if dims(spec,2) isa FrequencyDimension
        ax.yreversed = true
    end
    ax.xlabel = get_axis_label(dims(spec,1))
    ax.ylabel = get_axis_label(dims(spec,2))
    
    surf = surface!(p, x, y, z, colormap=p.colormap, colorrange=p.colorrange, 
                   shading=p.shading)
    Colorbar(current_figure()[1,2], surf)
    
    return p
end

# # Convenience functions
# nmrplot(args...; kw...) = NMRPlot(args...; kw...)
# nmrplot!(args...; kw...) = NMRPlot!(args...; kw...)
# nmrcontour(args...; kw...) = NMRContour(args...; kw...)
# nmrcontour!(args...; kw...) = NMRContour!(args...; kw...)
# nmrheatmap(args...; kw...) = NMRHeatmap(args...; kw...)
# nmrheatmap!(args...; kw...) = NMRHeatmap!(args...; kw...)
# nmrsurface(args...; kw...) = NMRSurface(args...; kw...)
# nmrsurface!(args...; kw...) = NMRSurface!(args...; kw...)

end # module