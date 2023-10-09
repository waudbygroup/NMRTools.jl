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
spec = loadnmr("../../exampledata/1D_19F/1")
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

```@example 1
savefig("myspectrum.pdf")
```


## Plot a series of 1D spectra

Load and plot multiple 1D spectra from a list of filenames

```@example 1Ds
using NMRTools, Plots
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
spectra = [loadnmr(filename) for filename in filenames]
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

