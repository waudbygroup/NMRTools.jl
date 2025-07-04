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
| `:solvent`       | solvent string, e.g. "H2O+D2O"             |
| `:temperature`   | temperature in K                           |
| `:nuclei`        | set of `Nucleus` values                    |

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
| `:nucleus`	   | `Nucleus` enum value for this dimension                               |


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
