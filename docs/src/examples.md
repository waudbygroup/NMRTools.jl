# Examples

## Loading and plotting a 1D spectrum

Load in some example data, in NMRPipe format

```@repl 1
using NMRTools;
y = loadnmr("../../exampledata/1D_19F/test.ft1")
```

and then plot it

```@repl 1
using Plots;
plot(y);
savefig("plot-y.svg"); nothing # hide
```

![](plot-y.svg)

Zoom in on a particular region using a [`Between`](@ref) selector

```@repl 1
plot(y[Between(-123,-124.5)]);
savefig("plot-y2.svg"); nothing # hide
```

![](plot-y2.svg)


## A quick look at spectrum metadata

Access metadata associated with the spectrum

```@repl 1
metadata(y) |> keys
metadata(y, :pulseprogram)
metadata(y, :ns)
```

and with the X axis itself

```@repl 1
metadata(y, X) |> keys
metadata(y, X, :label)
metadata(y, X, :offsetppm)
```

This includes information on the window function, indicating in this case the line broadening applied (in Hz) and the acquisition time (in s)

```@repl 1
metadata(y, X, :window)
```

Help is available on metadata entries

```@repl 1
metadatahelp(:sf)
metadata(y, X, :sf)
```

**Acquisition parameters** are easily accessible

```@repl 1
acqus(y, :P, 1)
acqus(y, :P)
acqus(y, :TE)
```


## Overlaying multiple 1D spectra

Load and plot multiple 1D spectra from a list of filenames

```@repl 1Ds
using NMRTools, Plots;
filenames = ["../../exampledata/1D_19F_titration/2/test.ft1",
            "../../exampledata/1D_19F_titration/3/test.ft1",
            "../../exampledata/1D_19F_titration/4/test.ft1",
            "../../exampledata/1D_19F_titration/5/test.ft1",
            "../../exampledata/1D_19F_titration/6/test.ft1",
            "../../exampledata/1D_19F_titration/7/test.ft1",
            "../../exampledata/1D_19F_titration/8/test.ft1",
            "../../exampledata/1D_19F_titration/9/test.ft1",
            "../../exampledata/1D_19F_titration/10/test.ft1",
            "../../exampledata/1D_19F_titration/11/test.ft1",
            "../../exampledata/1D_19F_titration/12/test.ft1"];
spectra = [loadnmr(filename) for filename in filenames];
plot(spectra);
savefig("plot-1Ds.svg"); nothing # hide
```

![](plot-1Ds.svg)

Legends are produced from the first line of the spectrum title file (which in this example is not particularly informative!). The legend can be disabled using the `legend=nothing` option. **Stacked views** can also be produced using the `vstack=true` option. By default, spectra are normalized according to the number of scans and receiver gain determined automatically from the spectrum metadata; this can be disabled with the `normalize=false` option

```@repl 1Ds
plot(spectra, vstack=true, normalize=false, legend=nothing);
savefig("plot-1Ds-stack.svg"); nothing # hide
```

![](plot-1Ds-stack.svg)


## Loading and plotting a 2D spectrum

```@repl 2d
using NMRTools, Plots;
spec = loadnmr("../../exampledata/2D_HN/test.ft2")
contour(spec);
savefig("plot-2d.svg"); nothing # hide
```

![](plot-2d.svg)

### Accessing raw spectrum data

Spectrum data and associated axis information, metadata, etc, is encapsulated in an [`NMRData`](@ref) object. Raw arrays of data for the spectrum and axes can be obtained from this using [`data`](@ref), [`xval`](@ref) and [`yval`](@ref) commands

```@repl 2d
data(spec)
xval(spec)
yval(spec)
```


## Overlaying multiple 2D spectra

Multiple 2D spectra can be loaded and overlaid in a similar manner to 1Ds

```@repl 2Ds
using NMRTools, Plots;
filenames  = ["../../exampledata/2D_HN_titration/1/test.ft2",
              "../../exampledata/2D_HN_titration/2/test.ft2",
              "../../exampledata/2D_HN_titration/3/test.ft2",
              "../../exampledata/2D_HN_titration/4/test.ft2",
              "../../exampledata/2D_HN_titration/5/test.ft2",
              "../../exampledata/2D_HN_titration/6/test.ft2",
              "../../exampledata/2D_HN_titration/7/test.ft2",
              "../../exampledata/2D_HN_titration/8/test.ft2",
              "../../exampledata/2D_HN_titration/9/test.ft2",
              "../../exampledata/2D_HN_titration/10/test.ft2",
              "../../exampledata/2D_HN_titration/11/test.ft2"];
spectra = [loadnmr(filename) for filename in filenames];
contour(spectra);
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


## Analysis of pseudo-2D diffusion data

Load in an example pseudo-2D dataset

```@repl diffusion
using NMRTools, Plots;
spec = loadnmr("../../exampledata/pseudo2D_XSTE/test.ft1")
```

As this is a pseudo-2D, set the values for this axis using [`settval`](@ref). In this case, values are set to ten points equally spaced from 5% to 95%, representing the relative gradient strength used in the experiment

```@repl diffusion
spec = settval(spec, LinRange(0.05, 0.95, 10));
wireframe(spec);
savefig("plot-diff.svg"); nothing # hide
```

![](plot-diff.svg)

Fit the integral of signals from 7.5 to 9 ppm to the Stejskal-Tanner equation using [`fitdiffusion`](@ref) in order to determine the diffusion coefficient

```@repl diffusion
rH, D = fitdiffusion(spec, Between(7.5,9), T=283)
savefig("plot-diff-fit.svg"); nothing # hide
```

![](plot-diff-fit.svg)

An estimate of the hydrodynamic radius is determined based on the viscosity of pure water at the specified temperature (default 298 K). Default values for gradient pulse length, δ, and strength, Gmax, and the diffusion delay, Δ, can be altered using the full form of the command

```julia
fitdiffusion(spec, selector; δ=0.004, Δ=0.1, σ=0.9, Gmax=0.55, solvent=:h2o, T=298, showplot=true)
```


## Saving plots

All plots can be saved as high quality vector graphics, or as png files, using the `savefig` command

```julia
savefig("myspectrum.pdf")
savefig("myspectrum.svd")
savefig("myspectrum.png")
```
