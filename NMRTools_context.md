Path: ./ext/PlotsExt.jl

```julia
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

contourlevels(spacing=1.7, n=12) = (spacing^i for i in 0:(n - 1))

axislabel(dat::NMRData, n=1) = axislabel(dims(dat, n))
axislabel(dim::FrequencyDimension) = "$(label(dim)) chemical shift (ppm)"
function axislabel(dim::NMRDimension)
    if isnothing(units(dim))
        "$(label(dim))"
    else
        "$(label(dim)) ($(units(dim)))"
    end
end

# 1D plot (frequency)
@recipe function f(A::NMRData{T,1,Tuple{D}}; normalize=true) where {T,D<:FrequencyDimension}
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
    return data(x), data(Afwd) ./ (normalize ? scale(Afwd) : 1)
end

# 1D plot (non-frequency)
@recipe function f(A::NMRData{T,1,Tuple{D}};
                   normalize=true) where {T,D<:NonFrequencyDimension}
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
    return data(x), data(Afwd) ./ (normalize ? scale(Afwd) : 1)
end

# multiple 1D plots
@recipe function f(v::Vector{<:NMRData{T,1} where {T}}; normalize=true, vstack=false)
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
    vdelta = maximum([maximum(abs.(A)) / (normalize ? scale(A) : 1)
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
@recipe function f(d::D; normalize=true,
                   usegradient=false) where {D<:NMRData{T,2} where {T}}
    return SimpleTraits.trait(HasNonFrequencyDimension{D}), d
end

@recipe function f(::Type{Not{HasNonFrequencyDimension{D}}},
                   d::D) where {D<:NMRData{T,2} where {T}}
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

        colors = sequential_palette(hue(convert(HSV, parse(Colorant, basecolor))), 5)[[4,
                                                                                       2]]

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
@recipe function f(::Type{HasNonFrequencyDimension{D}},
                   d::D) where {D<:NMRData{T,2} where {T}}
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
            palettesize = floor(palettesize / 4)
        elseif palettesize > 48
            palettesize = floor(palettesize / 3)
        elseif palettesize > 32
            palettesize = floor(palettesize / 2)
        elseif palettesize > 16
            palettesize = 16
        end

        # don't set a gradient palette if colours already specified
        setpalette = :seriescolor ∉ keys(plotattributes) ||
                     :linecolor ∉ keys(plotattributes)

        xones = ones(length(x))
        for i in 1:length(y)
            @series begin
                seriestype --> :path3d
                seriescolor --> i

                if gradient
                    line_z --> data(z)[:, i]  # colour by height
                    palette --> :darkrainbow
                else
                    if setpalette
                        palette --> palette(:phase, 11)
                    end
                end
                primary --> (i == 1)
                fillrange --> 0 # not currently implemented in plots for 3D data
                data(x), xones * y[i], data(z)[:, i] / scaling
            end
        end
    end
end

# multiple 2D plots
@recipe function f(v::Vector{D}; normalize=true) where {D<:NMRData{T,2}} where {T}
    return SimpleTraits.trait(HasNonFrequencyDimension{D}), v
end

@recipe function f(::Type{Not{HasNonFrequencyDimension{D}}},
                   v::Vector{D}) where {D<:NMRData{T,2}} where {T}
    n = length(v)
    hues = map(h -> HSV(h, 0.5, 0.5), (0:(n - 1)) .* (360 / n))

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

    h = 0.0

    for d in v
        dfwd = reorder(d, ForwardOrdered) # make sure data axes are in forwards order
        # dfwd = DimensionalData.maybe_permute(dfwd, (YDim, XDim))
        x, y = dims(dfwd)
        colors = sequential_palette(h, 5)[[4, 2]]
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
        h += 360.0 / n
    end
end

@recipe function f(::Type{HasNonFrequencyDimension{D}},
                   v::Vector{D}) where {D<:NMRData{T,2}} where {T}
    @warn "plot recipe for series of pseudo-2D NMR data not yet well-defined"
    # just make repeat calls to single plot recipe
    for d in v
        @series begin
            HasPseudoDimension{D}, d
        end
    end
end

end # module```

-----------

Path: ./docs/make.jl

```julia
using Documenter, NMRTools, Plots

ENV["GKSwstype"] = "100"

DocMeta.setdocmeta!(NMRTools, :DocTestSetup, :(using NMRTools); recursive=true)

makedocs(;
    modules=[NMRTools],
    format=Documenter.HTML(prettyurls=(get(ENV, "CI", nothing) == "true")),
    pages=[
        "Home" => "index.md",
        "Getting started" => "quickstart.md",
        "Tutorials" => [
            "Working with NMR data" => "tutorial-data.md",
            # "Non-frequency dimensions" => "tutorial-nonfreqdims.md",
            "Plotting" => "tutorial-plotrecipes.md",
            "Metadata" => "tutorial-metadata.md",
            "Animating spectra" => "tutorial-animation.md",
            "1D relaxation analysis" => "tutorial-relaxation.md",
            "Diffusion analysis" => "tutorial-diffusion.md",
            # "2D phosphorylation kinetics" => "tutorial-phosphorylation.md",
        ],
        "Reference guide" => [
        #     "Data" => "ref-data.md",
        #     "Dimensions" => "ref-dimensions.md",
        #     "File I/O" => "ref-io.md",
            "Metadata" => "ref-metadata.md",
        #     "Window functions" => "ref-windows.md",
            "Coherences and isotope data" => "ref-coherences.md",
        #     "Exceptions" => "ref-exceptions.md",
        #     "Plotting with JuliaPlots" => "ref-plots.md",
        ],
        "API" => "api.md",
        "Index" => "indexes.md",
    ],
    # repo=GitHub("waudbygroup", "NMRTools.jl"),
    sitename="NMRTools.jl",
    authors="Chris Waudby",
    warnonly = [:missing_docs],
)

deploydocs(;
    repo="github.com/waudbygroup/NMRTools.jl.git",
    versions = ["stable" => "v^", "v#.#", "dev" => "master"],
)
```

-----------

Path: ./docs/tutorial.md

```
# Tutorial

## Installing NMRTools

`NMRTools` is available from the Julia package registry. Just call `using NMRTools` to include
it in your environment.

```@example 0
using Pkg
Pkg.add("NMRTools")
using NMRTools
```

## Plot a 1D spectrum

Let's load some example data. This can be a Bruker experiment directory, a specific pdata folder, or an NMRPipe-format file.

```@example 1
using NMRTools
# spec = loadnmr("exampledata/1D_19F/1/pdata/1")
spec = exampledata("1D_19F") # the exampledata function automatically downloads example spectra
```

NMRTools contains Plots recipes for common types of spectrum. To plot our 1D spectrum, we just use
the `plot` command:

```@example 1
using Plots
plot(spec);
savefig("plot-y.svg"); nothing # hide
```

![](plot-y.svg)

We can zoom in on a particular region using the `..` selector:

```@example 1
plot(spec[-124.5 .. -123]);
savefig("plot-y2.svg"); nothing # hide
```

![](plot-y2.svg)

All plots can be saved as high quality vector graphics or png files, using the `savefig` command:

```julia
savefig("myspectrum.pdf")
```


## Plot a series of 1D spectra

Load and plot multiple 1D spectra from a list of filenames

```@example 1Ds
using NMRTools, Plots
# filenames = ["exampledata/1D_19F_titration/1/",
#             "exampledata/1D_19F_titration/2/",
#             "exampledata/1D_19F_titration/3/",
#             "exampledata/1D_19F_titration/4/",
#             "exampledata/1D_19F_titration/5/",
#             "exampledata/1D_19F_titration/6/",
#             "exampledata/1D_19F_titration/7/",
#             "exampledata/1D_19F_titration/8/",
#             "exampledata/1D_19F_titration/9/",
#             "exampledata/1D_19F_titration/10/",
#             "exampledata/1D_19F_titration/11/"]
# spectra = [loadnmr(filename) for filename in filenames]
spectra = exampledata("1D_19F_titration")
plot(spectra)
savefig("plot-1Ds.svg"); nothing # hide
```

![](plot-1Ds.svg)

**Stacked views** can also be produced using the `vstack=true` option.

```@example 1Ds
plot(spectra, vstack=true);
savefig("plot-1Ds-stack.svg"); nothing # hide
```

![](plot-1Ds-stack.svg)

!!! note
    By default, spectra are normalized according to the number of scans and receiver gain determined automatically from the spectrum metadata; this can be disabled with the `normalize=false` option

!!! tip
    Legends are produced from the first line of the spectrum title file. The legend can be disabled using the `legend=nothing` option. To re-label a spectrum, use `label!(spectrum, "new label")`.



## Plot a 2D spectrum

Two-dimensional spectra can be plotted in exactly the same way as for 1Ds.

```@example 2d
using NMRTools, Plots
spec = exampledata("2D_HN")
plot(spec)
savefig("plot-2d.svg"); nothing # hide
```

![](plot-2d.svg)

Contour levels are set to five times the noise level. The most convenient way to adjust this is simply to multiply or divide the spectrum by some scaling factor. You can also adjust the title - by default taken from the spectrum label - using the `title` keyword. Use an empty string (`title=""`) to remove the title.

```@example 2d
plot(spec / 2, title="spectrum divided by two")
savefig("plot-2d-scaled.svg"); nothing # hide
```

![](plot-2d-scaled.svg)


## Overlaying multiple 2D spectra

Multiple 2D spectra can be loaded and overlaid in a similar manner to 1Ds

```@repl 2Ds
using NMRTools, Plots;
#filenames  = ["exampledata/2D_HN_titration/1/test.ft2",
#              "exampledata/2D_HN_titration/2/test.ft2",
#              "exampledata/2D_HN_titration/3/test.ft2",
#              "exampledata/2D_HN_titration/4/test.ft2",
#              "exampledata/2D_HN_titration/5/test.ft2",
#              "exampledata/2D_HN_titration/6/test.ft2",
#              "exampledata/2D_HN_titration/7/test.ft2",
#              "exampledata/2D_HN_titration/8/test.ft2",
#              "exampledata/2D_HN_titration/9/test.ft2",
#              "exampledata/2D_HN_titration/11/test.ft2"];
#              "exampledata/2D_HN_titration/10/test.ft2",
#spectra = [loadnmr(filename) for filename in filenames];
spectra = exampledata("2D_HN_titration")
plot(spectra);
savefig("plot-2Ds.svg"); nothing # hide
```

![](plot-2Ds.svg)


Adjust the plot limits with the usual `xlims!` and `ylims!` commands

```@repl 2Ds
xlims!(8,9.5);
ylims!(112,118);
savefig("plot-2Ds-zoom.svg"); nothing # hide
```

![](plot-2Ds-zoom.svg)

```

-----------

Path: ./docs/docstring-template.md

```
"""
    bar(x[, y])

Compute the Bar index between `x` and `y`.

```math
\LaTeX
```

If `y` is unspecified, compute the Bar index between all pairs of columns of `x`.

# Arguments
- `n::Integer`: the number of elements to compute.
- `dim::Integer=1`: the dimensions along which to perform the computation.

# Examples
```jldoctest
julia> a = [1 2; 3 4]
2×2 Array{Int64,2}:
 1  2
 3  4
```

See also [`bar!`](@ref), [`baz`](@ref), [`baaz`](@ref).
"""```

-----------

Path: ./docs/src/ref-plots.md

```
# Plotting with JuliaPlots

```

-----------

Path: ./docs/src/ref-windows.md

```
# Window functions

```

-----------

Path: ./docs/src/tutorial-data.md

```
# Working with NMR data

NMR measurements are arrays of data, with additional numerical data associated with each dimension, or axis. Within NMRTools, these data are stored as [`NMRData`](@ref) structures, which provides a convenient way to encapsulate both the data, axis information, and additional metadata providing information on acquisition or processing.


## Loading NMR data

NMR data are loaded using the [`loadnmr`](@ref) function. This can handle processed Bruker experiments, or NMRPipe-format data.

```julia
# load bruker experiment number 1 from a directory '2D_HN'
# by default, NMRTools will load bruker processed data from proc 1
spec2d = loadnmr("exampledata/2D_HN/1")

# load a different processed spectrum
spec1d = loadnmr("exampledata/2D_HN/1/pdata/101")

# load data from NMRPipe format, using a template
spec3d = loadnmr("exampledata/pseudo3D_HN_R2/1/ft/test%03d.ft2")
```

!!! tip
    `loadnmr` will attempt to locate and parse acquisition metadata, such as acqus files. If the spectrum file is located elsewhere (for example, if you are loading a file that was processed with NMRPipe), then you can specify the path to the experiment folder using the `experimentfolder` keyword argument.

When spectra are loaded, a simple algorithm runs to estimate the noise level, which is often used for subsequent plotting commands.

## Manipulating spectrum data

[`NMRData`](@ref) structures encapsulate a standard Julia array. This can be accessed using the [`data`](@ref) command. However, through the magic of multiple dispatch, most operations will work transparently on NMRData variables as if they are regular arrays, with the added benefit that axis information and metadata are preserved. Data can be sliced and accessed like a regular array using the usual square brackets:
```julia
spec1d[100:105]
spec2d[3:4, 10:14]
```

However, more conveniently, value-based selectors can also be used to locate data using chemical shifts. Three selectors are defined:
- `At(x)`: select data precisely at the specified value
- `Near(x)`: select data at the nearest matching position
- `x .. y`: select the range of data between `x` and `y` (closed interval)

For example:
```julia
spec1d[8.2 .. 8.3] # select between 8.2 and 8.3 ppm
spec2d[Near(8.25), 123 .. 124] # select near 8.25 ppm in the first dimension
                               # and between 123 and 124 ppm in the second dimension
```

When data are sliced, new NMRData structures are created and their axes are updated to match the new data size.

!!! warning
    When `NMRData` structures are sliced, copied, or otherwise modified, they inherit the same dictionary of metadata as the original variable. This means that any changes to metadata will affect both variables. To resolve this, make a `deepcopy` of the variable. Note also that any acquisition metadata might not reflect the correct shape of the data any more.


## Accessing axis data

Information on data dimensions is stored in `NMRDimension` structures. These can be accessed with the `dims` function:
```@example 1
# get the first dimension of this two-dimensional experiment
using NMRTools # hide
spec2d = exampledata("2D_HN"); # hide
dims(spec2d, 1)
```

`NMRDimension`s can be treated like vectors (one-dimensional arrays) for most purposes, including indexing and slicing. Value-based selectors can also be used, as for spectrum data. Like spectrum data, the underlying numerical data can be accessed if needed using the [`data`](@ref) function.

A heirarchy of types are defined for NMR dimensions, reflecting the variety of different experiments:
- `NMRDimension`
    - `FrequencyDimension`: with specific types `F1Dim` to `F4Dim`
    - `NonFrequencyDimension`
        - `TimeDimension`:
            - `TrelaxDim`: for relaxation times
            - `TkinDim`: for kinetic evolution times
            - `T1Dim` to `T4Dim`: for general frequency evolution periods
        - `GradientDimension`: for e.g. diffusion measurements, with specific types `G1Dim` to `G4Dim`
        - `UnknownDimension`: with specific types `X1Dim` to `X4Dim`

## Accessing metadata

[`NMRData`](@ref) objects contain comprehensive metadata on processing and acquisition parameters that are populated automatically upon loading a spectrum. Entries are divided into *spectrum* metadata - associated with the experiment in general - and *axis* metadata, that are associated with a particular dimension of the data.

Metadata entries are labelled by symbols such as `:ns` or `:pulseprogram`. Entries can be accessed using the `metadata` function, or directly as a dictionary-style lookup:
```@repl 1
spec2d = exampledata("2D_HN"); # hide
metadata(spec2d, :ns)
spec2d[:title]
```

Acquisition parameters from Bruker acqus files are also parsed when loading data, and can be accessed using the [`acqus`](@ref) function. Parameters are specified either as lower-case symbols or strings (not case-sensitive). An index can be specified for arrayed parameters such as pulse lengths or delays.
```@repl 1
acqus(spec2d, "TE")
acqus(spec2d, :p, 1)
```

Axis metadata can be accessed by providing an additional label, which can either be numerical or the appropriate `NMRDimension` type, such as `F1Dim` etc:
```@repl 1
metadata(spec2d, F2Dim, :label)
spec2d[2, :bf]
spec2d[F2Dim, :window]
```



```

-----------

Path: ./docs/src/ref-data.md

```
# Data

```

-----------

Path: ./docs/src/api.md

```
# API

## NMRBase

```@autodocs
Modules = [NMRTools.NMRBase]
```

## NMRIO

```@autodocs
Modules = [NMRTools.NMRIO]
``````

-----------

Path: ./docs/src/tutorial-plotrecipes.md

```
# Plotting

NMRTools contains recipes for plotting common types of spectra, using the `Plots` package.


## Plotting a 1D spectrum

Let's load and plot an example 1D 19F spectrum, using the `loadnmr` and `plot` commands:

```@example 1
using NMRTools, Plots
spec = exampledata("1D_19F")
plot(spec)
savefig("plot-1D.svg"); nothing # hide
```

![](plot-1D.svg)

By default, plots are titled using the label generated when the data are loaded, which in turn
comes from the first line of the title file. Titles can be removed by specifying `title=""` in
the plot command (and the title can be changed in the same manner).

The plot colour can also be modified, by specifying e.g. `c=:black` in the plot command.

```@example 1
plot(spec, title="", c=:black)
savefig("plot-1D-black.svg"); nothing # hide
```

![](plot-1D-black.svg)


### Zooming in / setting plot limits

The plot range can be set using the usual `xlims` argument or command, e.g. passing `xlims=[-124,-122]`
as an option to the plot command.

Alternatively, the region of the spectrum can be selected *before* plotting, by using the NMRTools `..`
selector.

```@example 1
plot(spec[-124 .. -123])
savefig("plot-1D-zoom.svg"); nothing # hide
```

![](plot-1D-zoom.svg)

There are two advantages of this approach. If `xlims` are set, the y axis will be scaled to fit the entire
spectrum, including regions that are not actually displayed - this may not show your data at its best.
If the data are selected before plotting, the y axis will be scaled according only to the selected region. Secondly, for large spectra, it may be quicker to plot only a subset of the data, and this can result in smaller figure sizes also.


## Overlaying multiple 1D spectra

Multiple experiments can conveniently be loaded from a list of filenames using the `map` function.

```julia
# create a list of bruker experiment directories
filenames = ["../../exampledata/1D_19F_titration/1",
             "../../exampledata/1D_19F_titration/2",
             "../../exampledata/1D_19F_titration/3",
             "../../exampledata/1D_19F_titration/4",
             "../../exampledata/1D_19F_titration/5",
             "../../exampledata/1D_19F_titration/6",
             "../../exampledata/1D_19F_titration/7",
             "../../exampledata/1D_19F_titration/8",
             "../../exampledata/1D_19F_titration/9",
             "../../exampledata/1D_19F_titration/10",
             "../../exampledata/1D_19F_titration/11"]
spectra = map(loadnmr, filenames)
nothing # hide
```

This creates a list (`Vector`) of `NMRData` containing the individual spectra. To plot this series of spectra, we can simply pass the list of spectra to the plot function:

```@example 1
spectra = exampledata("1D_19F_titration"); # hide
plot(spectra, xlims=(-125, -122))
savefig("plot-19F-titration.svg"); nothing # hide
```

![](plot-19F-titration.svg)

!!! note
    By default, spectra are normalized according to the number of scans and receiver gain determined automatically from the spectrum metadata; this can be disabled with the `normalize=false` option

!!! tip
    Legends are produced from the first line of the spectrum title file. The legend can be disabled using the `legend=nothing` option. To re-label a spectrum, use `label!(spectrum, "new label")` (or for a list of experiments, the i-th spectrum can be relabelled with `label!(spectra[i], "new label")`).

**Stacked views** can also be produced using the `vstack=true` option. By default, spectra are normalized according to the number of scans and receiver gain determined automatically from the spectrum metadata

```@example 1
plot(spectra, xlims=(-125, -122), vstack=true, legend=:topright)
savefig("plot-19F-stack.svg"); nothing # hide
```

![](plot-19F-stack.svg)


## Plotting 2D spectra

2D spectra can be loaded and plotted in the same way as for 1D experiments:

```@example 1
# load a bruker experiment
# spec2d = loadnmr("exampledata/2D_HN/1")
spec2d = exampledata("2D_HN")
plot(spec2d)
savefig("plot-2D.svg"); nothing # hide
```

![](plot-2D.svg)

As for 1Ds, plots are titled using the label generated when the data are loaded. Positive and negative contour levels are generated starting from *five times the noise level*.

The most convenient way to adjust the contour levels is simply to multiply or divide the spectrum by a scaling factor - the noise level stored within the spectrum metadata is not updated and so the contour levels will change accordingly.

The plot colour can also be modified, by specifying e.g. `c=:purple` in the plot command. The hue of the requested colour will be used to generate two shades, for positive and negative contours.

```@example 1
plot(spec2d/3, c=:purple, xlims=(6,10))
savefig("plot-2D-purple.svg"); nothing # hide
```

![](plot-2D-purple.svg)


Spectra can also be plotted in other formats, e.g. heatmaps:

```@example 1
heatmap(spec2d[8 .. 8.5, 120 .. 125], cbar=:right, cbtitle="SNR")
savefig("plot-2D-heatmap.svg"); nothing # hide
```

![](plot-2D-heatmap.svg)


## Overlaying multiple 2D spectra

Multiple 2D experiments can conveniently be loaded from a list of filenames using the `map` function.

```julia
# create a list of nmrPipe-processed experiments
filenames = ["../../exampledata/2D_HN_titration/1/test.ft2",
             "../../exampledata/2D_HN_titration/2/test.ft2",
             "../../exampledata/2D_HN_titration/3/test.ft2",
             "../../exampledata/2D_HN_titration/4/test.ft2",
             "../../exampledata/2D_HN_titration/5/test.ft2",
             "../../exampledata/2D_HN_titration/6/test.ft2",
             "../../exampledata/2D_HN_titration/7/test.ft2",
             "../../exampledata/2D_HN_titration/8/test.ft2",
             "../../exampledata/2D_HN_titration/9/test.ft2",
             "../../exampledata/2D_HN_titration/10/test.ft2",
             "../../exampledata/2D_HN_titration/11/test.ft2"]
spectra2d = map(loadnmr, filenames)
```

As for 1D experiments, these can be plotted, with automatic normalisation for varying numbers of scans and receiver gain, simply by passing the list of spectra to the plot function:

```@example 1
spectra2d = exampledata("2D_HN_titration"); # hide
plot(spectra2d, legend=:topleft)
savefig("plot-2D-titration.svg"); nothing # hide
```

![](plot-2D-titration.svg)

A gradient of colours will automatically be generated when spectra are plotted in this way, and a legend generated from spectrum labels.

!!! note
    It is recommended to plot a series of 2Ds by passing a list of spectra in a single `plot` call, rather than adding them to a plot one-by-one using the `plot!` command. This will ensure consistent normalisation between experiments. Otherwise, contour levels will be calculated independently as five times the noise level in each experiment.

As usual, plot limits can be adjusted with the `xlims` and `ylims` options:

```@example 1
plot(spectra2d[[1,6]], xlims=(8,8.5),ylims=(120,125))
savefig("plot-2D-lims.svg"); nothing # hide
```

![](plot-2D-lims.svg)


## Plotting pseudo-2D data

Plot recipes are available for pseudo-2D data like diffusion, relaxation or kinetics.

```@example 1
# load a diffusion measurement, processed in topspin using xf2
diffusiondata = exampledata("pseudo2D_XSTE")

# set the gradient strengths - which varied from 2% to 98% of the max, over 10 points
diffusiondata = setgradientlist(diffusiondata, LinRange(0.02, 0.98, 10))

# generate a 3D plot of the data
plot(diffusiondata, xlims=(6,10))
savefig("plot-diff-3D.svg"); nothing # hide
```

![](plot-diff-3D.svg)

By default, the `plot` command will generate a 3D plot for pseudo-2D experiments. Heatmaps can also be generated using the `heatmap` command. In this example, we have selected the range to plot directly, rather than using the `xlims` option.

```@example 1
heatmap(diffusiondata[7..9,:])
savefig("plot-diff-heatmap.svg"); nothing # hide
```

![](plot-diff-heatmap.svg)


## Saving plots

All plots can be saved as high quality vector graphics, or as png files, using the `savefig` command.

```julia
savefig("myspectrum.pdf")
savefig("myspectrum.svd")
savefig("myspectrum.png")
``````

-----------

Path: ./docs/src/indexes.md

```
# Index

## NMRBase

```@index
Modules = [NMRTools.NMRBase]
```

## NMRIO

```@index
Modules = [NMRTools.NMRIO]
``````

-----------

Path: ./docs/src/quickstart.md

```
# Getting started

## Installing NMRTools

The Distributions package is available through the Julia package system by running `Pkg.add("NMRTools")`. Throughout, we assume that you have installed the package.

The examples in this tutorial also using the `Plots` package, which can be obtained similarly.


## Plot a 1D spectrum

Let's load some example data. This can be a Bruker experiment directory, a specific pdata folder, or an NMRPipe-format file.

```@example 1
using NMRTools, Plots
spec = exampledata("1D_19F")
```

NMRTools contains Plots recipes for common types of spectrum. To plot our 1D spectrum, we just use
the `plot` command:

```@example 1
plot(spec)
savefig("plot-y.svg"); nothing # hide
```

![](plot-y.svg)

We could zoom in on a particular region using the usual `xlims` arguments from `Plots`, but we can also select a chemical shift range from the data directly. To do this, we use square brackets `[...]` to access
the data like an array, but use the `..` selector to specify our chemical shift range:

```@example 1
plot(spec[-124.5 .. -123])
savefig("plot-y2.svg"); nothing # hide
```

![](plot-y2.svg)

All plots can be saved as high quality vector graphics or png files, using the `savefig` command:

```julis
savefig("myspectrum.pdf")
```


## Plot a 2D spectrum

Two-dimensional spectra can be plotted in exactly the same way as for 1Ds.

```@example 2d
using NMRTools, Plots # hide
spec = exampledata("2D_HN")
plot(spec)
savefig("plot-2d.svg"); nothing # hide
```

![](plot-2d.svg)

Contour levels are set to five times the noise level. The most convenient way to adjust this is simply to multiply or divide the spectrum by some scaling factor. You can also adjust the title - by default taken from the spectrum label - using the `title` keyword. Use an empty string (`title=""`) to remove the title.

```@example 2d
plot(spec / 2, title="spectrum divided by two")
savefig("plot-2d-scaled.svg"); nothing # hide
```

![](plot-2d-scaled.svg)


## Accessing your data

Spectrum data and associated axis information, metadata, etc, is encapsulated in an [`NMRData`](@ref) structure.
```@repl data
using NMRTools # hide
spec = exampledata("1D_19F")
```

Data can be accessed with conventional array indexing, but also using the value-based selectors, `Near` and `..`:
```@repl data
spec[100:105]
spec[Near(-124)]
spec[-124 .. -123.5]
```

This also works for multidimensional data. For example:
```@repl data
spec2d = exampledata("2D_HN")
spec2d[8.1 .. 8.3, Near(124)]
```

A plain array of data for the spectrum can be obtained from this using the [`data`](@ref) command:
```@repl data
data(spec)
```

Similarly, a plain vector containing axis values can be obtained from this using the [`data`](@ref) command, passing an additional argument to specify the dimension. This can either be a number or the axis type, e.g. `F1Dim`:
```@repl data
data(spec, 1)
```
```

-----------

Path: ./docs/src/tutorial-metadata.md

```
# Metadata

[`NMRData`](@ref) objects contain comprehensive metadata on processing and acquisition parameters. These are populated automatically when loading a spectrum. Entries are divided into **spectrum metadata** – associated with the experiment in general – and **axis metadata**, that are associated with a particular dimension of the data.

Examples of spectrum metadata include: number of scans, receiver gain, pulse program, experiment title, number of dimensions, noise level (calculated when the spectrum is loaded), acquisition parameters (pulse lengths etc, from the `acqus` file), contents of auxilliary files (e.g. vclists and vdlists).

Examples of axis metadata include: the number of points, the original time domain size (before zero filling, linear prediction or extraction of a subregion), carrier frequency, spectrum width, window function used for processing.


## Accessing spectrum metadata

Metadata are stored in a dictionary labelled by symbols such as `:ns` or `:pulseprogram`. This dictionary can be accessed using the [`metadata`](@ref) function.

```@example 1
using NMRTools
# load an example 2D 1H,15N HMQC spectrum
spec = exampledata("2D_HN")

metadata(spec)
```

For convenience, entries can be accessed by passing a second argument to the `metadata` function:

```@example 1
metadata(spec, :title)
```

or directly from the spectrum using a dictionary-style lookup:

```@example 1
spec[:ns]
```

## Accessing axis metadata

Axis metadata can be accessed by providing an additional argument to the [`metadata`](@ref) function, specifying the axis numerically:

```@example 1
metadata(spec, 1)
```

Axes can also be accessed by their type, e.g. `F1Dim` or `F2Dim`:

```@example 1
metadata(spec, F2Dim)
```

Again, for convenience entries can be accessed by passing an additional argument to the `metadata` function:

```@example 1
metadata(spec, F1Dim, :label)
```

or directly from the spectrum object using a dictionary-style lookup alongside an axis reference:

```@example 1
spec[2, :offsetppm]
```


## Accessing acquisition parameters

Spectrometer acquisition parameters are automatically parsed from the `acqus` file when data are loaded. This is stored as a dictionary in the `:acqus` entry of the spectrum metadata, but can more conveniently be accessed through the function `acqus(spec, parametername)`. Parameter names can be provided either as strings (case insensitive, e.g. `"TE"` for the temperature) or as lowercase symbols (e.g. `:te`).

```@example 1
acqus(spec, :te)
```

Arrayed parameters such as pulse lengths are returned as dictionaries:

```@example 1
acqus(spec, :p)
```

For convenience, particular entries can be accessed directly by supplying an additional index parameter:

```@example 1
acqus(spec, :cnst, 4)
```

!!! note
    Arrayed parameters such as pulse lengths, delays, etc. are returned as dictionaries rather than lists to avoid indexing confusion between Bruker arrays, which are zero-based, and Julia arrays, which are unit-based.


## Auxiliary files

If present, files such as `vclist` and `vdlist` are imported and can be accessed through the `acqus` function:

```@example 1
relaxation_experiment = exampledata("pseudo3D_HN_R2")
acqus(relaxation_experiment, :vclist)
```


## Window functions

The window functions used for data processing are identified when experiments are loaded. These are represented by subtypes of [`WindowFunction`](@ref), which contain appropriate parameters specifying the particular function applied together with the acquisition time $t_\mathrm{max}$ (calculated at the point of application, i.e. after linear prediction but before zero filling).

Window functions are stored as axis metadata and can be accessed through the `:window` parameter:
```@example 1
spec[2, :window] # get the window function for the second dimension
```

Available window functions are:
- `NullWindow(tmax)`: no window function applied
- `UnknownWindow(tmax)`: unrecognised window function
- `ExponentialWindow(lb, tmax)`: line broadening specified in Hz
- `SineWindow(offset, endpoint, power, tmax)`: a supertype encompassing some special cases
    - `CosWindow(tmax)`: apodization by a pure half-cosine window
    - `Cos²Window(tmax)`: apodization by a pure half-cosine-squared window
    - `GeneralSineWindow(offset, endpoint, power, tmax)`: other general cases
- `GaussWindow(expHz, gaussHz, center, tmax)`: a supertype encompassing some special cases
    - `LorentzToGaussWindow(expHz, gaussHz, tmax)`
    - `GeneralGaussWindow(expHz, gaussHz, center, tmax)`: other general cases
```

-----------

Path: ./docs/src/tutorial-phosphorylation.md

```
# 2D phosphorylation kinetics

```

-----------

Path: ./docs/src/tutorial-animation.md

```
# Animating spectra

The plot recipes defined within NMRTools provide an easy way to generate animations of spectral data, using the `@animate` macro defined within the Plots package. A couple of examples are provided below.

## Phosphorylation kinetics

First, load in some data. This pseudo-3D kinetic data - a series of 1H,15N SOFAST-HMQC spectra - showing the progressive phosphorylation of cJun by JNK1 kinase. Read more about the paper here: [Waudby et al. Nat Commun (2022)](https://www.nature.com/articles/s41467-022-33866-w).

```@example 1
using NMRTools, Plots

spec=exampledata("pseudo3D_kinetics")
nothing # hide
```

The data have been processed in Topspin using `ftnd 3` and `ftnd 2`, so that the final dimension of the 3D represents the phosphorylation time. Each 2D plane took 2 minutes to acquire, and there was an initial delay of 4 min between adding the kinase and recording the first free induction decay. We need to calculate a list of times from this information, that we can use to label the animation:

```@example 1
# get number of time points
nt = size(spec,3)

# calculate a list of measurement times
# experiment was recorded with 2 min per spectrum, plus initial dead-time of 4 min
tmin = LinRange(0, 2*(nt-1), nt) .+ 4
thr = tmin / 60
```

Now we can generate the animation, by looping over each point in the time series with the Plots `@animate` macro, then saving as an animated gif.

```@example 1
anim = @animate for i=1:nt
    # generate a nice title with the time rounded to 1 decimal place, e.g. "Time elapsed: 0.1 hr"
    titletext = "Time elapsed: $(round(thr[i],digits=1)) hr"
    plot(spec[:,:,i], title=titletext)
end

# save as an animated gif
gif(anim, "kinetics.gif", fps=30)
nothing # hide
```

![](kinetics.gif)


## 2D titration

First, load in some data - as described in the [tutorial on plotting](@ref "Overlaying multiple 2D spectra").

```@example 1
spectra2d = exampledata("2D_HN_titration")
nothing # hide
```

Now loop over the spectra to produce the animation:

```@example 1
anim=@animate for spec in spectra2d
    plot(spec, xlims=(6,10.5), title=label(spec))
end

gif(anim, "titration.gif", fps=8)
nothing # hide
```

![](titration.gif)

Note that spectra have been normalised automatically to account for differences in their number of scans or receiver gain.```

-----------

Path: ./docs/src/ref-metadata.md

```
# Metadata

[`NMRData`](@ref) objects can store various metadata associated with the spectrum and each of the dimensions.

Metadata are stored as dictionaries using symbols as keys (e.g. `:ns`). They can be accessed using the `metadata` function, or directly from an `NMRData` object using a dictionary-style lookup. Metadata associated with axes are accessed by providing an additional reference, either as a dimension number or type (e.g. `F1Dim`, `F2Dim` etc.).

```julia
metadata(nmrdata, key) # spectrum metadata
nmrdata[key]

metadata(nmrdata, dimension, key) # axis metadata
nmrdata[dimension, key]
```

```@docs; canonical=false
metadata
```

## Labels

```@docs; canonical=false
label
label!
units
```

## Acquisition data

When spectra are loaded, the contents of the `acqus` file  are parsed (as are the `acqu2s` files etc. too, if present). These can be accessed with `:acqus` and `:acqu2s` keys, etc. For convenience though, the additional function [`acqus`](@ref) is provided to access acquisiton data directly.

```@docs; canonical=false
acqus
```

## Auxilliary files

`acqus` can also be used to access the contents of auxilliary files (and if not present, `nothing` will be returned). Note that NMRTools will perform automatic unit conversion as follows:
- `:vclist`: variable loopcounter
- `:vdlist`: variable delays, in seconds
- `:valist`: variable amplitude, in dB (converted from Watts if necessary)
- `:vplist`: variable pulse lengths, in seconds
- `:fq1list` up to `:fq8list`: frequency lists – see [Frequency lists](@ref) for more information.

## Frequency lists

Frequency lists can be specified on the spectrometer in a number of ways - in Hz, in ppm, and relative to the spectrometer frequency or the base frequency (0 ppm). Frequency lists are therefore stored in NMRTools as `FQList` structures which encode this additional information.

```@docs; canonical=false
FQList
```

Raw numerical data can be accessed using the `data()` function, but it is recommended to use `getppm` and `getoffset` functions to access frequency data safely.

```@docs; canonical=false
FQList
getppm
getoffset
```


## Standard metadata: spectra

| Key                  | Description                                         |
|:-------------------- |:--------------------------------------------------- |
| `:acqusfilename`     | path to acqus file                                  |
| `:acqus`             | contents of acqus file, as a dictionary             |
| `:acqu2s`, `:acqu3s` | contents of acqu2s/acqu3s files (if present)        |
| `:experimentfolder`  | path to experiment                                  |
| `:filename`          | spectrum filename                                   |
| `:format`            | input file format (`:nmrpipe` or `:pdata`)          |
| `:label`             | short label (first line of title pdata file)        |
| `:ndim`              | number of dimensions                                |
| `:noise`             | RMS noise level (see [`estimatenoise!`](@ref))      |
| `:ns`                | number of scans                                     |
| `:pulseprogram`      | pulse program title                                 |
| `:rg`                | receiver gain                                       |
| `:title`             | spectrum title (contents of title pdata file)       |
| `:topspin`           | Topspin version used for acquisition                |



## Standard metadata: frequency dimensions

| Key                  | Description                                                                |
|:-------------------- |:-------------------------------------------------------------------------- |
| `:aq`                | acquisition time, in seconds                                               |
| `:bf`                | base frequency, in MHz                                                     |
| `:label`             | short label                                                                |
| `:npoints`           | final number of **real** data points in dimension (after extraction)       |
| `:offsethz`          | carrier offset from bf, in Hz                                              |
| `:offsetppm`         | carrier offset from bf, in ppm                                             |
| `:pseudodim`         | flag indicating non-frequency domain data (`false` for frequency domain)   |
| `:region`            | extracted region, expressed as a range in points, otherwise `missing`      |
| `:sf`                | carrier frequency, in MHz                                                  |
| `:swhz`              | spectrum width, in Hz                                                      |
| `:swppm`             | spectrum width, in ppm                                                     |
| `:td`                | number of **complex** points acquired, including LP                        |
| `:tdzf`              | number of **complex** points when FT executed, including LP and ZF         |
| `:window`            | [`WindowFunction`](@ref) encoding applied apodization                      |
```

-----------

Path: ./docs/src/ref-exceptions.md

```
# Exceptions

```

-----------

Path: ./docs/src/metadata.md

```
# Metadata

[`NMRData`](@ref) objects contain comprehensive metadata on processing and acquisition parameters that are populated automatically upon loading a spectrum. Entries are divided into *spectrum* metadata - associated with the experiment in general - and *axis* metadata, that are associated with a particular dimension of the data.


## Accessing spectrum metadata

Metadata entries are labelled by symbols such as `:ns` or `:pulseprogram`. See below for a list of all available symbols. Entries can be accessed using the `metadata` function, or directly as a dictionary-style lookup

```@repl 1
using NMRTools; # hide
spec = exampledata("2D_HN"); # hide
metadata(spec, :ns)
spec[:ns]
metadata(spec, :title)
spec[:title]
```

Help on metadata symbols is available

```@repl 1
metadatahelp(:td)
```


## Accessing axis metadata

Axis metadata can be accessed by providing an addition axis label, i.e. `F1Dim`, `F2Dim`.

```@repl 1
metadata(spec, F1Dim, :label)
spec[F1Dim, :label]
spec[1, :label]
metadata(spec, F2Dim, :label)
spec[F2Dim, :label]
spec[2, :label]
```


## Accessing acquisition parameters

Spectrometer acquisition parameters are automatically parsed from the `acqus` file when data are loaded. This is stored as a dictionary in the `:acqus` entry of the spectrum metadata, but can more conveniently be accessed through the convenience function `acqus(spec, :parametername)`. Note that parameter names are not case sensitive.

```@repl 1
acqus(spec, :bf1)
acqus(spec, :te)
```

Arrayed parameters such as pulse lengths can be accessed as lists or by supplying an additional index parameter

```@repl 1
acqus(spec, :p)
acqus(spec, :p, 1)
acqus(spec, :cnst, 4)
```

!!! note
    Lists of parameters are returned as zero-based arrays (in contrast to typical Julia arrays, which are unit-based) to match Bruker naming conventions


## Auxiliary files

If present, files such as `vclist` and `vdlist` are imported and can be accessed through the `acqus` function

```@repl 1
pseudo3dspec = exampledata("pseudo3D_HN_R2"); # hide
acqus(pseudo3dspec, :vclist)
```


## Available spectrum metadata symbols

| symbol           | description                                |
|:-----------------|:-------------------------------------------|
| `:filename`      | original filename or template              |
| `:format`        | `:NMRPipe` or `:bruker`                    |
| `:title`         | contents of `pdata/1/title`                |
| `:label`         | first line of title, used for captions     |
| `:pulseprogram`  | pulse program (PULPROG) from acqus file    |
| `:ndim`          | number of dimensions                       |
| `:acqusfilename` | path to associated acqus file              |
| `:acqus`         | dictionary of acqus data                   |
| `:ns`            | number of scans                            |
| `:rg`            | receiver gain                              |
| `:noise`         | rms noise level                            |


## Available axis metadata symbols

| symbol         | description                                                           |
|:---------------|:----------------------------------------------------------------------|
| `:pseudodim`   | flag indicating non-frequency domain data                             |
| `:npoints`     | final number of (real) data points in dimension (after extraction)    |
| `:td`          | number of complex points acquired                                     |
| `:tdzf`        | number of complex points when FT executed, including LP and ZF        |
| `:bf`          | base frequency, in MHz                                                |
| `:sf`          | carrier frequency, in MHz                                             |
| `:offsethz`    | carrier offset from bf, in Hz                                         |
| `:offsetppm`   | carrier offset from bf, in ppm                                        |
| `:swhz`        | spectrum width, in Hz                                                 |
| `:swppm`       | spectrum width, in ppm                                                |
| `:region`      | extracted region, expressed as a range in points, otherwise `missing` |
| `:window`      | `WindowFunction` object indicating applied apodization                |


## Window functions

Window functions are represented by subtypes of the abstract type `WindowFunction`, each of which contain appropriate parameters to specify the particular function applied. In addition, the acquisition time ``t_{max}`` is also stored (calculated at the point of application, i.e. after linear prediction but before zero filling).

Available window functions:
* `NullWindow(tmax)`: no window function applied
* `UnknownWindow(tmax)`: unrecognised window function
* `ExponentialWindow(lb, tmax)`: line broadening specified in Hz
* `SineWindow(offset, endpoint, power, tmax)`: a supertype encompassing some special cases
  - `CosWindow(tmax)`: apodization by a pure half-cosine window
  - `Cos²Window(tmax)`: apodization by a pure half-cosine-squared window
  - `GeneralSineWindow(offset, endpoint, power, tmax)`: other general cases
* `GaussWindow(expHz, gaussHz, center, tmax)`: a supertype encompassing some special cases
  - `LorentzToGaussWindow(expHz, gaussHz, tmax)`
  - `GeneralGaussWindow(expHz, gaussHz, center, tmax)`: other general cases
```

-----------

Path: ./docs/src/tutorial-nonfreqdims.md

```
# Non-frequency dimensions

```

-----------

Path: ./docs/src/index.md

```
# NMRTools.jl

NMRTools.jl is a simple library for importing and plotting NMR data. Documentation may be incomplete. Interested users are recommended to check out the 'Getting started' guide and the tutorial pages.

!!! note
    This package is under active development and it may be a while before its features and syntax stabilises.

```

-----------

Path: ./docs/src/ref-coherences.md

```
# Coherences and isotope data

NMRTools defines commonly used [nuclei](@ref Nuclei) and provides a framework for identifying single- and multiple-quantum [coherences](@ref Coherences) associated with them. [Reference data](@ref "Reference data") on their gyromagnetic ratios, and spin quantum numbers, is also defined and accessible through simple functions.

## Nuclei

```@docs; canonical=false
Nucleus
```

## Coherences

```@docs; canonical=false
Coherence
SQ
MQ
coherenceorder
```

## Reference data

```@docs; canonical=false
spin
gyromagneticratio
``````

-----------

Path: ./docs/src/tutorial-diffusion.md

```
# 1D diffusion analysis

Let's analyse a 15N-edited XSTE measurement of translational diffusion. This experiment was acquired as a single pseudo-2D measurement, with gradient strengths ranging from 2 to 98% of the maximum strength, 0.55 T/m.

First, we need to load the required packages. We will use `LsqFit` for the non-linear least squares fitting, `Measurements` to handle uncertainties, and `Statistics` for calculation of means and standard deviations.
```@example diff
using NMRTools
using Plots
using LsqFit
using Measurements
using Statistics

spec = exampledata("pseudo2D_XSTE")
```

## Set up parameters

The file we have just loaded has an `UnknownDimension` as the non-frequency dimension. We need to replace this with a `GradientDimension` and set the gradient strengths that were used. We do this with the `setgradientlist` function:
```@example diff
gradients = LinRange(0.02, 0.98, size(spec, X2Dim))
Gmax = 0.55 # T/m

spec = setgradientlist(spec, gradients, Gmax)
```

Next, we extract or set other acquisition parameters required for analysis. In particular, we extract the diffusion pulse length, δ, and the diffusion delay, Δ, from the acqus file. We also specify the chemical shift ranges used for plotting, fitting, and for determination of the noise level.
```@example diff
δ = acqus(spec, :p, 30) * 2e-6 # gradient pulse length = p30/2
Δ = acqus(spec, :d, 20)        # diffusion delay = d20
σ = 0.9                        # gradient pulse shape factor (for SMSQ10)

coherence = SQ(H1)             # coherence for diffusion encoding
γ = gyromagneticratio(coherence)            # calculate effective gyromagnetic ratio

g = data(spec, G2Dim)          # list of gradient strengths

# select chemical shift ranges for plotting and fitting
plotrange = 6 .. 10 # ppm
datarange = 7.7 .. 8.6 # ppm
noiseposition = 10.5 # ppm
nothing # hide
```

## Plot the data

To take a quick look at the data, we can plot the experiment either as 3D lines using the `plot` command, or as a heatmap:
```@example diff
plot(
    plot(spec[plotrange,:]),
    heatmap(spec[plotrange,:])
)
savefig("tutorial-diffusion-plot.svg"); nothing # hide
```

![](tutorial-diffusion-plot.svg)


## Calculate noise and peak integrals

Now, we can determine the measurement noise, by taking the standard deviation of integrals across the different gradient points:
```@example diff
# create a selector for the noise, matching the width of the data range
noisewidth = datarange.right - datarange.left
noiserange = (noiseposition-0.5noisewidth)..(noiseposition+0.5noisewidth)

# integrate over the noise regions and take the standard deviation
# (calculate the sum over the frequency dimension F1Dim, and use
# `data` to convert from NMRData to a regular array)
noise = sum(spec[noiserange,:], dims=F1Dim) |> data |> std

# calculate the integral of the data region similarly, using vec to convert to a list
integrals = sum(spec[datarange,:], dims=F1Dim) |> data |> vec

# normalise noise and integrals by the maximum value
noise /= maximum(integrals)
integrals /= maximum(integrals)
nothing # hide
```

## Fitting

Now, we can fit the data to the Stejskal-Tanner equation using the `LsqFit` package.
```@example diff
# model parameters are (I0, D) - scale D by 1e-10 for a nicer numerical value
model(g, p) = p[1] * exp.(-(γ*δ*σ*g).^2 .* (Δ - δ/3) .* p[2] .* 1e-10)

p0 = [1.0, 1.0] # rough guess of initial parameters

fit = curve_fit(model, g, integrals, p0) # run the fit

# extract the fit parameters and standard errors
pfit = coef(fit)
err = stderror(fit)
D = (pfit[2] ± err[2]) * 1e-10
```

## Plot the results

Finally, plot the results:
```@example diff
x = LinRange(0, maximum(g)*1.1, 100)
yfit = model(x, pfit)

p1 = scatter(g, integrals .± noise, label="observed",
        frame=:box,
        xlabel="G (T m⁻¹)",
        ylabel="Integrated signal",
        title="",
        ylims=(0,Inf), # make sure y axis starts at zero
        widen=true,
        grid=nothing)
plot!(p1, x, yfit, label="fit")

p2 = plot(spec[plotrange,1],linecolor=:black)
plot!(p2, spec[datarange,1], fill=(0,:orange), linecolor=:red)
hline!(p2, [0], c=:grey)
title!(p2, "")

plot(p1, p2, layout=(1,2))
savefig("tutorial-diffusion-fit.svg"); nothing # hide
```

![](tutorial-diffusion-fit.svg)


## Estimating the hydrodynamic radius

We can use the known viscosity of water as a function of temperature to estimate the hydrodynamic radius from the measured diffusion coefficient. First, we extract the temperature from the spectrum metadata:
```@example diff
T = acqus(spec, :te)
```

Next, we can create a little function to calculate viscosity for H2O or D2O solvents as a function of temperature:
```@example diff
function viscosity(solvent, T)
	if solvent==:h2o
        A = 802.25336
        a = 3.4741e-3
        b = -1.7413e-5
        c = 2.7719e-8
        gamma = 1.53026
        T0 = 225.334
    elseif solvent==:d2o
        A = 885.60402
        a = 2.799e-3
        b = -1.6342e-5
        c = 2.9067e-8
        gamma = 1.55255
        T0 = 231.832
    else
        @error "solvent not recognised (should be :h2o or :d2o)"
    end

    DT = T - T0
    k = 1.38e-23
	
    return A * (DT + a*DT^2 + b*DT^3 + c*DT^4)^(-gamma)
end
η = viscosity(:h2o, T)
```

Finally, we can use the Stokes-Einstein equation to calculate the hydrodynamic radius:
```@example diff
k = 1.38e-23
rH = k*T / (6π * η * 0.001 * D) * 1e9 # in nm
```

```

-----------

Path: ./docs/src/ref-io.md

```
# File I/O

```

-----------

Path: ./docs/src/tutorial-relaxation.md

```
# 1D relaxation analysis

Let's analyse a measurement of 1H T2 relaxation, acquired as a single pseudo-2D spectrum. First, we need to load the required packages. We will use `LsqFit` for the non-linear least squares fitting, `Measurements` to handle uncertainties, and `Statistics` for calculation of means and standard deviations.

Data have been processed in Topspin (using `xf2`), so can be loaded using the `loadnmr` function.

```@example 1
using NMRTools
using Plots
using LsqFit
using Measurements
using Statistics

spec = exampledata("pseudo2D_T2")
nothing # hide
```

## Set up parameters

The experiment uses a vclist to encode the relaxation time. The contents of this list are automatically parsed when the spectrum is loaded, and can be accessed with the [`acqus`](@ref) command:

```@example 1
acqus(spec, :vclist)
```

Each loop corresponds to a delay of 4 ms, so from this we can calculate a list of relaxation times. The spectrum we have just loaded has an `UnknownDimension` as the non-frequency dimension. We need to replace this with a `TrelaxDimension` that encodes the relaxation delays, and we can do this with the `setrelaxtimes` function:

```@example 1
τ = acqus(spec, :vclist) * 4e-3
spec = setrelaxtimes(spec, τ, "s")
nothing # hide
```

Next, we specify the chemical shift ranges used for plotting, fitting, and for determination of the noise level.
```@example 1
plotrange = 0.7 .. 1.0 # ppm
datarange = 0.8 .. 0.9 # ppm
noiseposition = -2 # ppm
nothing # hide
```

## Plot the data

To take a quick look at the data, we can plot the experiment either as 3D lines using the `plot` command, or as a heatmap:
```@example 1
plot(
    plot(spec[plotrange,:]),
    heatmap(spec[plotrange,:])
)
savefig("tutorial-relax-plot.svg"); nothing # hide
```

![](tutorial-relax-plot.svg)


## Calculate noise and peak integrals

Now, we can determine the measurement noise, by taking the standard deviation of integrals across the different gradient points:
```@example 1
# create a selector for the noise, matching the width of the data range
noisewidth = datarange.right - datarange.left
noiserange = (noiseposition-0.5noisewidth)..(noiseposition+0.5noisewidth)

# integrate over the noise regions and take the standard deviation
# (calculate the sum over the frequency dimension F1Dim, and use
# `data` to convert from NMRData to a regular array)
noise = sum(spec[noiserange,:], dims=F1Dim) |> data |> std

# calculate the integral of the data region similarly, using vec to convert to a list
integrals = sum(spec[datarange,:], dims=F1Dim) |> data |> vec

# normalise noise and integrals by the maximum value
noise /= maximum(integrals)
integrals /= maximum(integrals)
nothing # hide
```

## Fitting

Now, we can fit the data to an exponential decay using the `LsqFit` package:

```@example 1
# model parameters are (I0, R2)
function model(t, p)
    I0 = p[1]
    R2 = p[2]
    @. I0 * exp(-R2 * t)
end

p0 = [1.0, 1.0] # rough guess of initial parameters

fit = curve_fit(model, τ, integrals, p0) # run the fit

# extract the fit parameters and standard errors
pfit = coef(fit)
err = stderror(fit)
R2 = (pfit[2] ± err[2])
```

So we see that the fitted R₂ relaxation rate is 0.844 ± 0.016 s⁻¹

## Plot the results

Finally, plot the results:

```@example 1
# calculate the best-fit curve across 100 points so it looks nice and smooth
x = LinRange(0, maximum(τ)*1.1, 100)
yfit = model(x, pfit)

p1 = scatter(τ, integrals .± noise, label="observed",
        frame=:box,
        xlabel="Relaxation time (s)",
        ylabel="Integrated signal",
        title="",
        ylims=(0,Inf), # make sure y axis starts at zero
        widen=true,
        grid=nothing)
plot!(p1, x, yfit, label="fit (R₂ = $R2 s⁻¹)")

p2 = plot(spec[plotrange,1],linecolor=:black)
plot!(p2, spec[datarange,1], fill=(0,:orange), linecolor=:red)
hline!(p2, [0], c=:grey)
title!(p2, "")

plot(p1, p2, layout=(1,2))
savefig("tutorial-relax-fit.svg"); nothing # hide
```

![](tutorial-relax-fit.svg)
```

-----------

Path: ./docs/src/ref-dimensions.md

```
# Data

```

-----------

Path: ./TODO.md

```
# NMRTools.jl TODO list

- [ ] Import (multi)complex spectra
- [ ] Load raw time-domain data
- [ ] Export data


## failure importing complex 2D

```
dat = loadnmr("exampledata/2D_HN/1/pdata/1"; allcomponents=true)
┌ Warning: import of multicomplex data not yet implemented - returning real values only
└ @ NMRTools.NMRIO ~/.julia/dev/NMRTools/src/NMRIO/bruker.jl:174
ERROR: BoundsError: attempt to access 4-element Vector{Matrix{Float64}} at index [1:1216, 1:512]
Stacktrace:
 [1] throw_boundserror(A::Vector{Matrix{Float64}}, I::Tuple{UnitRange{Int64}, UnitRange{Int64}})
   @ Base ./abstractarray.jl:744
 [2] checkbounds
   @ ./abstractarray.jl:709 [inlined]
 [3] _getindex
   @ ./multidimensional.jl:860 [inlined]
 [4] getindex(::Vector{Matrix{Float64}}, ::UnitRange{Int64}, ::UnitRange{Int64})
   @ Base ./abstractarray.jl:1294
 [5] loadpdata(filename::String, allcomponents::Bool)
   @ NMRTools.NMRIO ~/.julia/dev/NMRTools/src/NMRIO/bruker.jl:184
 [6] loadnmr(filename::String; experimentfolder::Nothing, allcomponents::Bool)
   @ NMRTools.NMRIO ~/.julia/dev/NMRTools/src/NMRIO/loadnmr.jl:43
 [7] top-level scope
   @ REPL[15]:1
``````

-----------

Path: ./README.md

```
# NMRTools

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://waudbygroup.github.io/NMRTools.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://waudbygroup.github.io/NMRTools.jl/dev)
[![CI](https://github.com/waudbygroup/NMRTools.jl/actions/workflows/Runtests.yml/badge.svg)](https://github.com/waudbygroup/NMRTools.jl/actions/workflows/Runtests.yml)
[![Codecov](https://codecov.io/gh/waudbygroup/NMRTools.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/waudbygroup/NMRTools.jl)
[![DOI](https://zenodo.org/badge/251587402.svg)](https://zenodo.org/badge/latestdoi/251587402)

![NMRTools logo](logo.png)

NMRTools.jl is a simple library for importing and plotting NMR data.

Usage examples are provided in the documentation, and additional examples are provided as Pluto workbooks. To run these:
```julia
# add Pluto if needed through package manager
using Pkg
Pkg.add("Pluto")

# launch Pluto
using Pluto
Pluto.run()
```

> **NOTE**: This package is under active development and it may be a while before its features and syntax stabilises. Please take a look at the examples in the documentation for a guide to getting started.
```

-----------

Path: ./make-local-docs.jl

```julia
using Pkg
Pkg.instantiate()
Pkg.develop(path=pwd())
include("docs/make.jl")```

-----------

Path: ./src/NMRIO/loadnmr.jl

```julia
"""
    loadnmr(filename, experimentfolder=nothing)

Main function for loading NMR data. `experimentfolder` contains the path to an experiment directory,
for identification of metadata, if the filename is not directly within an experiment.

Returns an `NMRData` structure, or throws an `NMRToolsError` is there is a problem.

# Examples

nmrPipe import:

```julia
loadnmr("exampledata/1D_1H/1/test.ft1");
loadnmr("exampledata/1D_19F/1/test.ft1");
loadnmr("exampledata/2D_HN/1/test.ft2");
loadnmr("exampledata/pseudo2D_XSTE/1/test.ft1");
loadnmr("exampledata/pseudo3D_HN_R2/1/ft/test%03d.ft2");
```

Bruker pdata import:

```julia
loadnmr("exampledata/1D_19F/1");
loadnmr("exampledata/1D_19F/1/");
loadnmr("exampledata/1D_19F/1/pdata/1");
loadnmr("exampledata/1D_19F/1/pdata/1/");
```

ucsf (Sparky) import:

```julia
loadnmr("exampledata/2D_HN/1/hmqc.ucsf");
loadnmr("exampledata/1D_19F/1/");
loadnmr("exampledata/1D_19F/1/pdata/1");
loadnmr("exampledata/1D_19F/1/pdata/1/");
```
"""
function loadnmr(filename; experimentfolder=nothing, allcomponents=false)
    # 1. get format
    format, filename = getformat(filename)

    # 2. get acqus metadata
    # TODO - this assumes we're dealing with Bruker data…
    aqdic = getacqusmetadata(format, filename, experimentfolder)

    # 3. load data
    if format == :nmrpipe
        spectrum = loadnmrpipe(filename)
    elseif format == :ucsf
        spectrum = loaducsf(filename)
    elseif format == :pdata
        # TODO bruker pdata import
        spectrum = loadpdata(filename, allcomponents)
    else
        # unknown format
        throw(NMRToolsError("unknown file format for loadnmr\nfilename = " * filename))
    end

    # 4. merge in acqus metadata
    merge!(metadata(spectrum), aqdic)

    # 5. estimate the spectrum noise level
    estimatenoise!(spectrum)

    return spectrum
end

"""
    getformat(filename)

Take an input filename and return either :ucsf, :nmrpipe, :pdata (bruker processed), or :unknown after checking
whether the filename matches any known format.
"""
function getformat(filename)
    # ucsf: match XXX.ucsf
    isucsf = occursin(r"\.ucsf$", filename)
    isucsf && return :ucsf, filename

    # NMRPipe: match XXX.ft, test.ft1, test.ft2, test.ft3, test.ft4, test001.ft1, test0001.ft3, ...
    ispipe = occursin(r"[a-zA-Z0-9]+(\%0[34]d)?\.ft[1234]?$", filename)
    ispipe && return :nmrpipe, filename

    # Bruker: match pdata/1, 123/pdata/101, 1/pdata/23/, etc...
    # NB. This relies on identifying the pdata folder, so would fail if the working directory is already the pdata
    isbruker = occursin(r"pdata/[0-9]+/?$", filename)
    isbruker && return :pdata, filename

    # No pdata directory specified? Test if filename/pdata/1 exists
    # If it does, return the updated path filename/pdata/1
    if isdir(filename)
        testpath = joinpath(filename, "pdata", "1")
        isdir(testpath) && return :pdata, testpath
    end

    return :unknown, filename
end```

-----------

Path: ./src/NMRIO/NMRIO.jl

```julia
module NMRIO

using ..NMRBase
using Artifacts
using ArtifactUtils
using LazyArtifacts

include("lists.jl")
include("loadnmr.jl")
include("jdx.jl")
include("acqus.jl")
include("nmrpipe.jl")
include("bruker.jl")
include("ucsf.jl")
include("exampledata.jl")


export loadnmr
export loadjdx
export FQList, getppm, getoffset

# examples
export exampledata

end
```

-----------

Path: ./src/NMRIO/exampledata.jl

```julia
function exampledata()
    println("""
Available example data:
- 1D_1H
- 1H_19F
- 1H_19F_titration
- 2D_HN
- 2D_HN_titration
- pseudo2D_T2
- pseudo2D_XSTE
- pseudo3D_HN_R2
- pseudo3D_kinetics
- 3D_HNCA
""")
end

function exampledata(name)
    if name == "1D_1H"
        loadnmr(artifact"1D_1H")
    elseif name == "1D_19F"
        loadnmr(artifact"1D_19F")
    elseif name == "1D_19F_titration"
        filenames = [joinpath(artifact"1D_19F_titration", "$i") for i=1:11]
        map(loadnmr, filenames)
    elseif name == "2D_HN"
        loadnmr(artifact"2D_HN")
    elseif name == "2D_HN_titration"
        filenames = [joinpath(artifact"2D_HN_titration", "$i/test.ft2") for i=1:11]
        map(loadnmr, filenames)
    elseif name == "pseudo2D_T2"
        loadnmr(artifact"pseudo2D_T2")
    elseif name == "pseudo2D_XSTE"
        loadnmr(artifact"pseudo2D_XSTE")
    elseif name == "pseudo3D_HN_R2"
        loadnmr(artifact"pseudo3D_HN_R2")
    elseif name == "pseudo3D_kinetics"
        loadnmr(artifact"pseudo3D_kinetics")
    elseif name == "3D_HNCA"
        loadnmr(artifact"3D_HNCA")
    else
        throw(NMRToolsError("example data $name not found. Call exampledata() to list available data"))
    end
end```

-----------

Path: ./src/NMRIO/bruker.jl

```julia
"""
    loadpdata(filename, allcomponents=false)

Filename will be a reference to a pdata folder.
"""
function loadpdata(filename, allcomponents=false)
    # 1. get reference to pdata/X directory
    if isdir(filename)
        pdir = filename
    else
        pdir = dirname(filename)
    end
    isdir(pdir) ||
        throw(NMRToolsError("can't load bruker data, pdata directory $pdir does not exist"))

    # 2. get a list of pdata input files (which depends on the dimension of the spectrum)
    ndim = 0
    datafiles = []
    if isfile(joinpath(pdir, "1r"))
        ndim = 1
        datafiles = ["1r", "1i"]
    elseif isfile(joinpath(pdir, "2rr"))
        ndim = 2
        datafiles = ["2rr", "2ri", "2ir", "2ii"]
    elseif isfile(joinpath(pdir, "3rrr"))
        ndim = 3
        datafiles = ["3rrr", "3rri", "3rir", "3rii", "3irr", "3iri", "3iir", "3iii"]
    end
    ndim > 0 ||
        throw(NMRToolsError("can't load bruker data, pdata directory $pdir does not contain binary data files (1r/2rr/3rrr etc.)"))

    # 2b. only include the realest component unless requested
    if !allcomponents
        datafiles = [first(datafiles)]
    end

    # 2c. check these files actually exist
    datafiles = map(x -> joinpath(pdir, x), datafiles)
    filter!(isfile, datafiles)

    # 3. read procs files (containing axis metadata)
    procsfiles = ["procs", "proc2s", "proc3s", "proc4s"]
    procsdics = [loadjdx(joinpath(pdir, procsfiles[i])) for i in 1:ndim]

    # 4. TODO parse procs into main axis metadata
    md = Dict{Symbol,Any}()  # main dictionary for metadata
    md[:ndim] = ndim
    # populate metadata for each dimension
    axesmd = []
    for i in 1:ndim
        dic = Dict{Symbol,Any}()
        procdic = procsdics[i]

        # add some data in a nice format
        if procdic[:ft_mod] == 0
            dic[:pseudodim] = true
            dic[:label] = ""
            dic[:npoints] = procdic[:tdeff] # NB use this and not SI to avoid regions of zeros - trim them out later
            dic[:val] = 1:dic[:npoints] # coordinates for this dimension are just 1 to N
        else # frequency domain
            dic[:pseudodim] = false
            dic[:label] = procdic[:axnuc]
            dic[:bf] = procdic[:sf]  # NB this includes the addition of SR
            # see bruker processing reference, p. 85
            # (SR = SF - BF1, where SF is proc par and BF1 is acqu par)

            # extleftppm = procdic[:offset] # edge of extracted region, in ppm
            extswhz = procdic[:sw_p] # sw of extracted region, in Hz
            extswppm = extswhz / dic[:bf]

            # full sw = ftsize / stsi * sw of extracted region
            dic[:swhz] = procdic[:ftsize] / procdic[:stsi] * procdic[:sw_p]
            dic[:swppm] = dic[:swhz] / dic[:bf]

            # chemical shift at point STSR = offset ppm
            # ppm per point = full sw / ftsize
            # midpoint = ftsize ÷ 2
            # true offset = offset + (STSR-midpoint)*ppmperpoint
            extoffset = procdic[:offset]
            ppmperpoint = dic[:swppm] / procdic[:ftsize]
            midpoint = procdic[:ftsize] ÷ 2
            offsetppm = extoffset + (procdic[:stsr] - midpoint) * ppmperpoint

            dic[:offsetppm] = offsetppm #dic[:offsethz] / dic[:bf]
            dic[:offsethz] = offsetppm * dic[:bf] #procdic[:offset]*dic[:bf] - dic[:swhz]/2
            dic[:sf] = dic[:offsethz] * 1e-6 + dic[:bf]

            # if procdic[:lpbin] == 0
            dic[:td] = procdic[:tdeff] ÷ 2  # number of COMPLEX points, after LP, before ZF
            # else
            #     dic[:td] = procdic[:lpbin] ÷ 2
            # end
            dic[:tdzf] = procdic[:ftsize] #÷ 2  # number of COMPLEX points
            dic[:aq] = dic[:td] / dic[:swhz]

            # get any extracted regions and number of points
            dic[:npoints] = procdic[:stsi]
            if procdic[:stsr] == 0
                dic[:region] = missing
            else
                dic[:region] = procdic[:stsr]:(procdic[:stsr] + procdic[:stsi] - 1)
            end

            # chemical shift values
            δ = LinRange(procdic[:offset], procdic[:offset] - extswppm, dic[:npoints] + 1)
            dic[:val] = δ[1:(end - 1)]

            # create a representation of the window function
            # calculate acquisition time = td / 2*sw
            w = procdic[:wdw]
            if w == 0
                window = NullWindow(dic[:aq])
            elseif w == 1
                window = ExponentialWindow(procdic[:lb], dic[:aq])
            elseif w == 2
                warn("Gaussian window not yet implemented")
                window = UnknownWindow(dic[:aq])
            elseif w == 3
                ssb = procdic[:ssb]
                if ssb < 1
                    ssb = 1
                end
                window = SineWindow(1 - 1.0 / ssb, 1, 1, dic[:aq]) # offset, endpoint, power
            elseif w == 4
                ssb = procdic[:ssb]
                if ssb < 1
                    ssb = 1
                end
                window = SineWindow(1 - 1.0 / ssb, 1, 2, dic[:aq]) # offset, endpoint, power
            else
                window = UnknownWindow(dic[:aq])
            end
            dic[:window] = window
        end

        dic[:procs] = procsdics[i] # store procs file in main axis dictionary
        push!(axesmd, dic)
    end

    # 5. determine shape and submatrix size
    shape = [procs[:si] for procs in procsdics]
    submatrix = [procs[:xdim] for procs in procsdics]

    # 6. check data format (default to Int32)
    dtype = get(procsdics[1], :dtypp, 1) == 2 ? Float64 : Int32

    # 7. check endianness (default to little)
    endian = get(procsdics[1], :bytordp, 0) == 1 ? "b" : "l"

    # 8. read the data files
    dat = map(datafile -> readpdatabinary(datafile, shape, submatrix, dtype, endian),
              datafiles)

    # 9. combine into real/complex/multicomplex output
    if !allcomponents
        y = first(dat)
    elseif ndim == 1
        if length(dat) == 1
            @warn "unable to find imaginary data for import of $filename - returning real values only"
            y = dat
        else
            y = dat[1] + 1im .* dat[2]
        end
    else
        if length(dat) == 1
            @warn "unable to find imaginary data for import of $filename - returning real values only"
            y = dat
        elseif length(dat) == 2
            # only two components - return complex data regardless of what particular files are present
            # (see https://rdrr.io/github/ssokolen/rnmrfit/man/read_processed_2d.html for similar approach)
            y = dat[1] + 1im .* dat[2]
        else
            # TODO
            @warn "import of multicomplex data not yet implemented - returning real values only"
            y = dat
        end
    end

    # 10. scale
    y = one(Float64) * y
    scalepdata!(y, procsdics[1])

    # 11. trim out any regions of zero data
    y = y[[1:axesmd[i][:npoints] for i in 1:ndim]...]

    # 12. form NMRData and return
    if ndim == 1
        valx = axesmd[1][:val]
        delete!(axesmd[1], :val) # remove values from metadata to prevent confusion when slicing up

        xaxis = F1Dim(valx; metadata=axesmd[1])

        NMRData(y, (xaxis,); metadata=md)
    elseif ndim == 2
        val1 = axesmd[1][:val]
        val2 = axesmd[2][:val]
        delete!(axesmd[1], :val) # remove values from metadata to prevent confusion when slicing up
        delete!(axesmd[2], :val)

        xaxis = F1Dim(val1; metadata=axesmd[1])

        ax2 = axesmd[2][:pseudodim] ? X2Dim : F2Dim
        yaxis = ax2(val2; metadata=axesmd[2])

        NMRData(y, (xaxis, yaxis); metadata=md)
    elseif ndim == 3
        # rearrange data into a useful order - always place pseudo-dimension last - and generate axes
        # 1 is always direct, and should be placed first (i.e. 1 x x)
        # if is there is a pseudodimension, put that last (i.e. 1 y p)
        pdim = [axesmd[i][:pseudodim] for i in 1:3]

        val1 = axesmd[1][:val]
        val2 = axesmd[2][:val]
        val3 = axesmd[3][:val]
        delete!(axesmd[1], :val) # remove values from metadata to prevent confusion when slicing up
        delete!(axesmd[2], :val)
        delete!(axesmd[3], :val)

        if pdim[2]
            if pdim[3]
                # two pseudodimensions - keep default ordering
                xaxis = F1Dim(val1; metadata=axesmd[1])
                yaxis = X2Dim(val2; metadata=axesmd[2])
                zaxis = X3Dim(val3; metadata=axesmd[3])
            else
                # dimensions are x p y => we want ordering 1 3 2
                xaxis = F1Dim(val1; metadata=axesmd[1])
                yaxis = F2Dim(val3; metadata=axesmd[3])
                zaxis = X3Dim(val2; metadata=axesmd[2])
                y = permutedims(y, [1, 3, 2])
            end
        elseif pdim[3]
            # dimensions are x y p => we want ordering 1 2 3
            xaxis = F1Dim(val1; metadata=axesmd[1])
            yaxis = F2Dim(val2; metadata=axesmd[2])
            zaxis = X3Dim(val3; metadata=axesmd[3])
        else
            # no pseudodimension, use Z axis not Ti
            # dimensions are x y z => we want ordering 1 2 3
            xaxis = F1Dim(val1; metadata=axesmd[1])
            yaxis = F2Dim(val2; metadata=axesmd[2])
            zaxis = F3Dim(val3; metadata=axesmd[3])
        end

        NMRData(y, (xaxis, yaxis, zaxis); metadata=md)
    else
        throw(NMRToolsError("loadnmr cannot currently handle 4D+ experiments"))
    end
end

function scalepdata!(y, procs, reverse=false)
    if reverse
        y .*= 2.0^(-get(procs, :nc_proc, 1))
    else
        y .*= 2.0^(get(procs, :nc_proc, 1))
    end
end

function readpdatabinary(filename, shape, submatrix, dtype, endian)
    # preallocate header
    np = foldl(*, shape)
    y = zeros(dtype, np)

    # read the file
    open(filename) do f
        return read!(f, y)
    end
    convertor = endian == "b" ? ntoh : ltoh # get convertor function for big/little-to-host
    y = convertor(y)

    return reordersubmatrix(y, shape, submatrix)
end

function reordersubmatrix(yin, shape, submatrix, reverse=false)
    ndim = length(shape)
    if ndim == 1
        # do nothing to 1D data
        return yin
    end

    nsub = @. Int(ceil(shape / submatrix))
    nsubs = foldl(*, nsub)
    N = length(yin)
    sublength = foldl(*, submatrix)

    subshape = vcat(nsubs, submatrix)
    if reverse
        yout = zeros(eltype(yin), N)
    else
        yout = zeros(eltype(yin), shape...)
    end

    ci = CartesianIndices(ones(nsub...))
    for n in 1:nsubs
        idx = ci[n]
        slices = [(1 + (idx[i] - 1) * submatrix[i]):(idx[i] * submatrix[i]) for i in 1:ndim]
        vecslice = (1 + (n - 1) * sublength):(n * sublength)
        if reverse
            yout[vecslice] = yin[slices...]
        else
            yout[slices...] = yin[vecslice]
        end
    end

    return yout
end```

-----------

Path: ./src/NMRIO/nmrpipe.jl

```julia
function loadnmrpipe(filename)
    if occursin(r"%0[34]d", filename)
        # something like test%03d.ft2
        filename1 = expandpipetemplate(filename, 1)
    else
        filename1 = filename
    end
    # parse the header
    md, mdax = loadnmrpipeheader(filename1)

    ndim = md[:ndim]
    if ndim == 1
        loadnmrpipe1d(filename, md, mdax)
    elseif ndim == 2
        loadnmrpipe2d(filename, md, mdax)
    elseif ndim == 3
        loadnmrpipe3d(filename, md, mdax)
    else
        throw(NMRToolsError("can't load data $(filename), unsupported number of dimensions."))
    end
end

function expandpipetemplate(template, n)
    return replace(template, "%03d" => lpad(n, 3, "0"), "%04d" => lpad(n, 4, "0"))
end

function loadnmrpipeheader(filename)
    # check file exists
    isfile(filename) ||
        throw(NMRToolsError("cannot load $(filename), not a recognised file."))

    # preallocate header
    header = zeros(Float32, 512)

    # read the file
    open(filename) do f
        return read!(f, header)
    end

    # parse the header, returning md and mdax
    return parsenmrpipeheader(header)
end

"""
    parsenmrpipeheader(header)

Pass a 512 x 4 byte array containing an nmrPipe header file, and returns dictionaries of metadata.
The nmrPipe header format is defined in `fdatap.h`.

# Return values
- `md`: dictionary of spectrum metadata
- `mdax`: array of dictionaries containing axis metadata

# Examples
```julia
md, mdax = parsenmrpipeheader(header)
```
"""
function parsenmrpipeheader(header::Vector{Float32})
    # declare constants for clarity in accessing nmrPipe header

    # general parameters (independent of number of dimensions)
    genpars = Dict(:FDMAGIC => 1,
                   :FDFLTFORMAT => 2,
                   :FDFLTORDER => 3,
                   :FDPIPEFLAG => (Int, 58),  #Dimension code of data stream
                   :FDCUBEFLAG => (Int, 448),
                   :FDSIZE => (Int, 100),
                   :FDSPECNUM => (Int, 220),
                   :FDQUADFLAG => (Int, 107),
                   :FD2DPHASE => (Int, 257),
                   :FDTRANSPOSED => (Int, 222),
                   :FDDIMCOUNT => (Int, 10),
                   :FDDIMORDER => (Int, 25:28),
                   :FDFILECOUNT => (Int, 443),
                   :FDSIZE => (Int, (100, 220, 16, 33)))
    # dimension-specific parameters
    dimlabels = (17:18, 19:20, 21:22, 23:24) # UInt8
    dimpars = Dict(:FDAPOD => (Int, (96, 429, 51, 54)),
                   :FDSW => (101, 230, 12, 30),
                   :FDOBS => (120, 219, 11, 29),
                   :FDOBSMID => (379, 380, 381, 382),
                   :FDORIG => (102, 250, 13, 31),
                   :FDUNITS => (Int, (153, 235, 59, 60)),
                   :FDQUADFLAG => (Int, (57, 56, 52, 55)),
                   :FDFTFLAG => (Int, (221, 223, 14, 32)),
                   :FDCAR => (67, 68, 69, 70),
                   :FDCENTER => (80, 81, 82, 83),
                   :FDOFFPPM => (481, 482, 483, 484),
                   :FDP0 => (110, 246, 61, 63),
                   :FDP1 => (111, 247, 62, 64),
                   :FDAPODCODE => (Int, (414, 415, 401, 406)),
                   :FDAPODQ1 => (416, 421, 402, 407),
                   :FDAPODQ2 => (417, 422, 403, 408),
                   :FDAPODQ3 => (418, 423, 404, 409),
                   :FDLB => (112, 244, 373, 374),
                   :FDGB => (375, 276, 377, 378),
                   :FDGOFF => (383, 384, 385, 386),
                   :FDC1 => (419, 424, 405, 410),
                   :FDZF => (Int, (109, 438, 439, 440)),
                   :FDX1 => (Int, (258, 260, 262, 264)),
                   :FDXN => (Int, (259, 261, 263, 265)),
                   :FDFTSIZE => (Int, (97, 99, 201, 202)),
                   :FDTDSIZE => (Int, (387, 388, 389, 390)))

    # check correct endian-ness
    if header[genpars[:FDFLTORDER]] ≉ 2.345
        header = bswap.(header)
    end

    # populate spectrum metadata
    md = Dict{Symbol,Any}()  # main dictionary for metadata
    pipemd = Dict{Symbol,Any}()  # dictionary to hold all the complete pipe header information
    for k in keys(genpars)
        x = genpars[k]
        # cast to new type if needed
        if x[1] isa Type
            if length(x[2]) == 1
                pipemd[k] = x[1].(header[x[2]])
            else
                # array parameter
                pipemd[k] = [x[1].(header[i]) for i in x[2]]
            end
        else
            pipemd[k] = Float64(header[x])
        end
    end

    # add some metadata in nice format
    ndim = pipemd[:FDDIMCOUNT]
    md[:ndim] = ndim

    # store full NMRPipe header in main dictionary
    md[:pipe] = pipemd

    # populate metadata for each dimension
    axesmd = []
    for i in 1:ndim
        dic = Dict{Symbol,Any}()
        pipedic = Dict{Symbol,Any}()
        for k in keys(dimpars)
            x = dimpars[k]
            # cast to new type if needed
            if x[1] isa Type
                pipedic[k] = x[1].(header[x[2][i]])
            else
                pipedic[k] = Float64(header[x[i]])
            end
        end
        # add label, removing null characters
        tmp = reinterpret(UInt8, header[dimlabels[i]])
        dic[:label] = String(tmp[tmp .≠ 0])

        # add some data in a nice format
        if pipedic[:FDFTFLAG] == 0
            dic[:pseudodim] = true
            dic[:npoints] = pipedic[:FDTDSIZE]
            dic[:val] = 1:dic[:npoints] # coordinates for this dimension are just 1 to N
        else # frequency domain
            dic[:pseudodim] = false
            dic[:td] = pipedic[:FDTDSIZE]
            dic[:tdzf] = pipedic[:FDFTSIZE]
            dic[:bf] = pipedic[:FDOBS]
            dic[:swhz] = pipedic[:FDSW]
            dic[:swppm] = dic[:swhz] / dic[:bf]
            swregion = dic[:swppm]
            dic[:offsetppm] = pipedic[:FDCAR]
            dic[:offsethz] = (dic[:offsetppm] * 1e-6 + 1) * dic[:bf]
            dic[:sf] = dic[:offsethz] * 1e-6 + dic[:bf]
            if pipedic[:FDX1] == 0 && pipedic[:FDXN] == 0
                dic[:region] = missing
                dic[:npoints] = dic[:tdzf]
            else
                dic[:region] = pipedic[:FDX1]:pipedic[:FDXN]
                dic[:npoints] = length(dic[:region])

                dic[:swhz] *= dic[:tdzf] / dic[:npoints]
                dic[:swppm] *= dic[:tdzf] / dic[:npoints]
            end

            edge_frq = pipedic[:FDORIG]
            # calculate chemical shift values
            cs_at_edge = edge_frq / dic[:bf]
            cs_at_other_edge = cs_at_edge + swregion
            x = range(cs_at_other_edge, cs_at_edge; length=dic[:npoints] + 1)
            dic[:val] = x[2:end]
            # # alternative calculation (without extraction) - this agrees OK
            # x = range(dic[:offsetppm] + 0.5*dic[:swppm], dic[:offsetppm] - 0.5*dic[:swppm], length=dic[:npoints]+1)
            # dic[:val2] = x[1:end-1]

            # create a representation of the window function
            # calculate acquisition time = td / sw
            dic[:aq] = dic[:td] / dic[:swhz]
            #:FDAPODCODE => "Window function used (0=none, 1=SP, 2=EM, 3=GM, 4=TM, 5=ZE, 6=TRI)",
            w = pipedic[:FDAPODCODE]
            q1 = pipedic[:FDAPODQ1]
            q2 = pipedic[:FDAPODQ2]
            q3 = pipedic[:FDAPODQ3]
            if w == 0
                window = NullWindow(dic[:aq])
            elseif w == 1
                window = SineWindow(q1, q2, q3, dic[:aq])
            elseif w == 2
                window = ExponentialWindow(q1, dic[:aq])
            elseif w == 3
                window = GaussWindow(q1, q2, q3, dic[:aq])
            else
                window = UnknownWindow(dic[:aq])
            end
            dic[:window] = window
        end

        dic[:pipe] = pipedic # store pipe header info in main axis dictionary
        push!(axesmd, dic)
    end

    return md, axesmd
end

"""
    loadnmrpipe1d(filename, md, mdax)

Return an NMRData array containing spectrum and associated metadata.
"""
function loadnmrpipe1d(filename, md, mdax)
    npoints = mdax[1][:npoints]
    # preallocate data (and dummy header)
    header = zeros(Float32, 512)
    y = zeros(Float32, npoints)

    # read the file
    open(filename) do f
        read!(f, header)
        return read!(f, y)
    end
    y = Float64.(y)

    valx = mdax[1][:val]
    delete!(mdax[1], :val) # remove values from metadata to prevent confusion when slicing up
    xaxis = F1Dim(valx; metadata=mdax[1])

    return NMRData(y, (xaxis,); metadata=md)
end

"""
    loadnmrpipe2d(filename, md, mdax)

Return NMRData containing spectrum and associated metadata.
"""
function loadnmrpipe2d(filename::String, md, mdax)
    npoints1 = mdax[1][:npoints]
    npoints2 = mdax[2][:npoints]
    transposeflag = md[:pipe][:FDTRANSPOSED] > 0

    # preallocate data (and dummy header)
    header = zeros(Float32, 512)
    if transposeflag
        y = zeros(Float32, npoints2, npoints1)
    else
        y = zeros(Float32, npoints1, npoints2)
    end

    # read the file
    open(filename) do f
        read!(f, header)
        return read!(f, y)
    end
    if transposeflag
        y = transpose(y)
    end
    y = Float64.(y)

    valx = mdax[1][:val]
    delete!(mdax[1], :val) # remove values from metadata to prevent confusion when slicing up
    valy = mdax[2][:val]
    delete!(mdax[2], :val) # remove values from metadata to prevent confusion when slicing up
    ax2 = mdax[2][:pseudodim] ? X2Dim : F2Dim
    xaxis = F1Dim(valx; metadata=mdax[1])
    yaxis = ax2(valy; metadata=mdax[2])

    return NMRData(y, (xaxis, yaxis); metadata=md)
end

"""
    loadnmrpipe3d(filename, md, mdax)

Return NMRData containing spectrum and associated metadata.
"""
function loadnmrpipe3d(filename::String, md, mdax)
    datasize = md[:pipe][:FDSIZE][1:3]

    # load data
    header = zeros(Float32, 512)
    y = zeros(Float32, datasize...)
    if md[:pipe][:FDPIPEFLAG] == 0
        # series of 2D files
        y2d = zeros(Float32, datasize[1], datasize[2])
        for i in 1:datasize[3]
            filename1 = expandpipetemplate(filename, i)
            open(filename1) do f
                read!(f, header)
                return read!(f, y2d)
            end
            y[:, :, i] = y2d
        end
    else
        # single stream
        open(filename) do f
            read!(f, header)
            return read!(f, y)
        end
    end
    y = Float64.(y)

    # get axis values
    val1 = mdax[1][:val]
    val2 = mdax[2][:val]
    val3 = mdax[3][:val]
    delete!(mdax[1], :val) # remove values from metadata to prevent confusion when slicing up
    delete!(mdax[2], :val)
    delete!(mdax[3], :val)

    # y is currently in order of FDSIZE - we need to rearrange
    dimorder = md[:pipe][:FDDIMORDER][1:3]
    tr = md[:pipe][:FDTRANSPOSED]

    # figure out current ordering of data matrix
    # e.g. order = [2 1 3] indicates the data matrix is axis2 x axis1 x axis3
    if tr == 0
        order = [findfirst(x -> x .== i, dimorder) for i in [2, 1, 3]]
    else # transpose flag
        # swap first two entries of dimorder round
        dimorder2 = [dimorder[2], dimorder[1], dimorder[3]]
        order = [findfirst(x -> x .== i, dimorder2) for i in [1, 2, 3]]
    end
    # calculate the permutation required to bring the data matrix into the order axis1 x axis2 x axis3
    unorder = [findfirst(x -> x .== i, order) for i in [1, 2, 3]]
    y = permutedims(y, unorder)

    # finally rearrange data into a useful order - always place pseudo-dimension last - and generate axes
    # 1 is always direct, and should be placed first (i.e. 1 x x)
    # is there is a pseudodimension, put that last (i.e. 1 y p)
    # otherwise, return data in the order 1 2 3 = order of fid.com, inner -> outer loop
    pdim = [mdax[i][:pseudodim] for i in 1:3]
    if pdim[2]
        # dimensions are x p y => we want ordering 1 3 2
        xaxis = F1Dim(val1; metadata=mdax[1])
        yaxis = F2Dim(val3; metadata=mdax[3])
        zaxis = X3Dim(val2; metadata=mdax[2])
        y = permutedims(y, [1, 3, 2])
    elseif pdim[3]
        # dimensions are x y p => we want ordering 1 2 3
        xaxis = F1Dim(val1; metadata=mdax[1])
        yaxis = F2Dim(val2; metadata=mdax[2])
        zaxis = X3Dim(val3; metadata=mdax[3])
    else
        # no pseudodimension, use Z axis not Ti
        # dimensions are x y z => we want ordering 1 2 3
        xaxis = F1Dim(val1; metadata=mdax[1])
        yaxis = F2Dim(val2; metadata=mdax[2])
        zaxis = F3Dim(val3; metadata=mdax[3])
    end

    return NMRData(y, (xaxis, yaxis, zaxis); metadata=md)
end```

-----------

Path: ./src/NMRIO/acqus.jl

```julia
function getacqusmetadata(format, filename, experimentfolder=nothing)
    md = Dict{Symbol,Any}()
    md[:format] = format

    # try to locate the folder containing the acqus file
    if isnothing(experimentfolder)
        if format == :nmrpipe
            # assume that acqus is in same directory as test.ft2 files, and one up from ft/test%03d.ft2 files
            experimentfolder = dirname(filename)
            if occursin("%", basename(filename))
                # move up a directory
                experimentfolder = dirname(experimentfolder)
            end
        elseif format == :ucsf
            # assume that acqus is in same directory as ucsf file
            experimentfolder = dirname(filename)
        elseif format == :pdata
            # move up two directories from X/pdata/Y to X
            if isdir(filename)
                if isdirpath(filename)
                    # filename = X/pdata/Y/
                    # dirname = X/pdata/Y
                    experimentfolder = dirname(dirname(dirname(filename)))
                else
                    # filename = X/pdata/Y
                    # dirname = X/pdata
                    experimentfolder = dirname(dirname(filename))
                end
            else
                experimentfolder = dirname(dirname(dirname(filename)))
            end
        end
    else
        # if the passed experiment folder isn't a directory, use the enclosing directory
        if !isdir(experimentfolder)
            @warn "passed experiment folder $experimentfolder is not a directory"
            if isfile(experimentfolder)
                experimentfolder = dirname(experimentfolder)
            end
        end
    end

    # add filenames to metadata
    md[:filename] = filename
    md[:experimentfolder] = experimentfolder

    # parse the acqus file
    acqusfilename = joinpath(experimentfolder, "acqus")
    if isfile(acqusfilename)
        acqusmetadata = parseacqus(acqusfilename)
        md[:acqus] = acqusmetadata
        md[:topspin] = acqusmetadata[:topspin]
        md[:ns] = acqusmetadata[:ns]
        md[:rg] = acqusmetadata[:rg]
        md[:pulseprogram] = acqusmetadata[:pulprog]
        md[:acqusfilename] = acqusfilename
    else
        @warn "cannot locate acqus file for $(filename) - some metadata will be missing"
    end

    # parse the acquXs files, if they exist, and store in :acquXs dict entries
    for i in 2:4
        acquXsfilename = joinpath(experimentfolder, "acqu$(i)s")
        if isfile(acquXsfilename)
            acquXsmetadata = parseacqus(acquXsfilename, false) # don't parse aux files
            md[Symbol("acqu$(i)s")] = acquXsmetadata
        else
            break
        end
    end

    # load the title file
    titlefilename = joinpath(experimentfolder, "pdata", "1", "title")
    if isfile(titlefilename)
        title = read(titlefilename, String)
        md[:title] = strip(title)
        # use first line of title for experiment label
        titleline1 = split(title, "\n")[1]
        md[:label] = titleline1
    else
        @warn "cannot locate title file for $(filename) - some metadata will be missing"
    end

    return md
end

function parseacqus(acqusfilename::String, auxfiles=true)
    dic = loadjdx(acqusfilename)

    if auxfiles
        # add the topspin version to the dictionary
        dic[:topspin] = topspinversion(acqusfilename)

        # lastly, check for referenced files like vclist, fq1list, and load these in place of filename
        parseacqusauxfiles!(dic, dirname(acqusfilename))
    end

    return dic
end

"""
    parsetopspinversion(acqusfilename)

Return the TopSpin version as a VersionNumber (e.g. v"4.2.0").

This is obtained from the end of the first line of the acqus file, e.g.
```
##TITLE= Parameter file, TopSpin 4.2.0
##TITLE= Parameter file, TOPSPIN		Version 2.1
##TITLE= Parameter file, TOPSPIN		Version 3.2
```
"""
function topspinversion(acqusfilename)
    isfile(acqusfilename) ||
        throw(NMRToolsError("getting TopSpin version: $(acqusfilename) is not a valid acqus file"))

    firstline = readlines(acqusfilename)[1]
    version = split(firstline)[end]

    return VersionNumber(version)
end

function parseacqusauxfiles!(dic, basedir)
    # TS 4.0.8 - pulseprogram / pulseprogram.precomp introduced
    # TS 4.1.4 - lists directory introduced
    if dic[:topspin] < v"4.1.4"
        _parseacqusauxfiles_TS3!(dic, basedir)
    else
        _parseacqusauxfiles_TS4!(dic, basedir)
    end
end

function _parseacqusauxfiles_TS3!(dic, basedir)
    # filenames aren't actually used before TS4 - e.g. vclist is always stored as vclist
    if get(dic, :vclist, "") != ""
        filename = joinpath(basedir, "vclist")
        if isfile(filename)
            dic[:vclist] = parsevclist(filename)
        end
    end

    if get(dic, :vdlist, "") != ""
        filename = joinpath(basedir, "vdlist")
        if isfile(filename)
            dic[:vdlist] = parsevdlist(filename)
        end
    end

    if get(dic, :vplist, "") != ""
        filename = joinpath(basedir, "vplist")
        if isfile(filename)
            dic[:vplist] = parsevplist(filename)
        end
    end

    if get(dic, :valist, "") != ""
        filename = joinpath(basedir, "valist")
        if isfile(filename)
            dic[:valist] = parsevalist(filename)
        end
    end

    for k in
        (:fq1list, :fq2list, :fq3list, :fq4list, :fq5list, :fq6list, :fq7list, :fq8list)
        get(dic, k, "") == "" && continue

        filename = joinpath(basedir, string(k))
        isfile(filename) || continue

        dic[k] = parsefqlist(filename)
    end
end

function _parseacqusauxfiles_TS4!(dic, basedir)
    vclistfile = joinpath(basedir, "lists", "vc", get(dic, :vclist, ""))
    if isfile(vclistfile)
        dic[:vclist] = parsevclist(vclistfile)
    end

    vdlistfile = joinpath(basedir, "lists", "vd", get(dic, :vdlist, ""))
    if isfile(vdlistfile)
        dic[:vdlist] = parsevdlist(vdlistfile)
    end

    vplistfile = joinpath(basedir, "lists", "vp", get(dic, :vplist, ""))
    if isfile(vplistfile)
        dic[:vplist] = parsevplist(vplistfile)
    end

    valistfile = joinpath(basedir, "lists", "va", get(dic, :valist, ""))
    if isfile(valistfile)
        dic[:valist] = parsevalist(valistfile)
    end

    for k in
        (:fq1list, :fq2list, :fq3list, :fq4list, :fq5list, :fq6list, :fq7list, :fq8list)
        fqlistfile = joinpath(basedir, "lists", "f1", get(dic, k, ""))
        isfile(fqlistfile) || continue
        dic[k] = parsefqlist(fqlistfile)
    end

    # lists/pp (pulseprogram)
    # lists/gp
    # lists/vc
    # lists/vd
    # lists/va
    # lists/vp
    # lists/f1 (frequencies)
    # referred to by name in the acqus file
end

function parsevclist(filename)
    x = readlines(filename)
    xint = tryparse.(Int, x)
    if any(xint .== nothing)
        @warn "Unable to parse format of vclist $filename"
        return x
    end

    return xint
end

"return vdlist contents in seconds"
function parsevdlist(filename)
    x = readlines(filename)
    # default unit for vdlist is seconds
    x = replace.(x, "u" => "e-6")
    x = replace.(x, "m" => "e-3")
    x = replace.(x, "s" => "")
    xf = tryparse.(Float64, x)
    if any(xf .== nothing)
        @warn "Unable to parse format of vdlist $filename"
        return x
    end

    return xf
end

"return vplist contents in seconds"
function parsevplist(filename)
    x = readlines(filename)
    # default unit for vplist is seconds
    x = map(x) do line
        line = replace(line, "u" => "")
        line = replace(line, "m" => "e3")
        return line = replace(line, "s" => "e6")
    end

    xf = tryparse.(Float64, x)

    if any(xf .== nothing)
        @warn "Unable to parse format of vplist $filename"
        return x
    end

    return xf * 1e-6  # return vplist in seconds
end

"return valist contents in dB"
function parsevalist(filename)
    x = readlines(filename)

    # power unit must be specified on first lien
    powertoken = popfirst!(x)

    # parse the rest of the list
    xf = tryparse.(Float64, x)

    if any(xf .== nothing)
        @warn "Unable to parse format of valist $filename"
        return x
    end

    # convert to dB if needed
    if powertoken == "Watt"
        @info "converting valist from Watt to dB"
        xf = -10 * log10.(xf)
    end
    return xf
end

"""
    parsefqlist(filename)

Return contents of the specified fqlist.

fqlists can have several different formats:

first line   | reference   | unit
----------------------------------
             | sfo         | Hz
sfo hz       | sfo         | Hz
sfo ppm      | sfo         | ppm
bf hz        | bf          | Hz
bf ppm       | bf          | ppm
p            | sfo         | ppm
P            | bf          | ppm

"""
function parsefqlist(filename)
    x = readlines(filename)

    if isnumeric(x[1][1])
        # first character of first line is a number => no header line
        unit = :Hz
        relative = true
    else
        firstline = popfirst!(x)
        if firstline == "p"
            unit = :ppm
            relative = true
        elseif firstline == "P"
            unit = :ppm
            relative = false
        elseif lowercase(firstline) == "bf hz"
            unit = :Hz
            relative = false
        elseif lowercase(firstline) == "bf ppm"
            unit = :ppm
            relative = false
        elseif lowercase(firstline) == "sfo hz"
            unit = :Hz
            relative = true
        elseif lowercase(firstline) == "sfo ppm"
            unit = :ppm
            relative = true
        else
            @warn "Unable to parse format of fqlist $filename"
            return x
        end
    end

    # parse the rest of the list
    xf = tryparse.(Float64, x)

    if any(xf .== nothing)
        @warn "Unable to parse format of fqlist $filename"
        return x
    end

    fqlist = FQList(xf, unit, relative)

    return fqlist
end
```

-----------

Path: ./src/NMRIO/jdx.jl

```julia
function loadjdx(filename::String)
    isfile(filename) ||
        throw(NMRToolsError("loading JCAMP-DX data: $(filename) is not a valid file"))

    dat = open(filename) do f
        return read(f, String)
    end

    fields = [strip(strip(x), '$') for x in split(dat, "##")]
    dic = Dict{Symbol,Any}()
    for field in fields
        field == "" && continue # skip empty lines
        x = split(field, "= ")
        if length(x) > 1
            # store keys as uppercase - there's only a couple of annoying exceptions like NusAMOUNT
            # and forcing uppercase makes it easier to access, e.g. as :vclist not :VCLIST
            dic[Symbol(lowercase(x[1]))] = parsejdxentry(x[2])
        end
    end

    return dic
end

function parsejdxentry(dat)
    if dat[1] == '('
        # array data - split into fields
        fields = split(split(dat, ")\n")[2])
        parsed = map(parsejdxfield, fields)
        if parsed isa Vector{Real}
            parsed = float.(parsed)
        end
        # create a dictionary, 0 => p0, 1 => p1, etc.
        parsed = Dict(zip(0:(length(parsed) - 1), parsed))
    else
        parsed = parsejdxfield(dat)
    end
    return parsed
end

function parsejdxfield(dat)
    if dat[1] == '<' # <string>
        dat = dat[2:(end - 1)]
    else
        x = tryparse(Int64, dat)
        if isnothing(x)
            dat = tryparse(Float64, dat)
        else
            dat = x
        end
    end
    return dat
end
```

-----------

Path: ./src/NMRIO/ucsf.jl

```julia
# UCSF format:
# - https://www.cgl.ucsf.edu/home/sparky/manual/files.html
# - https://github.com/jjhelmus/nmrglue/blob/master/nmrglue/fileio/sparky.py

function loaducsf(filename)
    # parse the header
    md, mdax = loaducsfheader(filename)

    ndim = md[:ndim]
    if ndim == 2
        loaducsf2d(filename, md, mdax)
    elseif ndim == 3
        loaducsf3d(filename, md, mdax)
    else
        throw(NMRToolsError("can't load data $(filename), unsupported number of dimensions ($ndim)."))
    end
end

function loaducsfheader(filename)
    # check file exists
    isfile(filename) ||
        throw(NMRToolsError("cannot load $(filename), not a recognised file."))

    md = parseucsfheader(filename)
    ndim = md[:ndim]

    # load the dimension headers
    # 128 bytes per axis, after the initial 180
    axisheaders = zeros(UInt8, 128 * ndim)
    open(filename) do f
        read(f, 180)
        return read!(f, axisheaders)
    end
    # axisheaders = ntoh.(axisheaders)
    axisheaders = reshape(axisheaders, :, ndim)

    # parse the header, returning md and mdax
    mdax = [parseucsfaxisheader(axisheaders[:, i]) for i in 1:ndim]

    return md, mdax
end

"parse ucsf file header into a dictionary"
function parseucsfheader(filename)
    # preallocate header
    header = zeros(UInt8, 180)

    # read the file
    open(filename) do f
        return read!(f, header)
    end
    header = ntoh.(header) # convert from big-endian to native

    ucsfstring = String(header[1:10])
    ucsfstring[1:8] == "UCSF NMR" ||
        throw(NMRToolsError("can't load data $(filename), invalid header (ucsfstring)."))

    version = Int(header[14])
    version == 2 ||
        throw(NMRToolsError("can't load data $(filename), unsupported file version (version=$version)."))

    ncomp = Int(header[12])
    ncomp == 1 ||
        throw(NMRToolsError("can't load data $(filename), unsupported number of components (ncomp=$ncomp)."))

    md = Dict{Symbol,Any}()

    md[:ndim] = Int(header[11])

    return md
end

"parse ucsf axis header into a dictionary"
function parseucsfaxisheader(header)
    # (NB 1-based positions)
    # position	bytes	contents
    # 1	        6	    nucleus name (1H, 13C, 15N, 31P, ...) null terminated ASCII
    # 7         2       UInt16 spectral shift
    # 9	        4	    integer, number of data points along this axis
    # 13        4	    integer, axis size (?)
    # 17	    4	    integer, tile size along this axis
    # 21	    4	    float spectrometer frequency for this nucleus (MHz)
    # 25	    4	    float spectral width (Hz)
    # 29	    4	    float center of data (ppm)
    # 33	    4	    float, zero order (phase?)
    # 37	    4	    float, first order (phase?)
    # 41	    4	    float, first point scaling

    # nucleus name
    nucleus = ntoh.(header[1:6])
    nucleus = String(nucleus[nucleus .≠ 0])

    spectralshift = Int(ntoh(reinterpret(UInt16, header[7:8])[1]))
    npoints = Int(ntoh(reinterpret(Int32, header[9:12])[1]))
    axissize = Int(ntoh(reinterpret(Int32, header[13:16])[1]))
    tilesize = Int(ntoh(reinterpret(Int32, header[17:20])[1]))
    bf = Float64(ntoh(reinterpret(Float32, header[21:24])[1]))
    swhz = Float64(ntoh(reinterpret(Float32, header[25:28])[1]))
    offsetppm = Float64(ntoh(reinterpret(Float32, header[29:32])[1]))
    zeroorder = Float64(ntoh(reinterpret(Float32, header[33:36])[1]))
    firstorder = Float64(ntoh(reinterpret(Float32, header[37:40])[1]))
    firstpointscaling = Float64(ntoh(reinterpret(Float32, header[41:44])[1]))

    md = Dict{Symbol,Any}()
    md[:label] = nucleus
    md[:spectralshift] = spectralshift
    md[:npoints] = npoints
    md[:ucsfaxissize] = axissize
    md[:ucsftilesize] = tilesize
    md[:bf] = bf
    md[:swhz] = swhz
    md[:offsetppm] = offsetppm
    md[:zeroorder] = zeroorder
    md[:firstorder] = firstorder
    md[:firstpointscaling] = firstpointscaling

    swppm = swhz / bf
    md[:offsethz] = offsetppm * bf
    md[:sf] = (1 + offsetppm / 1e6) * bf
    md[:swppm] = swppm
    md[:window] = UnknownWindow()
    md[:pseudodim] = false

    x = LinRange(offsetppm + 0.5swppm, offsetppm - 0.5swppm, npoints + 1)
    md[:val] = x[1:(end - 1)]

    return md
end

function loaducsf2d(filename, md, mdax)
    nx = mdax[2][:npoints]
    ny = mdax[1][:npoints]
    tx = mdax[2][:ucsftilesize]
    ty = mdax[1][:ucsftilesize]

    # preallocate data
    dat = zeros(Float32, nx, ny)

    # read the file
    open(filename) do f
        read(f, 180) # header
        read(f, 128) # axis header 1
        read(f, 128) # axis header 2
        return read!(f, dat)
    end
    dat = Float64.(ntoh.(dat))

    # untile the data
    dat = untileucsf2d(dat, tx, ty, nx, ny)

    # set up dimensions
    valx = mdax[2][:val]
    delete!(mdax[2], :val) # remove values from metadata to prevent confusion when slicing up
    valy = mdax[1][:val]
    delete!(mdax[1], :val) # remove values from metadata to prevent confusion when slicing up
    xaxis = F1Dim(valx; metadata=mdax[2])
    yaxis = F2Dim(valy; metadata=mdax[1])

    return NMRData(dat, (xaxis, yaxis); metadata=md)
end

function loaducsf3d(filename, md, mdax)
    nx = mdax[3][:npoints]
    ny = mdax[2][:npoints]
    nz = mdax[1][:npoints]
    tx = mdax[3][:ucsftilesize]
    ty = mdax[2][:ucsftilesize]
    tz = mdax[1][:ucsftilesize]

    # preallocate data
    dat = zeros(Float32, nx, ny, nz)

    # read the file
    open(filename) do f
        read(f, 180) # header
        read(f, 128) # axis header 1
        read(f, 128) # axis header 2
        read(f, 128) # axis header 3
        return read!(f, dat)
    end
    dat = Float64.(ntoh.(dat))

    # untile the data
    dat = untileucsf3d(dat, tx, ty, tz, nx, ny, nz)

    # set up dimensions
    valx = mdax[3][:val]
    delete!(mdax[3], :val) # remove values from metadata to prevent confusion when slicing up
    valy = mdax[2][:val]
    delete!(mdax[2], :val) # remove values from metadata to prevent confusion when slicing up
    valz = mdax[1][:val]
    delete!(mdax[1], :val) # remove values from metadata to prevent confusion when slicing up

    xaxis = F1Dim(valx; metadata=mdax[3])
    yaxis = F2Dim(valy; metadata=mdax[2])
    zaxis = F3Dim(valz; metadata=mdax[1])

    return NMRData(dat, (xaxis, yaxis, zaxis); metadata=md)
end

function untileucsf2d(dat, tx, ty, nx, ny)
    # determine the number of tiles in data 
    ntx = ceil(Int, nx / tx) # number of tiles in x dim
    nty = ceil(Int, ny / ty) # number of tiles in y dim

    tsize = tx * ty # number of points in one tile

    # create an empty array to store file data
    out = zeros(eltype(dat), ntx * tx, nty * ty)

    for iy in 1:nty
        for ix in 1:ntx
            minx = (ix - 1) * tx + 1
            maxx = ix * tx
            miny = (iy - 1) * ty + 1
            maxy = iy * ty
            ntile = (iy - 1) * ntx + ix
            mint = (ntile - 1) * tsize + 1
            maxt = ntile * tsize

            # fill in the tile data
            out[minx:maxx, miny:maxy] .= reshape(dat[mint:maxt], tx, ty)
        end
    end

    return out[1:nx, 1:ny]
end

function untileucsf3d(dat, tx, ty, tz, nx, ny, nz)
    # determine the number of tiles in data 
    ntx = ceil(Int, nx / tx) # number of tiles in x dim
    nty = ceil(Int, ny / ty) # number of tiles in y dim
    ntz = ceil(Int, nz / tz) # number of tiles in z dim

    tsize = tx * ty * tz # number of points in one tile

    # create an empty array to store file data
    out = zeros(eltype(dat), ntx * tx, nty * ty, ntz * tz)

    for iz in 1:ntz
        for iy in 1:nty
            for ix in 1:ntx
                minx = (ix - 1) * tx + 1
                maxx = ix * tx
                miny = (iy - 1) * ty + 1
                maxy = iy * ty
                minz = (iz - 1) * tz + 1
                maxz = iz * tz
                ntile = (iz - 1) * ntx * nty + (iy - 1) * ntx + ix
                mint = (ntile - 1) * tsize + 1
                maxt = ntile * tsize

                # fill in the tile data
                out[minx:maxx, miny:maxy, minz:maxz] .= reshape(dat[mint:maxt], tx, ty, tz)
            end
        end
    end

    return out[1:nx, 1:ny, 1:nz]
end```

-----------

Path: ./src/NMRIO/lists.jl

```julia
"""
    FQList(values, unit::Symbol, relative::Bool)

Represents a frequency list. `unit` can be `:Hz` or `:ppm`, and `relative`
indicates whether the frequency is given relative to SFO (true) or BF (false).

Raw values can be extracted using the `data` function, or (better) as absolute
chemical shifts (in ppm) or relative offsets (in Hz) using [`getppm`](@ref) and
[`getoffset`](@ref) functions.

See also: [`getppm`](@ref), [`getoffset`](@ref).
"""
struct FQList{T}
    values::Vector{T}
    unit::Symbol
    relative::Bool
end

data(f::FQList) = f.values

"""
    getppm(f::FQList, ax::FrequencyDimension)

Return frequency list values in ppm (in absolute terms, i.e. relative to 0 ppm).

See also: [`getoffset`](@ref)
"""
function getppm(f::FQList, ax::FrequencyDimension)
    if f.relative
        ppm0 = ax[:offsetppm]
    else
        ppm0 = 0
    end
    if f.unit == :ppm
        ppm = f.values
    else
        # convert Hz to ppm
        bf = ax[:bf]
        ppm = f.values ./ bf
    end
    return ppm .+ ppm0
end

"""
    getoffset(f::FQList, ax::FrequencyDimension)

Return frequency list values as offsets relative to the spectrometer frequency, in Hz.

See also: [`getppm`](@ref)
"""
function getoffset(f::FQList, ax::FrequencyDimension)
    if f.relative
        if f.unit == :ppm
            # ppm, relative
            return f.values * ax[:bf]
        else
            # Hz, relative
            return f.values
        end
    else
        if f.unit == :ppm
            # ppm, absolute
            return (f.values .- ax[:offsetppm]) * ax[:bf]
        else
            # Hz, absolute
            return f.values .- ax[:offsethz]
        end
    end
end```

-----------

Path: ./src/NMRTools.jl

```julia
module NMRTools

using PrecompileTools
using Reexport: Reexport

include("NMRBase/NMRBase.jl")
include("NMRIO/NMRIO.jl")

Reexport.@reexport using .NMRBase
Reexport.@reexport using .NMRIO

include("precompile.jl")

end
```

-----------

Path: ./src/NMRBase/windows.jl

```julia
"""
    WindowFunction

Abstract type to represent apodization functions.

Window functions are represented by subtypes of the abstract type `WindowFunction`,
each of which contain appropriate parameters to specify the particular function
applied. In addition, the acquisition time `tmax` is also stored (calculated at
the point the window function is applied, i.e. after linear prediction but before
zero filling).
"""
abstract type WindowFunction end

Base.Broadcast.broadcastable(w::WindowFunction) = Ref(w)

"""
    NullWindow(tmax)

No apodization applied. Acquisition time is `tmax`.
"""
struct NullWindow <: WindowFunction
    tmax::Float64
    NullWindow(tmax=Inf) = new(tmax)
end

"""
    UnknownWindow(tmax)

Unknown apodization applied. Acquisition time is `tmax`.
"""
struct UnknownWindow <: WindowFunction
    tmax::Float64
    UnknownWindow(tmax=Inf) = new(tmax)
end

"""
    ExponentialWindow(lb, tmax)

Exponential window function, with a line broadening of `lb` Hz. Acquisition time is `tmax`.
"""
struct ExponentialWindow <: WindowFunction
    lb::Float64
    tmax::Float64
    ExponentialWindow(lb=0.0, tmax=Inf) = new(lb, tmax)
end

"""
    SineWindow(offset, endpoint, power, tmax)

Abstract window function representing multiplication by sine/cosine functions.
Acquisition time is `tmax`.
```math
\\left[\\sin\\left(
    \\pi\\cdot\\mathrm{offset} +
    \\frac{\\left(\\mathrm{end} - \\mathrm{offset}\\right)\\pi t}{\\mathrm{tmax}}
    \\right)\\right]^\\mathrm{power}
```

Specialises to `CosWindow`, `Cos²Window` or `GeneralSineWindow`.

# Arguments
- `offset`: initial value is ``\\sin(\\mathrm{offset}\\cdot\\pi)`` (0 to 1)
- `endpoint`: initial value is ``\\sin(\\mathrm{endpoint}\\cdot\\pi)`` (0 to 1)
- `pow`: sine exponent
"""
abstract type SineWindow <: WindowFunction end

function SineWindow(offset=0.0, endpoint=1.0, power=1.0, tmax=Inf)
    if power ≈ 1.0 && offset ≈ 0.5
        return CosWindow(endpoint * tmax)
    elseif power ≈ 2.0 && offset ≈ 0.5
        return Cos²Window(endpoint * tmax)
    else
        return GeneralSineWindow(offset, endpoint, power, tmax)
    end
end

struct GeneralSineWindow <: SineWindow
    offset::Float64
    endpoint::Float64
    power::Float64
    tmax::Float64
end

"""
    CosWindow(tmax)

Apodization by a pure cosine function. Acquisition time is `tmax`.

See also [`Cos²Window`](@ref), [`SineWindow`](@ref).
"""
struct CosWindow <: SineWindow
    tmax::Float64
end

"""
    Cos²Window(tmax)

Apodization by a pure cosine squared function. Acquisition time is `tmax`.

See also [`CosWindow`](@ref), [`SineWindow`](@ref).
"""
struct Cos²Window <: SineWindow
    tmax::Float64
end

"""
    GaussWindow(expHz, gaussHz, center, tmax)

Abstract representation of Lorentz-to-Gauss window functions, applying an inverse
exponential of `expHz` Hz, and a gaussian broadening of `gaussHz` Hz, with maximum
at `center` (between 0 and 1). Acquisition time is `tmax`.

Specialises to `LorentzToGaussWindow` when `center` is zero, otherwise `GeneralGaussWindow`.
"""
abstract type GaussWindow <: WindowFunction end

function GaussWindow(expHz=0.0, gaussHz=0.0, center=0.0, tmax=Inf)
    if center ≈ 0.0
        return LorentzToGaussWindow(expHz, gaussHz, tmax)
    else
        return GeneralGaussWindow(expHz, gaussHz, center, tmax)
    end
end

struct GeneralGaussWindow <: GaussWindow
    expHz::Float64
    gaussHz::Float64
    center::Float64
    tmax::Float64
    function GeneralGaussWindow(expHz=0.0, gaussHz=0.0, center=0.0, tmax=Inf)
        return new(expHz, gaussHz, center, tmax)
    end
end

struct LorentzToGaussWindow <: GaussWindow
    expHz::Float64
    gaussHz::Float64
    tmax::Float64
    LorentzToGaussWindow(expHz=0.0, gaussHz=0.0, tmax=Inf) = new(expHz, gaussHz, tmax)
end

"""
    LineshapeComplexity

Abstract type to specify calculation of `RealLineshape` or `ComplexLineshape` in function calls.
"""
abstract type LineshapeComplexity end

"""
    RealLineshape

Return a real-valued lineshape when used in calculations
"""
struct RealLineshape <: LineshapeComplexity end

"""
    ComplexLineshape

Return a complex-valued lineshape when used in calculations
"""
struct ComplexLineshape <: LineshapeComplexity end

"""
    lineshape(axis, δ, R2, complexity=RealLineshape())

Return a simulated real- or complex-valued spectrum for a resonance with chemical
shift `δ` and relaxation rate `R2`, using the parameters and window function associated
with the specified axis.
"""
function lineshape(ax, δ, R2, complexity::LineshapeComplexity)
    return _lineshape(getω(ax, δ), R2, getω(ax), ax[:window], complexity)
end
# default to a real return type
lineshape(ax, δ, R2) = lineshape(ax, δ, R2, RealLineshape())

"""
    _lineshape(ω, R2, ωaxis, window, complexity)

Internal function to calculate a resonance lineshape with frequency `ω` and
relaxation rate `R2`, calculated at frequencies `ωaxis` and with apodization according
to the specified window function.
"""
function _lineshape end

function _lineshape(ω, R, ωax, ::WindowFunction, ::RealLineshape)
    # generic case - return a default real-valued Lorentzian
    @. R / ((ωax - ω)^2 + R^2)
end

function _lineshape(ω, R, ωax, ::WindowFunction, ::ComplexLineshape)
    # generic case - return a default (complex-valued) Lorentzian
    @. 1 / (R + 1im * (ω - ωax))
end

# exponential functions

function _lineshape(ω, R, ωax, w::ExponentialWindow, ::ComplexLineshape)
    x = @. R + 1im * (ω - ωax) + π * w.lb
    T = w.tmax

    return @. (1 - exp(-T * x)) / x
end

function _lineshape(ω, R, ωax, w::ExponentialWindow, ::RealLineshape)
    return real(_lineshape(ω, R, ωax, w, ComplexLineshape()))
end

# cosine

function _lineshape(ω, R, ωax, w::CosWindow, ::ComplexLineshape)
    x = @. R + 1im * (ω - ωax)
    T = w.tmax
    Tx = T * x
    return @. 2 * T * (π * exp(-Tx) + 2 * Tx) / (π^2 + 4 * Tx^2)
end

function _lineshape(ω, R, ωax, w::CosWindow, ::RealLineshape)
    return real(_lineshape(ω, R, ωax, w, ComplexLineshape()))
end

function _lineshape(ω, R, ωax, w::Cos²Window, ::ComplexLineshape)
    x = @. R + 1im * (ω - ωax)
    Tx = w.tmax * x

    return @. (π^2 * (1 - exp(-Tx)) + 2 * Tx^2) / (2 * (π^2 + Tx^2) * x)
end

function _lineshape(ω, R, ωax, w::Cos²Window, ::RealLineshape)
    return real(_lineshape(ω, R, ωax, w, ComplexLineshape()))
end

"""
    apod(spec::NMRData, dimension, zerofill=true)

Return the time-domain apodization function for the specified axis,
as a vector of values.
"""
function apod(spec::AbstractNMRData, dimension, zerofill=true)
    return apod(dims(spec, dimension), zerofill)
end

function apod(ax::FrequencyDimension, zerofill=true)
    td = ax[:td]
    sw = ax[:swhz]
    window = ax[:window]

    dt = 1 / sw
    t = dt * (0:(td - 1))

    if zerofill
        tdzf = ax[:tdzf]
        w = zeros(tdzf)
    else
        w = zeros(td)
    end
    w[1:td] = apod(t, window)

    return w
end

# function apod(t, w::WindowFunction)
#     @warn "time-domain apodization function not yet defined for window $w - treating as no apodization"
#     ones(length(t))
# end

apod(t, ::NullWindow) = ones(length(t))
apod(t, w::ExponentialWindow) = exp.(-π * w.lb * t)
function apod(t, w::GeneralSineWindow)
    @. sin(π * w.offset + π * ((w.endpoint - w.offset) * t / w.tmax))^w.power
end
apod(t, w::CosWindow) = @. cos(π / 2 * t / w.tmax)
apod(t, w::Cos²Window) = @. cos(π / 2 * t / w.tmax)^2
```

-----------

Path: ./src/NMRBase/isotopedata.jl

```julia
"""
    spin(n::Nucleus)

Return the spin quantum number of nucleus `n`, or `nothing` if not defined.

# Examples
```jldoctest
julia> spin(H1)
1//2
```

See also [`Coherence`](@ref).
"""
function spin(n::Nucleus)
    dic = Dict(H1 => 1 // 2,
               H2 => 1,
               C12 => 0,
               C13 => 1 // 2,
               N14 => 1,
               N15 => 1 // 2,
               F19 => 1 // 2,
               P31 => 1 // 2)
    return get(dic, n, nothing)
end

"""
    gyromagneticratio(n::Nucleus)
    gyromagneticratio(c::Coherence)

Return the gyromagnetic ratio in Hz/T of a nucleus, or calculate the effective gyromagnetic
ratio of a coherence. This is equal to the product of the individual gyromagnetic ratios
with their coherence orders.

Returns `nothing` if not defined.

# Examples
```jldoctest
julia> gyromagneticratio(H1)
2.6752218744e8

julia> gyromagneticratio(SQ(H1))
2.6752218744e8

julia> gyromagneticratio(MQ(((H1,1),(C13,1))))
3.3480498744e8

julia> gyromagneticratio(MQ(((H1,0),)))
0.0
```

See also [`Nucleus`](@ref), [`Coherence`](@ref).
"""
function gyromagneticratio end

function gyromagneticratio(n::Nucleus)
    dic = Dict(H1 => 267.52218744e6,
               H2 => 41.065e6,
               C13 => 67.2828e6,
               N14 => 19.331e6,
               N15 => -27.116e6,
               F19 => 251.815e6,
               P31 => 108.291e6)
    return get(dic, n, nothing)
end

gyromagneticratio(c::SQ) = gyromagneticratio(c.nucleus)
function gyromagneticratio(c::MQ)
    return sum([gyromagneticratio(t[1]) * t[2] for t in c.coherences])
end
```

-----------

Path: ./src/NMRBase/nuclei.jl

```julia
"""
    Nucleus

Enumeration of common nuclei associated with biomolecular NMR. Nuclei are named e.g. `H1`, `C13`.

Defined nuclei: `H1`, `H2`, `C12`, `C13`, `N14`, `N15`, `F19`, `P31`.

See also [`spin`](@ref), [`gyromagneticratio`](@ref), [`Coherence`](@ref).
"""
@enum Nucleus begin
    H1
    H2
    C12
    C13
    N14
    N15
    F19
    P31
end
```

-----------

Path: ./src/NMRBase/exceptions.jl

```julia
"""
    NMRToolsError(message)

An error arising in NMRTools.
"""
struct NMRToolsError <: Exception
    message::String
end
```

-----------

Path: ./src/NMRBase/nmrdata.jl

```julia
"""
    AbstractNMRData <: DimensionalData.AbstractDimArray

Abstract supertype for objects that wrap an array of NMR data, and metadata about
its contents.

`AbstractNMRData`s inherit from [`AbstractDimArray`]($DDarraydocs)
from DimensionalData.jl. They can be indexed as regular Julia arrays or with
DimensionalData.jl [`Dimension`]($DDdimdocs)s.
"""
abstract type AbstractNMRData{T,N,D,A} <: AbstractDimArray{T,N,D,A} end

# Base methods #####################################################################################

function Base.:(==)(A::AbstractNMRData{T,N}, B::AbstractNMRData{T,N}) where {T,N}
    return size(A) == size(B) && all(A .== B)
end

Base.parent(A::AbstractNMRData) = A.data
# NOTE In the future, specialise for file-based data (see Rasters.jl/array.jl)
Base.Array(A::AbstractNMRData) = Array(parent(A))
Base.collect(A::AbstractNMRData) = collect(parent(A))
# TODO define similar() to inherit metadata appropriately

# Interface methods ################################################################################

"""
    missingval(x)

Returns the value representing missing data in the dataset.
"""
function missingval end
missingval(x) = missing
missingval(A::AbstractNMRData) = A.missingval

# DimensionalData methods ##########################################################################

# Rebuild types of AbstractNMRData
function DD.rebuild(X::A, data, dims::Tuple, refdims, name,
                    metadata=metadata(X),
                    missingval=missingval(X)) where {A<:AbstractNMRData}
    # HACK use A.name.wrapper to return the type (i.e. constructor) stripped of parameters.
    # This may not be a stable feature. See discussions:
    # - https://discourse.julialang.org/t/get-generic-constructor-of-parametric-type/57189/5
    # - https://github.com/JuliaObjects/ConstructionBase.jl/blob/master/src/constructorof.md
    return (A.name.wrapper)(data, dims, refdims, name, metadata, missingval)
end

function DD.rebuild(A::AbstractNMRData;
                    data=parent(A), dims=dims(A), refdims=refdims(A), name=name(A),
                    metadata=metadata(A), missingval=missingval(A))
    return rebuild(A, data, dims, refdims, name, metadata, missingval)
end

# NOTE In the future, specialise for file-based data (see Rasters.jl/array.jl)
function DD.modify(f, A::AbstractNMRData)
    newdata = f(parent(A))
    size(newdata) == size(A) ||
        error("$f returns an array with size $(size(newdata)) when the original size was $(size(A))")
    return rebuild(A, newdata)
end

# function DD.DimTable(As::Tuple{<:AbstractNMRData,Vararg{<:AbstractNMRData}}...)
#     return DD.DimTable(DimStack(map(read, As...)))
# end

# Concrete implementation ##########################################################################

"""
    NMRData <: AbstractNMRData
    NMRData(A::AbstractArray{T,N}, dims; kw...)
    NMRData(A::AbstractNMRData; kw...)

A generic [`AbstractNMRData`](@ref) for NMR array data. It holds memory-backed arrays.

# Keywords

- `dims`: `Tuple` of `NMRDimension`s for the array.
- `name`: `Symbol` name for the array, which will also retreive named layers if `NMRData`
    is used on a multi-layered file like a NetCDF.
- `missingval`: value representing missing data, normally detected from the file. Set manually
    when you know the value is not specified or is incorrect. This will *not* change any
    values in the NMRData, it simply assigns which value is treated as missing.

# Internal Keywords

In some cases it is possible to set these keywords as well.

- `data`: can replace the data in an `AbstractNMRData`

- `refdims`: `Tuple of` position `Dimension`s the array was sliced from, defaulting to `()`.
"""
struct NMRData{T,N,D<:Tuple,R<:Tuple,A<:AbstractArray{T,N},Na,Me,Mi} <:
       AbstractNMRData{T,N,D,A}
    data::A
    dims::D
    refdims::R
    name::Na
    metadata::Me
    missingval::Mi
end

function NMRData(A::AbstractArray, dims::Tuple;
                 refdims=(), name=Symbol(""), metadata=defaultmetadata(NMRData),
                 missingval=missing)
    return NMRData(A, Dimensions.format(dims, A), refdims, name, metadata, missingval)
end

function NMRData(A::AbstractArray{<:Any,1}, dims::Tuple{<:Dimension,<:Dimension,Vararg};
                 kw...)
    return NMRData(reshape(A, map(length, dims)), dims; kw...)
end

# function NMRData(table, dims::Tuple; name=first(_not_a_dimcol(table, dims)), kw...)
#     Tables.istable(table) ||
#         throw(ArgumentError("First argument to `NMRData` is not a table or other known object: $table"))
#     isnothing(name) && throw(UndefKeywordError(:name))
#     cols = Tables.columns(table)
#     A = reshape(cols[name], map(length, dims))
#     return NMRData(A, dims; name, kw...)
# end

NMRData(A::AbstractArray; dims, kw...) = NMRData(A, dims; kw...)

function NMRData(A::AbstractDimArray;
                 data=parent(A), dims=dims(A), refdims=refdims(A),
                 name=name(A), metadata=metadata(A), missingval=missingval(A), kw...)
    return NMRData(data, dims; refdims, name, metadata, missingval, kw...)
end

# function NMRData(filename::AbstractString, dims::Tuple{<:Dimension,<:Dimension,Vararg};
#                  kw...)
#     return NMRData(filename; dims, kw...)
# end

# TODO ??
# DD.dimconstructor(::Tuple{<:Dimension{<:AbstractProjected},Vararg{<:Dimension}}) = NMRData

# Getters ##########################################################################################
"""
    data(nmrdata)

Return the numerical data associated with the specified NMRData.
"""
data(A::NMRData) = A.data

"""
    data(nmrdata, dim)

Return the numerical data associated with the specified dimension.
"""
data(A::NMRData, dim) = data(dims(A, dim))

# Methods ##########################################################################################
"""
    scale(d::AbstractNMRData)

Return a scaling factor for the data combining the number of scans, receiver gain, and, if
specified, the sample concentration.
```math
\\mathrm{scale} = \\mathrm{ns} \\cdot \\mathrm{rg} \\cdot \\mathrm{conc}
```
"""
function scale(d::AbstractNMRData)
    # get ns, rg, and concentration, with safe defaults in case missing
    ns = get(metadata(d), :ns, 1)
    rg = get(metadata(d), :rg, 1)
    conc = get(metadata(d), :conc, 1)
    return ns * rg * conc
end

# Set pseudo-dimension data

"""
    setkinetictimes(A::NMRData, [dimnumber], tvals, units="")

Return a new NMRData with a kinetic time axis containing the passed values (and optionally, units).
If a dimension number is specified, that dimension will be replaced with a `TkinDim`. If not, the
function will search for a unique non-frequency dimension, and replace that. If there are multiple
non-frequency dimensions, the dimension number must be specified explicitly, and the function will throw
an error.
"""
function setkinetictimes() end

function setkinetictimes(A::NMRData, tvals::AbstractVector, units="")
    hasnonfrequencydimension(A) ||
        throw(NMRToolsError("cannot set time values: data does not have a non-frequency dimension"))

    nonfreqdims = isa.(dims(A), NonFrequencyDimension)
    sum(nonfreqdims) == 1 ||
        throw(NMRToolsError("multiple non-frequency dimensions are present - ambiguous command"))

    olddimnumber = findfirst(nonfreqdims)

    return setkinetictimes(A::NMRData, olddimnumber, tvals, units)
end

function setkinetictimes(A::NMRData, dimnumber::Integer, tvals::AbstractVector, units="")
    newdim = TkinDim(tvals)
    newA = replacedimension(A::NMRData, dimnumber, newdim)

    label!(newA, newdim, "Time elapsed")
    newA[newdim, :units] = units

    return newA
end

"""
    setrelaxtimes(A::NMRData, [dimnumber], tvals, units="")

Return a new NMRData with a relaxation time axis containing the passed values (and optionally, units).
If a dimension number is specified, that dimension will be replaced with a `TrelaxDim`. If not, the
function will search for a unique non-frequency dimension, and replace that. If there are multiple
non-frequency dimensions, the dimension number must be specified explicitly, and the function will throw
an error.
"""
function setrelaxtimes() end

function setrelaxtimes(A::NMRData, tvals::AbstractVector, units="")
    hasnonfrequencydimension(A) ||
        throw(NMRToolsError("cannot set time values: data does not have a non-frequency dimension"))

    nonfreqdims = isa.(dims(A), NonFrequencyDimension)
    sum(nonfreqdims) == 1 ||
        throw(NMRToolsError("multiple non-frequency dimensions are present - ambiguous command"))

    olddimnumber = findfirst(nonfreqdims)

    return setrelaxtimes(A::NMRData, olddimnumber, tvals, units)
end

function setrelaxtimes(A::NMRData, dimnumber::Integer, tvals::AbstractVector, units="")
    newdim = TrelaxDim(tvals)
    newA = replacedimension(A::NMRData, dimnumber, newdim)

    label!(newA, newdim, "Relaxation time")
    newA[newdim, :units] = units

    return newA
end

"""
    setgradientlist(A::NMRData, [dimnumber], relativegradientlist, Gmax=nothing)

Return a new NMRData with a gradient axis containing the passed values. If no maximum strength is specified,
a default gradient strength of 0.55 T m⁻¹ will be set, but a warning raised for the user.

If a dimension number is specified, that dimension will be replaced. If not, the function will search for
a unique non-frequency dimension, and replace that. If there are multiple non-frequency dimensions, the
dimension number must be specified explicitly, and the function will throw an error.
"""
function setgradientlist() end

function setgradientlist(A::NMRData, dimnumber::Integer,
                         relativegradientlist::AbstractVector, Gmax=nothing)
    if isnothing(Gmax)
        @warn("a maximum gradient strength of 0.55 T m⁻¹ is being assumed - this is roughly correct for modern Bruker systems but calibration is recommended")
        gvals = 0.55 * relativegradientlist
    else
        gvals = Gmax * relativegradientlist
    end

    if dimnumber == 1
        newdim = G1Dim(gvals)
    elseif dimnumber == 2
        newdim = G2Dim(gvals)
    elseif dimnumber == 3
        newdim = G3Dim(gvals)
    end
    newA = replacedimension(A::NMRData, dimnumber, newdim)

    label!(newA, newdim, "Gradient strength")
    newA[newdim, :units] = "T m⁻¹"

    return newA
end

function setgradientlist(A::NMRData, relativegradientlist::AbstractVector, Gmax=nothing)
    hasnonfrequencydimension(A) ||
        throw(NMRToolsError("cannot set gradient values: data does not have a non-frequency dimension"))

    unknowndims = isa.(dims(A), UnknownDimension)
    sum(unknowndims) == 1 ||
        throw(NMRToolsError("multiple unknown dimensions are present - ambiguous command"))

    olddimnumber = findfirst(unknowndims)

    return setgradientlist(A, olddimnumber, relativegradientlist, Gmax)
end

"""
    replacedimension(nmrdata, olddimnumber, newdim)

Return a new NMRData, in which the numbered axis is replaced by a new `Dimension`.
"""
function replacedimension(A::NMRData, olddimnumber, newdim)
    olddim = dims(A, olddimnumber)
    length(olddim) == length(newdim) ||
        throw(NMRToolsError("size of old and new dimensions are not compatible"))
    merge!(metadata(newdim).val, metadata(olddim).val)

    olddims = Vector{NMRDimension}([dims(A)...])
    olddims[olddimnumber] = newdim
    newdims = tuple(olddims...)

    return NMRData(A.data, newdims; name=A.name, refdims=A.refdims, metadata=A.metadata)
end

"""
    decimate(data, n dims=1)

Decimate NMR data into n-point averages along the specified dimension.
Note that data are *averaged* and not *summed*. Noise metadata is not updated.
"""
function decimate(expt::NMRData, n, dims=1)
    np = size(expt, dims) ÷ n
    out = selectdim(expt, dims, 1:n:(np * n)) # preallocate decimated NMRData

    sz = [size(out)...]
    insert!(sz, dims, n)

    y = selectdim(data(expt), dims, 1:(np * n))
    y = reshape(y, sz...)
    y = reduce(+, y; dims=dims) / n

    outsz = [size(out)...]
    outsz[dims] = np
    data(out) .= reshape(y, outsz...)

    return out
end

function decimate(signal, n, dims=1)
    np = size(signal, dims) ÷ n
    y = selectdim(signal, dims, 1:(np * n))

    sz = [size(signal)...]
    sz[dims] = np
    insert!(sz, dims, n)

    y = reshape(y, sz...)
    y = sum(y; dims=dims) / n

    outsz = [size(signal)...]
    outsz[dims] = np
    return reshape(y, outsz...)
end

"""
    stack(expts::Vector{NMRData})

Combine a collection of equally-sized NMRData into one larger array, by arranging them
along a new dimension, of type `UnknownDimension`.

Throws a `DimensionMismatch` if data are not of compatible shapes.
"""
function Base.stack(expts::Vector{D}) where {D<:AbstractNMRData{T,N}} where {T,N}
    # construct new data
    newdata = stack(data, expts)

    # construct new dimensions
    n = length(expts)
    if N == 1
        newdim = X2Dim(1:n)
    elseif N == 2
        newdim = X3Dim(1:n)
    elseif N == 3
        newdim = X4Dim(1:n)
    end
    newdims = [dims(expts[1])..., newdim]
    # push!(newdims, newdim)
    newdims = tuple(newdims...)

    # check and warn if dimensions don't match
    allequal(map(dims, expts)) || warn("stack: dimensions of expts 1 and $i are not equal")

    # construct new metadata, based on metadata for first spectrum
    newmd = deepcopy(metadata(first(expts)))
    newmd[:ndim] = N + 1

    # check and warn if ns don't match between experiments
    ns = map(e -> e[:ns], expts)
    allequal(ns) || @warn "stack: experiments do not have same ns" ns
    rg = map(e -> e[:rg], expts)
    allequal(rg) || @warn "stack: experiments do not have same rg" rg

    return NMRData(newdata, newdims; metadata=newmd)
end

# Arithmetic #######################################################################################

# BUG - it would be nice to propagate the noise, but at the moment metadata is shallow-copied during
# arithmetic operations so the operation changes the original input values as well.

# function Base.:+(a::NMRData, b::NMRData)
#     c = invoke(+, Tuple{DimensionalData.AbstractDimArray, DimensionalData.AbstractDimArray}, a, b)
#     c = NMRData(c.data, dims(c), name=c.name, refdims=c.refdims, metadata=copy(metadata(c)))
#     delete!(metadata(c), :noise) # delete old entry
#     c[:noise] = sqrt(get(metadata(a), :noise, 0)^2 + get(metadata(b), :noise, 0)^2)
#     return c
# end

# function Base.:-(a::NMRData, b::NMRData)
#     c = invoke(-, Tuple{DimensionalData.AbstractDimArray, DimensionalData.AbstractDimArray}, a, b)
#     c = NMRData(c.data, dims(c), name=c.name, refdims=c.refdims, metadata=copy(metadata(c)))
#     delete!(metadata(c), :noise) # delete old entry
#     c[:noise] = sqrt(get(metadata(a), :noise, 0)^2 + get(metadata(b), :noise, 0)^2)
#     return c
# end

# function Base.:*(a::Number, b::NMRData)
#     c = invoke(*, Tuple{Number, DimensionalData.AbstractDimArray}, a, b)
#     c = NMRData(c.data, dims(c), name=c.name, refdims=c.refdims, metadata=copy(metadata(c)))
#     delete!(metadata(c), :noise) # delete old entry
#     c[:noise] = a * get(metadata(b), :noise, 0)
#     return c
# end

# function Base.:/(a::NMRData, b::Number)
#     c = invoke(/, Tuple{DimensionalData.AbstractDimArray, Number}, a, b)
#     c = NMRData(c.data, dims(c), name=c.name, refdims=c.refdims, metadata=copy(metadata(c)))
#     delete!(metadata(c), :noise) # delete old entry
#     c[:noise] = get(metadata(a), :noise, 0) / b
#     return c
# end

# Traits ###########################################################################################
"""
    @traitdef HasNonFrequencyDimension{D}

A trait indicating whether the data object has a non-frequency domain dimension.

# Example

```julia
@traitfn f(x::X) where {X; HasNonFrequencyDimension{X}} = "This spectrum has a non-frequency domain dimension!"
@traitfn f(x::X) where {X; Not{HasNonFrequencyDimension{X}}} = "This is a pure frequency-domain spectrum!"
```
"""
@traitdef HasNonFrequencyDimension{D}

# adapted from expansion of @traitimpl
# this is a pure function because it only depends on the type definition of NMRData
Base.@pure function SimpleTraits.trait(t::Type{HasNonFrequencyDimension{D}}) where {D<:NMRData{T,
                                                                                               N,
                                                                                               A}} where {T,
                                                                                                          N,
                                                                                                          A}
    if any(map(dim -> (typeintersect(dim, FrequencyDimension) == Union{}), A.parameters))
        HasNonFrequencyDimension{D}
    else
        Not{HasNonFrequencyDimension{D}}
    end
end

"""
    hasnonfrequencydimension(spectrum)

Return true if the spectrum contains a non-frequency domain dimension.

# Example

```julia
julia> y2=loadnmr("exampledata/2D_HN/test.ft2");
julia> hasnonfrequencydimension(y2)
false
julia> y3=loadnmr("exampledata/pseudo3D_HN_R2/ft/test%03d.ft2");
julia> hasnonfrequencydimension(y3)
true
```
"""
function hasnonfrequencydimension(spectrum::NMRData{T,N,A}) where {T,N,A}
    return any(map(dim -> (typeintersect(dim, FrequencyDimension) == Union{}),
                   A.parameters))
end```

-----------

Path: ./src/NMRBase/noise.jl

```julia
"""
    estimatenoise!(nmrdata)

Estimate the rms noise level in the data and update `:noise` metadata.

If called on an `Array` of data, each item will be updated.

# Algorithm
Data are sorted into numerical order, and the highest and lowest 12.5% of data are discarded
(so that 75% of the data remain). These values are then fitted to a truncated gaussian
distribution via maximum likelihood analysis.

The log-likelihood function is:
```math
\\log L(\\mu, \\sigma) = \\sum_i{\\log P(y_i, \\mu, \\sigma)}
```

where the likelihood of an individual data point is:
```math
\\log P(y,\\mu,\\sigma) =
    \\log\\frac{
        \\phi\\left(\\frac{x-\\mu}{\\sigma}\\right)
    }{
        \\sigma \\cdot \\left[\\Phi\\left(\\frac{b-\\mu}{\\sigma}\\right) -
            \\Phi\\left(\\frac{a-\\mu}{\\sigma}\\right)\\right]}
```

and ``\\phi(x)`` and ``\\Phi(x)`` are the standard normal pdf and cdf functions.
"""
function estimatenoise!(d::NMRData)
    α = 0.25 # fraction of data to discard for noise estimation

    nsamples = 1000
    n0 = length(d)
    step = Int(ceil(n0 / nsamples))

    if isreal(data(d))
        vd = vec(data(d))
    else
        # TODO consider multicomplex
        @warn "estimatenoise! doesn't handle multicomplex numbers correctly. Working with real values only."
        vd = vec(real(data(d)))
    end
    y = sort(vd[1:step:end])
    n = length(y)

    # select central subset of points
    i1 = ceil(Int, (α / 2) * n)
    i2 = floor(Int, (1 - α / 2) * n)
    y = y[i1:i2]

    μ0 = mean(y)
    σ0 = std(y)
    a = y[1]
    b = y[end]
    #histogram(y)|>display

    # MLE of truncated normal distribution
    𝜙(x) = (1 / sqrt(2π)) * exp.(-0.5 * x .^ 2)
    𝛷(x) = 0.5 * erfc.(-x / sqrt(2))
    logP(x, μ, σ) = @. log(𝜙((x - μ) / σ) / (σ * (𝛷((b - μ) / σ) - 𝛷((a - μ) / σ))))
    ℒ(p) = -sum(logP(y, p...))

    p0 = [μ0, σ0]
    res = optimize(ℒ, p0)
    p = Optim.minimizer(res)
    return d[:noise] = abs(p[2])
end

estimatenoise!(spectra::Array{<:NMRData}) = map(estimatenoise!, spectra)
```

-----------

Path: ./src/NMRBase/NMRBase.jl

```julia
module NMRBase

const EXPERIMENTAL = """
    WARNING: This feature is experimental. It may change in future versions, and may
    not be 100% reliable in all cases. Please file github issues if problems occur.
    """

# DimensionalData documentation urls
const DDdocs = "https://rafaqz.github.io/DimensionalData.jl/stable/api"
const DDdimdocs = joinpath(DDdocs, "#DimensionalData.Dimension")
const DDarraydocs = joinpath(DDdocs, "#DimensionalData.AbstractDimensionalArray")
# const DDabssampleddocs = joinpath(DDdocs, "#DimensionalData.AbstractSampled")
# const DDsampleddocs = joinpath(DDdocs, "#DimensionalData.Sampled")
# const DDlocusdocs = joinpath(DDdocs, "#DimensionalData.Locus")
# const DDselectordocs = joinpath(DDdocs, "#DimensionalData.Selector")
# const DDtidocs = joinpath(DDdocs, "#DimensionalData.Ti")

using LinearAlgebra
using SimpleTraits
using Optim
using Statistics
using SpecialFunctions

# using Reexport: Reexport
# Reexport.@reexport using DimensionalData
using DimensionalData
using DimensionalData.LookupArrays,
      DimensionalData.Dimensions
const DD = DimensionalData

# using DimensionalData: Name, NoName
# using .Dimensions: StandardIndices, DimTuple, Dimension
# using .LookupArrays: LookupArrayTuple

import DimensionalData.refdims_title
import .LookupArrays: metadata, set, _set, rebuild, basetypeof, Metadata,
                      order, span, sampling, locus, val, index, bounds, hasselection, units,
                      SelectorOrInterval,
                      ForwardOrdered
import .Dimensions: dims, refdims, lookup, dimstride, kwdims, hasdim, label, _astuple

include("exceptions.jl")
include("nuclei.jl")
include("coherences.jl")
include("isotopedata.jl")
include("dimensions.jl")
include("nmrdata.jl")
include("windows.jl")
include("metadata.jl")
include("noise.jl")
include("pcls.jl")

macro exportinstances(enum)
    eval = GlobalRef(Core, :eval)
    return :($eval($__module__, Expr(:export, map(Symbol, instances($enum))...)))
end

# Exceptions
export NMRToolsError

# Nuclei
export Nucleus
@exportinstances Nucleus
export spin
export gyromagneticratio

# coherences
export Coherence
export SQ, MQ
export coherenceorder

# NMRData
export AbstractNMRData
export NMRData
# Selectors
export Selector, IntSelector, ArraySelector
export At, Between, Touches, Contains, Near, Where, All, ..
# getter methods
export data, parent, dims, refdims, lookup, bounds, missingval
# traits
export hasnonfrequencydimension, HasNonFrequencyDimension
# Dimension/Lookup primitives
export dimnum, hasdim, hasselection, otherdims
# utils
export refdims_title
export set, rebuild, reorder, modify, broadcast_dims, broadcast_dims!, ForwardOrdered
# NMR properties
export scale
export estimatenoise!
export decimate

# Dimensions
export NMRDimension
export FrequencyDimension
export NonFrequencyDimension
export TimeDimension
export GradientDimension
export UnknownDimension
export F1Dim, F2Dim, F3Dim, F4Dim
export T1Dim, T2Dim, T3Dim, T4Dim
export TrelaxDim, TkinDim
export G1Dim, G2Dim, G3Dim, G4Dim
export X1Dim, X2Dim, X3Dim, X4Dim
# export GradientDim
# export SpatialDim
export getω
export replacedimension
export setkinetictimes
export setrelaxtimes
export setgradientlist

# Metadata
export AbstractMetadata, Metadata, NoMetadata
export metadata
export defaultmetadata
export metadatahelp
export label, label!, units
export acqus

# Window functions
export WindowFunction
export NullWindow
export UnknownWindow
export ExponentialWindow
export SineWindow
export GeneralSineWindow, CosWindow, Cos²Window
export GaussWindow
export GeneralGaussWindow, LorentzToGaussWindow
export lineshape
export apod

export LineshapeComplexity
export RealLineshape
export ComplexLineshape

# phase-constrained least squares
export pcls

end
```

-----------

Path: ./src/NMRBase/coherences.jl

```julia
"""
    Coherence

Abstract supertype for representing coherences.

See also [`SQ`](@ref), [`MQ`](@ref).
"""
abstract type Coherence end

"""
    SQ(nucleus::Nucleus, label=="")

Representation of a single quantum coherence on a given nucleus.

See also [`Nucleus`](@ref), [`MQ`](@ref).
"""
struct SQ <: Coherence
    nucleus::Nucleus
    label::String
    SQ(nuc, label="") = new(nuc, label)
end

"""
    MQ(coherences, label=="")

Representation of a multiple-quantum coherence. Coherences are specified as a tuple of tuples,
of the form `(nucleus, coherenceorder)`

# Examples
```jldoctest
julia> MQ(((H1,1), (C13,-1)), "ZQ")
MQ(((H1, 1), (C13, -1)), "ZQ")

julia> MQ(((H1,3), (C13,1)), "QQ")
MQ(((H1, 3), (C13, 1)), "QQ")
```

See also [`Nucleus`](@ref), [`SQ`](@ref).
"""
struct MQ <: Coherence
    coherences::Tuple{Vararg{Tuple{Nucleus,Int}}}
    label::String
    MQ(coherences, label="") = new(coherences, label)
end

"""
    coherenceorder(coherence)

Calculate the total coherence order.

# Examples
```jldoctest
julia> coherenceorder(SQ(H1))
1

julia> coherenceorder(MQ(((H1,1),(C13,1))))
2

julia> coherenceorder(MQ(((H1,1),(C13,-1))))
0

julia> coherenceorder(MQ(((H1,3),(C13,1))))
4

julia> coherenceorder(MQ(((H1,0),)))
0
```
See also [`Nucleus`](@ref), [`SQ`](@ref), [`MQ`](@ref).
"""
function coherenceorder end

coherenceorder(c::SQ) = 1
function coherenceorder(c::MQ)
    return sum([t[2] for t in c.coherences])
end
```

-----------

Path: ./src/NMRBase/dimensions.jl

```julia
"""
    NMRDimension

Abstract supertype for all axes used in NMRData objects.

See also [`FrequencyDimension`](@ref) and [`NonFrequencyDimension`](@ref).
"""
abstract type NMRDimension{T} <: DimensionalData.Dimension{T} end

"""
    FrequencyDimension <: NMRDimension

Abstract supertype for frequency dimensions used in NMRData objects.
Concrete types `F1Dim`, `F2Dim`, `F3Dim` and `F4Dim` are generated for
use in creating objects.

See also [`NonFrequencyDimension`](@ref).
"""
abstract type FrequencyDimension{T} <: NMRDimension{T} end

"""
    NonFrequencyDimension <: NMRDimension

Abstract supertype for non-frequency dimensions used in NMRData objects.
Sub-types include [`TimeDimension`](@ref), [`GradientDimension`](@ref), 
and [`UnknownDimension`](@ref).

See also [`FrequencyDimension`](@ref).
"""
abstract type NonFrequencyDimension{T} <: NMRDimension{T} end

"""
    TimeDimension <: NonFrequencyDimension <: NMRDimension

Abstract supertype for time dimensions used in NMRData objects.
Concrete types `T1Dim`, `T2Dim`, `T3Dim` and `T4Dim` are generated for
time-domains representing frequency evolution, and `TrelaxDim` and
`TkinDim` are generated for representing relaxation and real-time
kinetics.
"""
abstract type TimeDimension{T} <: NonFrequencyDimension{T} end
# abstract type QuadratureDimension{T} <: NMRDimension{T} end

"""
    UnknownDimension <: NonFrequencyDimension <: NMRDimension

Abstract supertype for unknown, non-frequency dimensions used in NMRData objects.
Concrete types `X1Dim`, `X2Dim`, `X3Dim` and `X4Dim` are generated for
use in creating objects.
"""
abstract type UnknownDimension{T} <: NonFrequencyDimension{T} end

"""
    GradientDimension <: NonFrequencyDimension <: NMRDimension

Abstract supertype for gradient-encoded dimensions used in NMRData objects.
Concrete types `G1Dim`, `G2Dim`, `G3Dim` and `G4Dim` are generated for
use in creating objects.
"""
abstract type GradientDimension{T} <: NonFrequencyDimension{T} end

# override DimensionalData.Dimensions macro to generate default metadata
macro NMRdim(typ::Symbol, supertyp::Symbol, args...)
    return NMRdimmacro(typ, supertyp, args...)
end
function NMRdimmacro(typ, supertype, name::String=string(typ))
    esc(quote
            Base.@__doc__ struct $typ{T} <: $supertype{T}
                val::T
            end
            function $typ(val::AbstractArray; kw...)
                v = values(kw)
                # e.g. values(kw) = (metadata = NoMetadata(),)
                if :metadata ∉ keys(kw)
                    # if no metadata defined, define it
                    # alternatively, if there is valid metadata, merge in the defaults
                    @debug "Creating default dimension metadata"
                    v = merge((metadata=defaultmetadata($typ),), v)
                elseif v[:metadata] isa Metadata{$typ}
                    @debug "Merging dimension metadata with defaults"
                    v2 = merge(v, (metadata=defaultmetadata($typ),))
                    merge!(v2[:metadata].val, v[:metadata].val)
                    v = v2
                elseif v[:metadata] isa Dict
                    @debug "Merging metadata dictionary with defaults"
                    md = v[:metadata]
                    v = merge(v, (metadata=defaultmetadata($typ),))
                    merge!(v[:metadata].val, md)
                else
                    # if NoMetadata (or an invalid type), define the correct default metadata
                    @debug "Dimension metadata is NoMetadata - replace with defaults"
                    v = merge(v, (metadata=defaultmetadata($typ),))
                end
                val = AutoLookup(val, v)
                return $typ{typeof(val)}(val)
                # @show tmpdim = $typ{typeof(val)}(val)
                # @show newlookup = DimensionalData.Dimensions._format(tmpdim, axes(tmpdim,1))
                # return $typ{typeof(newlookup)}(newlookup)
            end
            function $typ(val::T) where {T<:DimensionalData.Dimensions.LookupArrays.LookupArray}
                # HACK - this would better be replaced with a call to DD.format in the function above
                # e.g.
                # DimensionalData.Dimensions.format(DimensionalData.LookupArrays.val(axH), DimensionalData.LookupArrays.basetypeof(axH), Base.OneTo(11))
                return $typ{T}(val)
            end
            $typ() = $typ(:)
            Dimensions.name(::Type{<:$typ}) = $(QuoteNode(Symbol(name)))
            Dimensions.key2dim(::Val{$(QuoteNode(typ))}) = $typ()
        end)
end

@NMRdim F1Dim FrequencyDimension
@NMRdim F2Dim FrequencyDimension
@NMRdim F3Dim FrequencyDimension
@NMRdim F4Dim FrequencyDimension
@NMRdim T1Dim TimeDimension
@NMRdim T2Dim TimeDimension
@NMRdim T3Dim TimeDimension
@NMRdim T4Dim TimeDimension
@NMRdim TrelaxDim TimeDimension
@NMRdim TkinDim TimeDimension
# @NMRdim Q1Dim QuadratureDimension
# @NMRdim Q2Dim QuadratureDimension
# @NMRdim Q3Dim QuadratureDimension
# @NMRdim Q4Dim QuadratureDimension
@NMRdim X1Dim UnknownDimension
@NMRdim X2Dim UnknownDimension
@NMRdim X3Dim UnknownDimension
@NMRdim X4Dim UnknownDimension
@NMRdim G1Dim GradientDimension
@NMRdim G2Dim GradientDimension
@NMRdim G3Dim GradientDimension
@NMRdim G4Dim GradientDimension
# @NMRdim SpatialDim NMRDimension

# Getters ########
"""
    data(nmrdimension)

Return the numerical data associated with an NMR dimension.
"""
data(d::NMRDimension) = d.val.data

"""
    getω(axis)

Return the offsets (in rad/s) for points along a frequency axis.
"""
getω(ax::FrequencyDimension) = 2π * ax[:bf] * (data(ax) .- ax[:offsetppm])

"""
    getω(axis, δ)

Return the offset (in rad/s) for a chemical shift (or list of shifts) on a frequency axis.
"""
getω(ax::FrequencyDimension, δ) = 2π * ax[:bf] * (δ .- ax[:offsetppm])
```

-----------

Path: ./src/NMRBase/metadata.jl

```julia
# default constructor: dictionary of Symbol => Any #################################################

# struct NMRMetadata <: DimensionalData.Dimensions.LookupArrays.AbstractMetadata
# Metadata() = Metadata(Dict{Symbol,Any}())

# getters ##########################################################################################

# metadata accessor functions
"""
    metadata(nmrdata, key)
    metadata(nmrdata, dim, key)
    metadata(nmrdimension, key)

Return the metadata for specified key, or `nothing` if not found. Keys are passed as symbols.

# Examples (spectrum metadata)
- `:ns`: number of scans
- `:ds`: number of dummy scans
- `:rg`: receiver gain
- `:ndim`: number of dimensions
- `:title`: spectrum title (contents of title pdata file)
- `:filename`: spectrum filename
- `:pulseprogram`: title of pulse program used for acquisition
- `:experimentfolder`: path to experiment
- `:noise`: RMS noise level

# Examples (dimension metadata)
- `:pseudodim`: flag indicating non-frequency domain data
- `:npoints`: final number of (real) data points in dimension (after extraction)
- `:td`: number of complex points acquired
- `:tdzf`: number of complex points when FT executed, including LP and ZF
- `:bf`: base frequency, in MHz
- `:sf`: carrier frequency, in MHz
- `:offsethz`: carrier offset from bf, in Hz
- `:offsetppm`: carrier offset from bf, in ppm
- `:swhz`: spectrum width, in Hz
- `:swppm`: spectrum width, in ppm
- `:region`: extracted region, expressed as a range in points, otherwise missing
- `:window`: `WindowFunction` indicating applied apodization

See also [`estimatenoise!`](@ref).
"""
function metadata end

metadata(A::AbstractNMRData, key::Symbol) = get(metadata(A), key, nothing)
metadata(A::AbstractNMRData, dim, key::Symbol) = get(metadata(A, dim), key, nothing)
metadata(d::NMRDimension, key::Symbol) = get(metadata(d), key, nothing)

Base.getindex(A::AbstractNMRData, key::Symbol) = metadata(A, key)
Base.getindex(A::AbstractNMRData, dim, key::Symbol) = metadata(A, dim, key)
Base.getindex(d::NMRDimension, key::Symbol) = metadata(d, key)
Base.setindex!(A::AbstractNMRData, v, key::Symbol) = setindex!(metadata(A), v, key)  #(A[key] = v  =>  metadata(A)[key] = v)
function Base.setindex!(A::AbstractNMRData, v, dim, key::Symbol)
    return setindex!(metadata(A, dim), v, key)
end  #(A[dim, key] = v  =>  metadata(A, dim)[key] = v)
Base.setindex!(d::NMRDimension, v, key::Symbol) = setindex!(metadata(d), v, key)  #(d[key] = v  =>  metadata(d)[key] = v)

"""
    units(nmrdata)
    units(nmrdata, dim)
    units(nmrdimension)

Return the physical units associated with an `NMRData` structure or an `NMRDimension`.
"""
function units end
units(A::AbstractNMRData) = metadata(A, :units)
units(A::AbstractNMRData, dim) = metadata(A, dim, :units)
units(d::NMRDimension) = get(metadata(d), :units, nothing)

"""
    label(nmrdata)
    label(nmrdata, dim)
    label(nmrdimension)

Return a short label associated with an `NMRData` structure or an `NMRDimension`.
By default, for a spectrum this is obtained from the first line of the title file.
For a frequency dimension, this is normally something of the form `1H chemical shift (ppm)`.

See also [`label!`](@ref).
"""
function label end
label(A::AbstractNMRData) = metadata(A, :label)
label(A::AbstractNMRData, dim) = metadata(A, dim, :label)
label(d::NMRDimension) = get(metadata(d), :label, nothing)

"""
    label!(nmrdata, labeltext)
    label!(nmrdata, dim, labeltext)
    label!(nmrdimension, labeltext)

Set the label associated with an `NMRData` structure or an `NMRDimension`.

See also [`label`](@ref).
"""
function label! end
label!(A::AbstractNMRData, labeltext::AbstractString) = (A[:label] = labeltext)
label!(A::AbstractNMRData, dim, labeltext::AbstractString) = (A[dim, :label] = labeltext)
label!(d::NMRDimension, labeltext::AbstractString) = (d[:label] = labeltext)

"""
    acqus(nmrdata)
    acqus(nmrdata, key)
    acqus(nmrdata, key, index)

Return data from a Bruker acqus file, or `nothing` if it does not exist.
Keys can be passed as symbols or strings. If no key is specified, a dictionary
is returned representing the entire acqus file.

If present, the contents of auxilliary files such as `vclist` and `vdlist` can
be accessed using this function.

# Examples
```julia-repl
julia> acqus(expt, :pulprog)
"zgesgp"
julia> acqus(expt, "TE")
276.9988
julia> acqus(expt, :p, 1)
9.2
julia> acqus(expt, "D", 1)
0.1
julia> acqus(expt, :vclist)
11-element Vector{Int64}:
[...]
```

See also [`metadata`](@ref).
"""
acqus(A::AbstractNMRData) = metadata(A, :acqus)
function acqus(A::AbstractNMRData, key::Symbol)
    return ismissing(acqus(A)) ? missing : get(acqus(A), key, missing)
end
acqus(A::AbstractNMRData, key::String) = acqus(A, Symbol(lowercase(key)))
acqus(A::AbstractNMRData, key, index) = acqus(A, key)[index]

# # Metadata for NMRData #############################################################################

function defaultmetadata(::Type{<:AbstractNMRData})
    defaults = Dict{Symbol,Any}(:title => "",
                                :label => "",
                                :filename => nothing,
                                :format => nothing,
                                :lastserialised => nothing,
                                :pulseprogram => nothing,
                                :ns => nothing,
                                :rg => nothing,
                                :noise => nothing)

    return Metadata{NMRData}(defaults)
end

# Metadata for Dimensions ##########################################################################

function defaultmetadata(T::Type{<:NMRDimension})
    defaults = Dict{Symbol,Any}(:label => "",
                                :units => nothing)
    return Metadata{T}(defaults)
end

function defaultmetadata(::Type{<:FrequencyDimension})
    defaults = Dict{Symbol,Any}(:label => "",
                                :coherence => nothing,
                                :bf => nothing,
                                :offsethz => nothing,
                                :offsetppm => nothing,
                                :swhz => nothing,
                                :swppm => nothing,
                                :td => nothing,
                                :tdzf => nothing,
                                :npoints => nothing,
                                :region => nothing,
                                :units => nothing,
                                :window => nothing,
                                :mcindex => nothing)
    return Metadata{FrequencyDimension}(defaults)
end

function defaultmetadata(::Type{<:TimeDimension})
    defaults = Dict{Symbol,Any}(:label => "",
                                :units => nothing,
                                :window => nothing,
                                :mcindex => nothing)
    return Metadata{TimeDimension}(defaults)
end

function defaultmetadata(::Type{<:TrelaxDim})
    defaults = Dict{Symbol,Any}(:label => "Relaxation time",
                                :units => nothing)
    return Metadata{TrelaxDim}(defaults)
end

function defaultmetadata(::Type{<:TkinDim})
    defaults = Dict{Symbol,Any}(:label => "Time elapsed",
                                :units => nothing)
    return Metadata{TkinDim}(defaults)
end

function defaultmetadata(::Type{<:UnknownDimension})
    defaults = Dict{Symbol,Any}(:label => "",
                                :units => nothing)
    return Metadata{UnknownDimension}(defaults)
end

# Metadata entry definitions and help ##############################################################
function metadatahelp(A::Type{T}) where {T<:Union{NMRData,NMRDimension}}
    m = Metadata{A}()
    return Dict(map(kv -> kv[1] => metadatahelp(kv[1]), m))
end

function metadatahelp(key::Symbol)
    return get(metadatahelp(), key, "No information is available on this entry.")
end

function metadatahelp()
    d = Dict(:title => "Experiment title (may be multi-line)",
             :label => "Short experiment or axis description",
             :filename => "Original filename or template",
             :format => ":NMRPipe or :pdata",
             :pulseprogram => "Pulse program (PULPROG) from acqus file",
             :ns => "Number of scans",
             :rg => "Receiver gain",
             :noise => "RMS noise level",
             :units => "Axis units",
             :window => "Window function",
             :mcindex => "Index of imaginary component associated with axis (for multicomplex data)")
    return d
end```

-----------

Path: ./src/NMRBase/pcls.jl

```julia
"""
    pcls(A, y)

Compute the phase-constrained least squares solution:
```math
y = A x e^{i\\phi}
```
following the algorithm of Bydder (2010) *Lin Alg & Apps*.

Returns the tuple `(x, ϕ)`, containing the component amplitudes and global phase.

If passed a matrix `Y`, the function will return a matrix of component amplitudes and
a list of global phases corresponding to each row.

# Arguments
- `A`: (m,n) complex matrix with component spectra
- `y`: (m,) complex vector containing the observed spectrum
"""
function pcls(A::AbstractMatrix, y::AbstractVector)
    invM = pinv(real(A' * A))
    AHy = A' * y
    ϕ = 0.5 * angle(transpose(AHy) * invM * AHy)
    x = invM * real(AHy * exp(-im * ϕ))
    return x, ϕ
end

function pcls(A::AbstractMatrix, B::AbstractMatrix)
    n = size(A, 2)
    t = size(B, 2)
    X = zeros(n, t)
    Φ = zeros(t)

    invM = pinv(real(A' * A))

    for i in 1:t
        AHb = A' * B[:, i]
        ϕ = 0.5 * angle(transpose(AHb) * invM * AHb)
        X[:, i] = invM * real(AHb * exp(-im * ϕ))
        Φ[i] = ϕ
    end

    return X, Φ
end

# function pcls(A::AbstractMatrix, b::AbstractVector, invM)
#     AHb = A' * b
#     ϕ = 0.5 * angle(transpose(AHb) * invM * AHb)
#     x = invM * real(AHb * exp(-im*ϕ))
#     return x, ϕ
# end

# function plan_pcls(A::AbstractMatrix)
#     return pinv(real(A' * A))
# end
```

-----------

Path: ./src/precompile.jl

```julia
@compile_workload begin
    # 1D data
    axH = F1Dim(8:0.1:9; metadata=Dict{Symbol,Any}(:test => 123))
    dat = NMRData(0.0:1:10, (axH,))

    foo = dat[At(8.5)]
    foo = dat[Near(8.5)]
    foo = dat[8.4 .. 8.6]
    foo = dat[8.41 .. 8.6]
    foo = isnothing(metadata(dat, 1)[:window])
    foo = label(dims(dat, 1))
    foo = isnothing(units(dims(dat, 1)))
    foo = metadata(dat, 1)[:test]

    # 2D data
    x = 8:0.1:9
    y = 100:120
    z = x .+ y'  # 11 x 21

    axH = F1Dim(x)
    axN = F2Dim(y)
    dat = NMRData(z, (axH, axN))

    newax = TkinDim(110:130)
    dat = replacedimension(dat, 2, newax)

    # # data import
    # dat = loadnmr("../exampledata/1D_19F/1/test.ft1")
    # dat = loadnmr("../exampledata/1D_19F/1/pdata/1")
    # foo = acqus(dat, :pulprog)
    # foo = dat[1,:window]
    # dat = loadnmr("../exampledata/2D_HN/1/test.ft2")
    # dat = loadnmr("../exampledata/pseudo2D_XSTE/1/test.ft1")
end```

-----------

