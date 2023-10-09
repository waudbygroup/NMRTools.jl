# Getting started

## Installing NMRTools

The Distributions package is available through the Julia package system by running `Pkg.add("NMRTools")`. Throughout, we assume that you have installed the package.

The examples in this tutorial also using the `Plots` package, which can be obtained similarly.


## Plot a 1D spectrum

Let's load some example data. This can be a Bruker experiment directory, a specific pdata folder, or an NMRPipe-format file.

```@example 1
using NMRTools, Plots
spec = loadnmr("../../exampledata/1D_19F/1")
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

```@example 1
savefig("myspectrum.pdf")
```


## Plot a series of 1D spectra

We can easily load multiple spectra by mapping [`loadnmr`](@ref) over a list of filenames. This produces a list of spectra, that can be passed directly to a `plot` command.

```@example 1Ds
using NMRTools, Plots # hide
filenames = ["../../exampledata/1D_19F_titration/1/",
            "../../exampledata/1D_19F_titration/2/",
            "../../exampledata/1D_19F_titration/3/",
            "../../exampledata/1D_19F_titration/4/",
            "../../exampledata/1D_19F_titration/5/",
            "../../exampledata/1D_19F_titration/6/",
            "../../exampledata/1D_19F_titration/7/",
            "../../exampledata/1D_19F_titration/8/",
            "../../exampledata/1D_19F_titration/9/",
            "../../exampledata/1D_19F_titration/10/",
            "../../exampledata/1D_19F_titration/11/"]
spectra = map(loadnmr, filenames)
plot(spectra, xlims=[-125, -121])
savefig("plot-1Ds.svg"); nothing # hide
```

![](plot-1Ds.svg)

!!! note
    Here we have used `xlims` to set the plot range, because the selector `..` used above would have needed to be applied to each spectrum individually.

**Stacked views** can also be produced using the `vstack=true` option.

```@example 1Ds
plot(spectra, vstack=true, xlims=[-125, -121])
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
using NMRTools, Plots # hide
spec = loadnmr("../../exampledata/2D_HN/1")
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


## Plot a series of 2D spectra

Multiple 2D spectra can be loaded and overlaid in a similar manner to 1Ds. In this case, we are loading data that has been processed using NMRPipe.

```@example 2Ds
using NMRTools, Plots # hide
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
spectra = map(loadnmr, filenames)
plot(spectra, legend=:topleft)
savefig("plot-2Ds.svg"); nothing # hide
```

![](plot-2Ds.svg)


We can adjust the plot limits with the usual `xlims!` and `ylims!` commands:

```@example 2Ds
xlims!(8,9.5)
ylims!(112,118)
savefig("plot-2Ds-zoom.svg"); nothing # hide
```

![](plot-2Ds-zoom.svg)


## Accessing your data

Spectrum data and associated axis information, metadata, etc, is encapsulated in an [`NMRData`](@ref) structure.
```@repl data
using NMRTools # hide
spec = loadnmr("../../exampledata/1D_19F/1")
```

Data can be accessed with conventional array indexing, but also using the value-based selectors, `Near` and `..`:
```@repl data
spec[100:105]
spec[Near(-124)]
spec[-123.5 .. -124]
```

This also works for multidimensional data. For example:
```@repl data
spec2d = loadnmr("../../exampledata/2D_HN/1")
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
