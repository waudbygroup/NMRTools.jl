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

Contours are drawn at positive and negative levels by default. You can control colours and disable negative contours:

```@example 1
nmrplot(spec2d; negcontours=false)
save("makie-2Db.svg", fig); nothing # hide
```

![](makie-2Db.svg)

or adjust negative contour colours:

```@example 1
nmrplot(spec2d; negcolor=:red)
save("makie-2Dc.svg", fig); nothing # hide
```

![](makie-2Dc.svg)


## Plot placement and layout

`nmrplot` works directly with Makie layout slots (`GridPosition`) and can be composed with other Makie plots:

```@example 1
fig = Figure(size=(1000, 420))

nmrplot(fig[1, 1], exampledata("1D_19F"); title="1D")
nmrplot(fig[1, 2], exampledata("2D_HN"); title="2D")

save("makie-plots.svg", fig); nothing # hide
```

![](makie-plots.svg)


## Supported data shapes

### 1D frequency-domain

- Plotted as lines on `Axis`
- Frequency axis is reversed (`xreversed=true`)
- Lists of 1D spectra can be overlaid or vertically stacked with `vstack`

### 2D pure-frequency

- Plotted as contour maps on `Axis`
- Both frequency axes are reversed
- Optional projections can be added with `xprojection` and `yprojection`

### 3D pure-frequency

- Plotted as iso-surfaces on `Axis3`
- Positive and optional negative surfaces are drawn at multiples of the noise level

### Pseudo-2D (one frequency + one non-frequency dimension)

Choose a style with the `style` keyword:

- `style=:heatmap` (single spectrum)
- `style=:flat` (overlaid 1D slices)
- `style=:waterfall` (3D slice view)

## Common keywords

Common options across plotting modes include:

- `normalize`: scale spectra consistently (default `true`)
- `title`, `xlabel`, `ylabel`, `zlabel`: axis/title labels
- `xlims`, `ylims`, `zlims`: explicit axis limits
- `color`, `colors`, `colormap`: line/contour colour control
- `axis`: pass a `NamedTuple` of Makie axis attributes for fine control

For complete function signatures and dispatch forms, see the API entries for [`nmrplot`](@ref) and [`nmrplot!`](@ref).
