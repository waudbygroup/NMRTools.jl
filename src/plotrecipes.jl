struct ContourLike end

contourlevels(spacing=1.7, n=12) = (spacing^i for i=0:(n-1))

# 1D plot
@recipe function f(A::NMRData{T,1}; normalize=true) where T
    Afwd = DimensionalData.forwardorder(A) # make sure data axes are in forwards order
    dim = dims(Afwd, 1)

    # force 1D to be a line plot
    seriestype := :path
    markershape --> :none

    # set default title
    title --> DimensionalData.refdims_title(Afwd)
    legend --> false

    xlabel --> "$(Afwd[dim,:label]) chemical shift / ppm"
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    ylabel --> ""
    yshowaxis --> false
    yticks --> nothing

    delete!(plotattributes, :normalize)
    val(dim), parent(A)./(normalize ? scale(A) : 1)
end



# multiple 1D plots
@recipe function f(v::Vector{<:NMRData{T,1} where T}; normalize=true, vstack=false)
    # force 1D to be a line plot
    seriestype := :path
    markershape --> :none

    # get the first entry to determine axis label
    Afwd = DimensionalData.forwardorder(v[1])
    dim = dims(Afwd, 1)

    xlabel --> "$(Afwd[dim,:label]) chemical shift / ppm"
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    ylabel --> ""
    yshowaxis --> false
    yticks --> nothing

    delete!(plotattributes, :vstack)
    delete!(plotattributes, :normalize)

    voffset = 0
    vdelta = maximum([
            maximum(abs.(A)) / (normalize ? A[:ns]*A[:rg] : 1)
            for A in v]) / length(v)

    # TODO add guide lines
    # if vstack
    #     yticks --> voffset .+ (0:length(v)-1)*vdelta
    # else
    #     yticks --> [0,]
    # end

    for A in v
        @series begin
            seriestype := :path
            Afwd = DimensionalData.forwardorder(A) # make sure data axes are in forwards order
            dim = dims(Afwd, 1)
            label --> label(A)
            val(dim), parent(A)./(normalize ? scale(A) : 1) .+ voffset
        end
        vstack && (voffset += vdelta)
    end
end



# 2D plot
@recipe f(d::D) where {D<:NMRData{T,2} where T} = SimpleTraits.trait(HasPseudoDimension{D}), d

@recipe function f(::Type{Not{HasPseudoDimension{D}}}, d::D) where {D<:NMRData{T, 2} where T}
    dfwd = DimensionalData.forwardorder(d) # make sure data axes are in forwards order
    dfwd = DimensionalData.maybe_permute(dfwd, (YDim, XDim))
    y, x = dims(dfwd)

    # set default title
    title --> DimensionalData.refdims_title(dfwd)
    legend --> false
    framestyle --> :box

    xlabel --> "$(dfwd[x,:label]) chemical shift / ppm"
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    ylabel --> "$(dfwd[y,:label]) chemical shift / ppm"
    yflip --> true
    ygrid --> false
    ytick_direction --> :out

    # generate light and dark colours for plot contours, based on supplied colour
    # - create a 5-tone palette with the same hue as the passed colour, and select the
    # fourth and second entries to provide dark and light shades
    basecolor = get(plotattributes, :linecolor, :blue)
    colors = sequential_palette(hue(convert(HSV,parse(Colorant, basecolor))),5)[[4,2]]

    #delete!(plotattributes, :normalize)
    #scale = normalize ? A[:ns]*A[:rg] : 1
    #val(dim), parent(A) ./ scale
    @series begin
        levels --> 5*dfwd[:noise].*contourlevels()
        linecolor := colors[1]
        primary := true
        val(x), val(y), data(dfwd)
    end
    @series begin
        levels --> -5*dfwd[:noise].*contourlevels()
        linecolor := colors[2]
        primary := false
        val(x), val(y), data(dfwd)
    end
end


@recipe function f(::Type{HasPseudoDimension{D}}, d::D) where {D<:NMRData{T, 2} where T}
    # TODO define recipe for pseudo2D data
    dfwd = DimensionalData.forwardorder(d) # make sure data axes are in forwards order
    dfwd = DimensionalData.maybe_permute(dfwd, (YDim, XDim))
    y, x = dims(dfwd)
    @info "plot recipe for pseudo2D data not yet defined"
    val(x), val(y), data(dfwd)
end



# multiple 2D plots
@recipe f(v::Vector{D}; normalize=true) where {D<:NMRData{T,2}} where {T} = SimpleTraits.trait(HasPseudoDimension{D}), v



@recipe function f(::Type{Not{HasPseudoDimension{D}}}, v::Vector{D}; normalize=true) where {D<:NMRData{T,2}} where {T}
    @info "plotting vector of 2D NMR data"
    n = length(v)
    hues = map(h->HSV(h,0.5,0.5), (0:n-1) .* (360/n))

    # force 1D to be a line plot
    seriestype := :contour

    # get the first entry to determine axis label
    dfwd = DimensionalData.forwardorder(v[1]) # make sure data axes are in forwards order
    dfwd = DimensionalData.maybe_permute(dfwd, (YDim, XDim))
    y, x = dims(dfwd)

    # set default title
    title --> DimensionalData.refdims_title(dfwd)
    legend --> false
    framestyle --> :box

    xlabel --> "$(dfwd[x,:label]) chemical shift / ppm"
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    ylabel --> "$(dfwd[y,:label]) chemical shift / ppm"
    yflip --> true
    ygrid --> false
    ytick_direction --> :out

    delete!(plotattributes, :normalize)

    h = 0.0
    for d in v
        dfwd = DimensionalData.forwardorder(d) # make sure data axes are in forwards order
        dfwd = DimensionalData.maybe_permute(dfwd, (YDim, XDim))
        y, x = dims(dfwd)
        label --> label(d)
        # generate light and dark colours for plot contours, based on supplied colour
        # - create a 5-tone palette with the same hue as the passed colour, and select the
        # fourth and second entries to provide dark and light shades
        colors = sequential_palette(h, 5)[[4,2]]

        @series begin
            levels --> 5*dfwd[:noise].*contourlevels()
            linecolor := colors[1]
            primary := true
            val(x), val(y), data(dfwd)
        end
        @series begin
            levels --> -5*dfwd[:noise].*contourlevels()
            linecolor := colors[2]
            primary := false
            val(x), val(y), data(dfwd)
        end
        h += 360.0/n
    end
end



@recipe function f(::Type{HasPseudoDimension{D}}, v::Vector{D}; normalize=true) where {D<:NMRData{T,2}} where {T}
    @info "plot recipe for vector of pseudo2D NMR data not yet implemented"
    delete!(plotattributes, :normalize)
    # TODO just make repeat calls to single plot recipe
    for d in v
        @series begin
            HasPseudoDimension{D}, d
        end
    end
end
