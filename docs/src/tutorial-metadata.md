# Metadata

[`NMRData`](@ref) objects contain comprehensive metadata on processing and acquisition parameters. These are populated automatically when loading a spectrum. Entries are divided into **spectrum metadata** – associated with the experiment in general – and **axis metadata**, that are associated with a particular dimension of the data.

Examples of spectrum metadata include: number of scans, receiver gain, pulse program, experiment title, number of dimensions, noise level (calculated when the spectrum is loaded), acquisition parameters (pulse lengths etc, from the `acqus` file), contents of auxilliary files (e.g. vclists and vdlists).

Examples of axis metadata include: the number of points, the original time domain size (before zero filling, linear prediction or extraction of a subregion), carrier frequency, spectrum width, window function used for processing.


## Accessing spectrum metadata

Metadata are stored in a dictionary labelled by symbols such as `:ns` or `:pulseprogram`. This dictionary can be accessed using the [`metadata`](@ref) function.

```@example 1
using NMRTools
# load an example 2D 1H,15N HMQC spectrum
spec = loadnmr("../../exampledata/2D_HN/1")

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
relaxation_experiment = loadnmr("../../exampledata/pseudo3D_HN_R2/1")
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
