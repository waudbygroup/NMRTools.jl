module PlotsExt

@info "Loading PlotsExt"

"""
notes on testing:
]activate --temp
]dev .
]add Plots
using NMRTools, Plots
"""

using NMRTools
using Plots
using SimpleTraits
using Colors
using ColorSchemes

struct ContourLike end

contourlevels(spacing=1.7, n=12) = (spacing^i for i=0:(n-1))

axislabel(dat::NMRData, n=1) = axislabel(dims(dat,n))
axislabel(dim::FrequencyDimension) = "$(label(dim)) chemical shift (ppm)"
function axislabel(dim::NMRDimension)
    if isnothing(units(dim))
        "$(label(dim))"
    else
        "$(label(dim)) ($(units(dim)))"
    end
end

# 1D plot (frequency)
@recipe function f(A::NMRData{T,1, Tuple{D}}; normalize=true) where {T, D<:FrequencyDimension}
    Afwd = reorder(A, ForwardOrdered) # make sure data axes are in forwards order
    x = dims(Afwd, 1)

    # recommend 1D to be a line plot
    seriestype --> :path
    markershape --> :none

    # set default title
    title --> ifelse(isempty(refdims(Afwd)), label(Afwd), refdims_title(Afwd))

    # turn off legend, but provide a label in case the user wishes
    legend --> false
    label --> label(A)

    xguide --> axislabel(A)
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    yguide --> ""
    yshowaxis --> false
    yticks --> nothing

    delete!(plotattributes, :normalize)
    data(x), data(Afwd) ./ (normalize ? scale(Afwd) : 1)
end



# 1D plot (non-frequency)
@recipe function f(A::NMRData{T,1, Tuple{D}}; normalize=true) where {T, D<:NonFrequencyDimension}
    Afwd = reorder(A, ForwardOrdered) # make sure data axes are in forwards order
    x = dims(Afwd, 1)

    # recommend 1D to be a scatter plot
    seriestype --> :scatter

    # set default title
    title --> ifelse(isempty(refdims(Afwd)), label(Afwd), refdims_title(Afwd))
    
    # turn off legend, but provide a label in case the user wishes
    legend --> false
    label --> label(A)

    xguide --> axislabel(A)
    xflip --> false
    xtick_direction --> :out
    
    yguide --> "Intensity"
    yshowaxis --> true
    yticks --> :out
    # yerror --> A[:noise] * ones(length(A)) ./ (normalize ? scale(Afwd) : 1)

    widen --> true
    if minimum(x) < 0
        if maximum(x) < 0
            xlims --> (-Inf, 0)
        end
    else
        xlims --> (0, Inf)
    end
    if minimum(A) < 0
        if maximum(A) < 0
            ylims --> (-Inf, 0)
        end
    else
        ylims --> (0, Inf)
    end
    
    grid --> false
    frame --> :box

    delete!(plotattributes, :normalize)
    data(x), data(Afwd) ./ (normalize ? scale(Afwd) : 1)
end



# multiple 1D plots
@recipe function f(v::Vector{<:NMRData{T,1} where T}; normalize=true, vstack=false)
    # recommend 1D to be a line plot
    seriestype --> :path
    markershape --> :none

    # use the first entry to determine axis label
    xguide --> axislabel(v[1])
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    yguide --> ""
    yshowaxis --> false
    yticks --> nothing

    delete!(plotattributes, :vstack)
    delete!(plotattributes, :normalize)

    voffset = 0
    vdelta = maximum([
            maximum(abs.(A)) / (normalize ? scale(A) : 1)
            for A in v]) / length(v)

    # TODO add guide lines
    # if vstack
    #     yticks --> voffset .+ (0:length(v)-1)*vdelta
    # else
    #     yticks --> [0,]
    # end

    for A in v
        @series begin
            seriestype --> :path
            markershape --> :none
            Afwd = reorder(A, ForwardOrdered) # make sure data axes are in forwards order
            x = dims(Afwd, 1)
            label --> label(A)
            data(x), data(Afwd) ./ (normalize ? scale(A) : 1) .+ voffset
        end
        if vstack
            voffset += vdelta
        end
    end
end



# 2D plot
@recipe f(d::D; normalize=true, usegradient=false) where {D<:NMRData{T,2} where T} = SimpleTraits.trait(HasNonFrequencyDimension{D}), d

@recipe function f(::Type{Not{HasNonFrequencyDimension{D}}}, d::D) where {D<:NMRData{T, 2} where T}
    seriestype --> :contour

    dfwd = reorder(d, ForwardOrdered) # make sure data axes are in forwards order
    # dfwd = DimensionalData.maybe_permute(dfwd, (YDim, XDim))
    x, y = dims(dfwd)

    # set default title
    title --> label(d)
    legend --> false
    framestyle --> :box

    xguide --> axislabel(x)
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    yguide --> axislabel(y)
    yflip --> true
    ygrid --> false
    ytick_direction --> :out

    normalize = get(plotattributes, :normalize, true)
    delete!(plotattributes, :normalize)
    scaling = normalize ? scale(dfwd) : 1

    stype = get(plotattributes, :seriestype, nothing)
    if stype ∈ [:heatmap, :wireframe]
        # heatmap
        data(x), data(y), permutedims(data(dfwd / scaling))
    else
        # generate light and dark colours for plot contours, based on supplied colour
        # - create a 5-tone palette with the same hue as the passed colour, and select the
        # fourth and second entries to provide dark and light shades
        basecolor = get(plotattributes, :seriescolor, :blue)
        
        colors = sequential_palette(hue(convert(HSV,parse(Colorant, basecolor))),5)[[4,2]]
        
        @series begin
            levels --> 5 * dfwd[:noise] / scaling .* contourlevels()
            seriescolor := colors[1]
            primary --> true
            data(x), data(y), permutedims(data(dfwd / scaling))
        end
        @series begin
            levels --> -5 * dfwd[:noise] / scaling .* contourlevels()
            seriescolor := colors[2]
            primary := false
            data(x), data(y), permutedims(data(dfwd / scaling))
        end
    end
end


# pseudo-2D
# TODO FIX need to treat differently if user asks for a heatmap
@recipe function f(::Type{HasNonFrequencyDimension{D}}, d::D) where {D<:NMRData{T, 2} where T}
    z = reorder(d, ForwardOrdered) # make sure data axes are in forwards order
    # z = DimensionalData.maybe_permute(z, (YDim, XDim))
    if dims(z)[1] isa NonFrequencyDimension
        z = transpose(z)
    end
    x, y = dims(z)
    
    # set default title
    title --> label(d)
    legend --> false
    framestyle --> :box

    xguide --> axislabel(x)
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    yguide --> axislabel(y)
    yflip --> false
    ygrid --> false
    ytick_direction --> :out
   
    normalize = get(plotattributes, :normalize, true)
    delete!(plotattributes, :normalize)

    scaling = normalize ? scale(z) : 1

    stype = get(plotattributes, :seriestype, nothing)
    if stype ∈ [:heatmap, :wireframe]
        # heatmap
        data(x), data(y), permutedims(data(z)) ./ scaling
    else
        # default

        # TODO - BUG - this attribute isn't recognised
        gradient = get(plotattributes, :usegradient, false)
        delete!(plotattributes, :usegradient)
    
        palettesize = length(y)
        if palettesize > 64
            palettesize = floor(palettesize/4)
        elseif palettesize > 48
            palettesize = floor(palettesize/3)
        elseif palettesize > 32
            palettesize = floor(palettesize/2)
        elseif palettesize > 16
            palettesize = 16
        end
        
        # don't set a gradient palette if colours already specified
        setpalette = :seriescolor ∉ keys(plotattributes) ||
            :linecolor ∉ keys(plotattributes)
    
        xones = ones(length(x))
        for i=1:length(y)
            @series begin
                seriestype --> :path3d
                seriescolor --> i
    
                if gradient
                    line_z --> data(z)[:,i]  # colour by height
                    palette --> :darkrainbow
                else
                    if setpalette
                        palette --> palette(:phase,11)
                    end
                end
                primary --> (i==1)
                fillrange --> 0 # not currently implemented in plots for 3D data
                data(x), xones * y[i], data(z)[:,i] / scaling
            end
        end
    end
end


# multiple 2D plots
@recipe f(v::Vector{D}; normalize=true) where {D<:NMRData{T,2}} where {T} = SimpleTraits.trait(HasNonFrequencyDimension{D}), v



@recipe function f(::Type{Not{HasNonFrequencyDimension{D}}}, v::Vector{D}) where {D<:NMRData{T,2}} where {T}
    n = length(v)
    hues = map(h->HSV(h,0.5,0.5), (0:n-1) .* (360/n))
    
    seriestype --> :contour
    
    dfwd = reorder(v[1], ForwardOrdered) # make sure data axes are in forwards order
    # dfwd = DimensionalData.maybe_permute(dfwd, (YDim, XDim))
    x, y = dims(dfwd)
    
    # set default title
    title --> ""
    # legend --> :outerright
    colorbar --> nothing
    framestyle --> :box
    
    xguide --> axislabel(x)
    xflip --> true
    xgrid --> false
    xtick_direction --> :out
    
    yguide --> axislabel(y)
    yflip --> true
    ygrid --> false
    ytick_direction --> :out
    
    normalize = get(plotattributes, :normalize, true)
    delete!(plotattributes, :normalize)

    @info "plotting vector of 2D NMR data (normalize = $normalize)"
    
    h = 0.

    for d in v
        dfwd = reorder(d, ForwardOrdered) # make sure data axes are in forwards order
        # dfwd = DimensionalData.maybe_permute(dfwd, (YDim, XDim))
        x, y = dims(dfwd)
        colors = sequential_palette(h, 5)[[4,2]]
        if normalize
            scaling = scale(dfwd)
            σ = first(v)[:noise] / scale(first(v)) # use the first experiment to set contour levels from noise
        else
            scaling = 1
            σ = dfwd[:noise]
        end
        @series begin
            levels --> 5σ .* contourlevels()
            seriescolor := colors[1]
            primary := false # true
            label := nothing
            data(x), data(y), permutedims(data(dfwd / scaling))
        end
        @series begin
            levels --> -5σ .* contourlevels()
            seriescolor := colors[2]
            primary := false
            label := nothing
            data(x), data(y), permutedims(data(dfwd / scaling))
        end
        @series begin
            seriestype := :path
            seriescolor := colors[1]
            primary --> true
            label --> label(dfwd)
            [], []
        end
        h += 360.0/n
    end
end



@recipe function f(::Type{HasNonFrequencyDimension{D}}, v::Vector{D}) where {D<:NMRData{T,2}} where {T}
    @warn "plot recipe for series of pseudo-2D NMR data not yet well-defined"
    # just make repeat calls to single plot recipe
    for d in v
        @series begin
            HasPseudoDimension{D}, d
        end
    end
end


end # module