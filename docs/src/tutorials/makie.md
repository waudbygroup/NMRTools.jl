# Makie plotting

NMRTools provides a Makie extension with `nmrplot` and `nmrplot!` for interactive or publication-quality figures while preserving NMR plotting conventions (reversed chemical-shift axes, sensible defaults for 1D/2D/3D).

To activate the extension, load NMRTools and a Makie backend (for example CairoMakie or GLMakie):

```@example 1
using NMRTools
using CairoMakie
```

## Quick start

### 1D spectrum

```@example 1
fig = nmrplot(exampledata("1D_1H"))
save("makie-1D.svg", fig); nothing # hide
```

![](makie-1D.svg)

Set the plot range with the `xlims` option - the spectrum will rescale vertically to match:

```@example 1
fig = nmrplot(exampledata("1D_1H"), xlims=(-1, 4.5))
save("makie-1D-xlim.svg", fig); nothing # hide
```

![](makie-1D-xlim.svg)


Use the mutating form to overlay additional spectra onto the same axis:

```@example 1
nmrplot!(fig, exampledata("1D_1H") / 2)
save("makie-1Db.svg", fig); nothing # hide
```

![](makie-1Db.svg)

### 2D spectrum

```@example 1
spec2d = exampledata("2D_HN")
fig = nmrplot(spec2d)
save("makie-2D.svg", fig); nothing # hide
```

![](makie-2D.svg)

Add 1D projections along each axis:

```@example 1
fig = nmrplot(exampledata("2D_HN"), xprojection=true, yprojection=true)
save("makie-2D-projections.svg", fig); nothing # hide
```

![](makie-2D-projections.svg)

Plot a series of 2Ds in one call:

```@example 1
fig = nmrplot(exampledata("2D_HN_titration"), legend=:topleft)
save("makie-2D-series.svg", fig); nothing # hide
```

![](makie-2D-series.svg)

Or add spectra one-by-one with `nmrplot!` and then add a legend in standard Makie style:

```@example 1
dats = exampledata("2D_HN_titration")
fig, ax = nmrplot(dats[1], title="", xlims=(-120, -128))
nmrplot!(fig, dats[5])
nmrplot!(fig, dats[10])
axislegend(ax)
save("makie-2D-series-add.svg", fig); nothing # hide
```

![](makie-2D-series-add.svg)

When plotting a small number of 2Ds, Makie's default cycle is used instead of a rainbow gradient:

```@example 1
fig = nmrplot(exampledata("2D_HN_titration")[[1, 5, 10]])
save("makie-2D-series-small.svg", fig); nothing # hide
```

![](makie-2D-series-small.svg)

Contours are drawn at positive and negative levels by default. You can control colours and disable negative contours:

```@example 1
fig = nmrplot(spec2d; negcontours=false)
save("makie-2Db.svg", fig); nothing # hide
```

![](makie-2Db.svg)

or adjust negative contour colours:

```@example 1
fig = nmrplot(spec2d; negcolor=:red)
save("makie-2Dc.svg", fig); nothing # hide
```

![](makie-2Dc.svg)


### Pseudo-2D spectra (one frequency + one non-frequency dimension)

Choose a style with the `style` keyword:

- `style=:heatmap` (default)
- `style=:flat` (overlaid 1D slices)
- `style=:waterfall` (3D slice view)

Example pseudo-2D diffusion plot:

```@example 1
diffusiondata = exampledata("pseudo2D_XSTE")
# set the gradient strengths - which varied from 2% to 98% of the max, over 10 points
diffusiondata = setgradientlist(diffusiondata, LinRange(0.02, 0.98, 10))
fig = nmrplot(diffusiondata, xlims=(7, 9.5))
save("makie-pseudo2D-heatmap.svg", fig); nothing # hide
```

![](makie-pseudo2D-heatmap.svg)

The default is a heatmap, and flat/waterfall styles are also available:

```@example 1
fig = nmrplot(diffusiondata, xlims=(7, 9.5), style=:flat)
save("makie-pseudo2D-flat.svg", fig); nothing # hide
```

![](makie-pseudo2D-flat.svg)

```@example 1
fig = nmrplot(diffusiondata, xlims=(7, 9.5), style=:waterfall)
save("makie-pseudo2D-waterfall.svg", fig); nothing # hide
```

![](makie-pseudo2D-waterfall.svg)



## Plot placement and layout

`nmrplot` works directly with Makie layouts and can be composed with other Makie plots:

```@example 1
fig = Figure()

nmrplot(fig[1, 1], exampledata("1D_1H"); title="", xlims=(-1, 4.5))
nmrplot(fig[1, 2], exampledata("2D_HN"); title="", xlims=(6, 10))
scatter(fig[2,:], randn(100))

save("makie-plots.svg", fig); nothing # hide
```

![](makie-plots.svg)



