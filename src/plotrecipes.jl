struct ContourLike end

contourlevels(spacing=1.7, n=12) = (spacing^i for i=0:(n-1))

# 1D plot
@recipe function f(A::NMRData{T,1}; normalize=false) where T
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
    yticks --> [0,]

    delete!(plotattributes, :normalize)
    scale = normalize ? A[:ns]*A[:rg] : 1
    val(dim), parent(A) ./ scale
end



# multiple 1D plots
@recipe function f(v::Vector{<:NMRData{T,1} where T}; normalize=false, vstack=false)
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

    delete!(plotattributes, :vstack)
    delete!(plotattributes, :normalize)

    voffset = 0
    vdelta = maximum([
            maximum(abs.(A)) / (normalize ? A[:ns]*A[:rg] : 1)
            for A in v]) / length(v)

    if vstack
        yticks --> voffset .+ (0:length(v)-1)*vdelta
    else
        yticks --> [0,]
    end

    for A in v
        @series begin
            seriestype := :path
            Afwd = DimensionalData.forwardorder(A) # make sure data axes are in forwards order
            dim = dims(Afwd, 1)
            label --> label(A)
            scale = normalize ? A[:ns]*A[:rg] : 1
            val(dim), parent(A)./scale .+ voffset
        end
        vstack && (voffset += vdelta)
    end
end



# 2D plot
@recipe function f(A::NMRData{T,2}) where T
    sertype = get(plotattributes, :seriestype, :none)

    if !haspseudodimension(A) && sertype in [:contour, :heatmap, :image, :surface, :wireframe]
        ContourLike(), A
    else
        # TODO pseudo2D plots
        data(A)
    end
end



@recipe function f(::ContourLike, A::NMRData{T,2}) where T
    Afwd = DimensionalData.forwardorder(A) # make sure data axes are in forwards order
    Afwd = DimensionalData.maybe_permute(Afwd, (YDim, XDim))
    y, x = dims(Afwd)

    # set default title
    title --> DimensionalData.refdims_title(Afwd)
    legend --> false
    framestyle --> :box

    xlabel --> "$(Afwd[x,:label]) chemical shift / ppm"
    xflip --> true
    xgrid --> false
    xtick_direction --> :out

    ylabel --> "$(Afwd[y,:label]) chemical shift / ppm"
    yflip --> true
    ygrid --> false
    ytick_direction --> :out

    basecolor = get(plotattributes, :linecolor, :blue)
    colors = sequential_palette(hue(convert(HSV,parse(Colorant, basecolor))),5)[[4,2]]

    #delete!(plotattributes, :normalize)
    #scale = normalize ? A[:ns]*A[:rg] : 1
    #val(dim), parent(A) ./ scale
    @series begin
        levels --> 5*Afwd[:noise].*contourlevels()
        linecolor := colors[1]
        val(x), val(y), data(Afwd)
    end
    @series begin
        levels --> -5*Afwd[:noise].*contourlevels()
        linecolor := colors[2]
        val(x), val(y), data(Afwd)
    end


end
