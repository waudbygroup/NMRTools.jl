# Getting started

## Installing NMRTools

Install NMRTools.jl through the Julia package manager:

```julia
using Pkg
Pkg.add("NMRTools")
```

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
