struct HeatMapLike end
struct WireframeLike end
struct SeriesLike end
struct HistogramLike end
struct ViolinLike end

# 1D plot
@recipe function f(A::NMRData{T,1}) where T
    Afwd = DimensionalData.forwardorder(A) # make sure data axes are in forwards order
    dim = dims(Afwd, 1)

    # force 1D to be a line plot
    seriestype := :path
    markershape --> :none
    linecolor --> :blue

    # set default title
    title --> DimensionalData.refdims_title(Afwd)
    legend := false

    xlabel --> "$(Afwd[dim,:label]) chemical shift / ppm"
    xflip := true
    xgrid --> false
    xtick_direction --> :out

    ylabel --> ""
    yshowaxis --> false
    yticks --> [0,]


    val(dim), parent(A)
end
