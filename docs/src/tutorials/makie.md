# Plotting with Makie

NMRTools provides a Makie extension with `nmrplot` and `nmrplot!` for interactive or publication-quality figures. Load NMRTools and a Makie backend:

```@example 1
using NMRTools
using CairoMakie   # static figures; use GLMakie for interactive
```

!!! note "NMR conventions applied automatically"
    Several behaviours differ from plain Makie to match NMR conventions:
    - **Titles** come from the spectrum's label (set from the title file on load). Pass `title=""` to suppress or `title="My title"` to override.
    - **Axes** are reversed (high ppm on the left/bottom) and labelled automatically from dimension metadata.
    - **`xlims`/`ylims`** are passed directly to `nmrplot` rather than calling `xlims!(ax, ...)` afterwards. For 1D plots the y-axis rescales to fit the displayed region.
    - **Contour levels** for 2D spectra are set automatically from the noise level (starting at 5σ, geometric spacing of 1.7). The keyboard can be used to raise or lower them interactively (see below).
    - **Legends** are disabled by default. When enabled, entries are named automatically from spectrum labels.

## 1D spectra

```@example 1
fig = nmrplot(exampledata("1D_1H"))
save("makie-1D.svg", fig); nothing # hide
```

![](makie-1D.svg)

Set the plot range with `xlims` — the y-axis rescales to fit the visible region:

```@example 1
fig = nmrplot(exampledata("1D_1H"), xlims=(-1, 4.5))
save("makie-1D-xlim.svg", fig); nothing # hide
```

![](makie-1D-xlim.svg)

Overlay additional spectra with `nmrplot!`:

```@example 1
nmrplot!(fig, exampledata("1D_1H") / 2)
save("makie-1Db.svg", fig); nothing # hide
```

![](makie-1Db.svg)

## 2D spectra

```@example 1
spec2d = exampledata("2D_HN")
fig = nmrplot(spec2d)
save("makie-2D.svg", fig); nothing # hide
```

![](makie-2D.svg)

Add 1D projections along either axis:

```@example 1
fig = nmrplot(exampledata("2D_HN"), xprojection=true, yprojection=true)
save("makie-2D-projections.svg", fig); nothing # hide
```

![](makie-2D-projections.svg)

Plot a series of spectra in one call; colours cycle automatically and a legend can be added:

```@example 1
fig = nmrplot(exampledata("2D_HN_titration"), legend=:lt)
save("makie-2D-series.svg", fig); nothing # hide
```

![](makie-2D-series.svg)

Or add spectra one-by-one with `nmrplot!`:

```@example 1
dats = exampledata("1D_19F_titration")
fig, ax = nmrplot(dats[1], title="", xlims=(-120, -128))
nmrplot!(fig, dats[5])
nmrplot!(fig, dats[10])
axislegend(ax)
save("makie-2D-series-add.svg", fig); nothing # hide
```

![](makie-2D-series-add.svg)

### Contour colours and levels

Negative contours are shown by default as a faded version of the positive colour. Disable them or set a different colour:

```@example 1
fig = nmrplot(spec2d; negcontours=false)
save("makie-2Db.svg", fig); nothing # hide
```

![](makie-2Db.svg)

```@example 1
fig = nmrplot(spec2d; negcolor=:red)
save("makie-2Dc.svg", fig); nothing # hide
```

![](makie-2Dc.svg)

Pass `levels` as an integer to change the number of contour levels, or as a vector of absolute values to use explicit levels:

```julia
nmrplot(spec2d; levels=8)                    # 8 geometric levels from 5σ
nmrplot(spec2d; levels=[2e6, 4e6, 8e6])      # explicit positive levels
```

`spacing` sets the geometric ratio between levels (default 1.7):

```julia
nmrplot(spec2d; spacing=2.0, levels=10)
```

### Keyboard navigation (GLMakie)

In GLMakie, press **↑** / **↓** to raise or lower all contour levels in the figure by one step (multiplied/divided by `spacing`). The key repeats while held. This works for any spectrum added with `nmrplot` or `nmrplot!`.

## Pseudo-2D spectra

Pseudo-2D spectra (one frequency + one non-frequency dimension) support three display styles via the `style` keyword:

| `style` | Description |
|:--------|:------------|
| `:heatmap` | colour map (default) |
| `:flat` | overlaid 1D slices |
| `:waterfall` | 3D slice view |

```@example 1
diffusiondata = exampledata("pseudo2D_XSTE")
diffusiondata = setgradientlist(diffusiondata, LinRange(0.02, 0.98, 10))
fig = nmrplot(diffusiondata, xlims=(7, 9.5))
save("makie-pseudo2D-heatmap.svg", fig); nothing # hide
```

![](makie-pseudo2D-heatmap.svg)

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

## Saving figures

```julia
save("spectrum.svg", fig)          # vector graphics (recommended)
save("spectrum.pdf", fig)
save("spectrum.png", fig)          # raster
save("spectrum.png", fig; px_per_unit=2)  # 2× resolution
```

## Layout and composition

`nmrplot` accepts a `GridPosition` to place spectra into a shared figure alongside other Makie plots:

```@example 1
fig = Figure()
nmrplot(fig[1, 1], exampledata("1D_1H"); title="", xlims=(-1, 4.5))
nmrplot(fig[1, 2], exampledata("2D_HN"); title="", xlims=(6, 10))
scatter(fig[2, :], randn(100))
save("makie-plots.svg", fig); nothing # hide
```

![](makie-plots.svg)

Axis properties can be customised after the fact via the returned `ax` handle, or passed up-front via the `axis` keyword:

```julia
fig, ax, plt = nmrplot(spec)
ax.title[] = "My spectrum"

# equivalently:
fig = nmrplot(spec; axis=(; title="My spectrum"))
```

## Animations

The standard Makie `record` function works directly with `nmrplot!`. This example cycles through a titration series and saves a GIF:

```@example 1
spectra = exampledata("2D_HN_titration")
ref = spectra[1]

fig, ax, _ = nmrplot(spectra[1]; normalize=ref, xlims=(6, 10.5))
record(fig, "makie-titration.gif", spectra; framerate=4) do s
    empty!(ax)
    ax.title[] = label(s)
    nmrplot!(ax, s; normalize=ref)
end
nothing # hide
```

![](makie-titration.gif)

For interactive use with GLMakie, the same `record` approach works — or you can update the plot live by re-calling `nmrplot!` in response to user events.

## Options reference

### 1D spectra

| Keyword | Default | Description |
|:--------|:--------|:------------|
| `title` | spectrum label | Pass `""` to suppress. |
| `color` | auto (Wong palette) | Line colour. |
| `normalize` | `true` | Scale by scans and receiver gain. Pass `false` to use raw intensities. |
| `vstack` | `false` | Stack spectra vertically. Pass a number to scale the offset. |
| `xlims` | auto | Chemical shift range (ppm). y-axis rescales to fit. |
| `legend` | `false` | Legend position, e.g. `:rt`. Entries named from spectrum labels. |
| `axis` | `(;)` | Extra `Axis` keyword arguments (escape hatch). |

### 2D spectra

| Keyword | Default | Description |
|:--------|:--------|:------------|
| `title` | spectrum label | Pass `""` to suppress. |
| `color` / `poscolor` | auto (Wong palette) | Positive contour colour. |
| `negcontours` | `true` | Show negative contours. |
| `negcolor` | faded positive | Negative contour colour. |
| `normalize` | `true` | Scale contour threshold by scans/gain. Pass a reference spectrum for cross-spectrum comparison. |
| `levels` | `12` | Number of contour levels (Int), or a vector of explicit positive level values. |
| `spacing` | `1.7` | Geometric ratio between successive contour levels; also the step size per ↑/↓ keypress. |
| `xprojection` | `nothing` | 1D projection along the direct dimension. Pass `true` for max-projection or a 1D `NMRData`. |
| `yprojection` | `nothing` | 1D projection along the indirect dimension. |
| `xlims` | auto | Direct-dimension range (ppm). |
| `ylims` | auto | Indirect-dimension range (ppm). |
| `legend` | `false` | Legend position, e.g. `:lt`. Entries named from spectrum labels. |
| `axis` | `(;)` | Extra `Axis` keyword arguments (escape hatch). |
