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
- `:fq1list` up to `:fq8list`: frequency lists – see the [Frequency lists](metadata-fqlists.md) page for more information.

## Frequency list API

Frequency lists can be specified on the spectrometer in a number of ways - in Hz, in ppm, and relative to the spectrometer frequency or the base frequency (0 ppm). Frequency lists are therefore stored in NMRTools as `FQList` structures which encode this additional information.

```@docs; canonical=false
FQList
ppm
hz
```

Raw numerical data can be accessed using the `data()` function, but it is recommended to use `ppm` and `hz` functions to access frequency data safely. See the [Frequency lists](metadata-fqlists.md) page for detailed examples.


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
| `:bf`                | base frequency, in Hz                                                     |
| `:label`             | short label                                                                |
| `:npoints`           | final number of **real** data points in dimension (after extraction)       |
| `:offsethz`          | carrier offset from bf, in Hz                                              |
| `:offsetppm`         | carrier offset from bf, in ppm                                             |
| `:pseudodim`         | flag indicating non-frequency domain data (`false` for frequency domain)   |
| `:region`            | extracted region, expressed as a range in points, otherwise `missing`      |
| `:sf`                | carrier frequency, in Hz                                                  |
| `:swhz`              | spectrum width, in Hz                                                      |
| `:swppm`             | spectrum width, in ppm                                                     |
| `:td`                | number of **complex** points acquired, including LP                        |
| `:tdzf`              | number of **complex** points when FT executed, including LP and ZF         |
| `:window`            | [`WindowFunction`](@ref) encoding applied apodization                      |
| `:referenceoffset`   | applied referencing, in ppm                                                |
