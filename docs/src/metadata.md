# Metadata Overview

[`NMRData`](@ref) objects contain comprehensive metadata on processing and acquisition parameters that are populated automatically upon loading a spectrum. This metadata system provides access to all the information needed to understand, process, and analyze NMR data.

## Types of metadata

Metadata is organized into two categories:

1. **Spectrum metadata**: Information about the experiment as a whole (number of scans, receiver gain, pulse program, temperature, etc.)
2. **Axis metadata**: Information specific to each dimension (carrier frequency, spectral width, window functions, etc.)

## Quick start

### Accessing spectrum metadata

```@example overview
using NMRTools

# Load example spectrum
spec = exampledata("2D_HN")

# Access using the metadata function
metadata(spec, :ns)
```

```@example overview
# Or use dictionary-style lookup
spec[:pulseprogram]
```

### Accessing axis metadata

```@example overview
# By dimension type
spec[F2Dim, :label]
```

```@example overview
# Or by dimension number
spec[2, :swhz]
```

### Accessing acquisition parameters

```@example overview
# Get acquisition parameter
acqus(spec, :te)
```

```@example overview
# Access arrayed parameters
acqus(spec, :p, 1)  # First pulse length
```

## Special metadata types

NMRTools provides specialized types for handling complex metadata:

### Window functions

Window functions (apodization) applied during processing are stored as structured objects that preserve all parameters:

```@example overview
# Get window function for a dimension
win = spec[F2Dim, :window]
```

See the [Window functions](metadata-windows.md) page for detailed documentation.

### Power levels

Power levels are represented as [`Power`](@ref) objects that handle conversion between Watts and dB:

```julia
# Power levels from acqus file
p = acqus(spec, :pl, 1)
db(p)      # Get as dB
watts(p)   # Get as Watts
```

See the [Power levels](metadata-power.md) page for detailed documentation.

### Frequency lists

Frequency lists (from `fq1list`, etc.) are stored as [`FQList`](@ref) objects that preserve unit and reference information:

```julia
# Get frequency list
fqlist = acqus(spec, :fq1list)

# Extract as ppm or Hz
getppm(fqlist, dims(spec, F2Dim))
getoffset(fqlist, dims(spec, F2Dim))
```

See the [Frequency lists](metadata-fqlists.md) page for detailed documentation.

## Standard metadata keys

### Spectrum metadata symbols

| Symbol           | Description                                |
|:-----------------|:-------------------------------------------|
| `:filename`      | Original filename or template              |
| `:format`        | `:NMRPipe` or `:bruker`                    |
| `:title`         | Contents of `pdata/1/title`                |
| `:label`         | First line of title, used for captions     |
| `:pulseprogram`  | Pulse program (PULPROG) from acqus file    |
| `:ndim`          | Number of dimensions                       |
| `:acqusfilename` | Path to associated acqus file              |
| `:acqus`         | Dictionary of acqus data                   |
| `:ns`            | Number of scans                            |
| `:rg`            | Receiver gain                              |
| `:noise`         | RMS noise level                            |
| `:solvent`       | Solvent string, e.g. "H2O+D2O"             |
| `:temperature`   | Temperature in K                           |
| `:nuclei`        | Set of `Nucleus` values                    |

### Axis metadata symbols

| Symbol         | Description                                                           |
|:---------------|:----------------------------------------------------------------------|
| `:pseudodim`   | Flag indicating non-frequency domain data                             |
| `:npoints`     | Final number of (real) data points in dimension (after extraction)    |
| `:td`          | Number of complex points acquired                                     |
| `:tdzf`        | Number of complex points when FT executed, including LP and ZF        |
| `:bf`          | Base frequency, in MHz                                                |
| `:sf`          | Carrier frequency, in MHz                                             |
| `:offsethz`    | Carrier offset from bf, in Hz                                         |
| `:offsetppm`   | Carrier offset from bf, in ppm                                        |
| `:swhz`        | Spectrum width, in Hz                                                 |
| `:swppm`       | Spectrum width, in ppm                                                |
| `:region`      | Extracted region, expressed as a range in points, otherwise `missing` |
| `:window`      | `WindowFunction` object indicating applied apodization                |
| `:nucleus`     | `Nucleus` enum value for this dimension                               |

## Auxiliary files

Files such as `vclist`, `vdlist`, and frequency lists are automatically imported when present:

```@example overview
# Access variable delay list
relaxation_spec = exampledata("pseudo3D_HN_R2")
acqus(relaxation_spec, :vclist)
```

NMRTools performs automatic unit conversion:
- `:vclist`: Variable loop counter (dimensionless)
- `:vdlist`: Variable delays, in seconds
- `:valist`: Variable amplitude, in dB (converted from Watts if necessary)
- `:vplist`: Variable pulse lengths, in seconds
- `:fq1list` through `:fq8list`: Frequency lists (see [Frequency lists](metadata-fqlists.md))

## Next steps

- **[Power levels](metadata-power.md)**: Learn about power representation and RF field strength calculations
- **[Frequency lists](metadata-fqlists.md)**: Understand frequency list handling and conversions
- **[Window functions](metadata-windows.md)**: Explore apodization functions and lineshape effects
- **[Tutorial: Metadata](tutorial-metadata.md)**: Step-by-step introduction to working with metadata (see Tutorials section)
- **[Reference: Metadata](ref-metadata.md)**: Complete API reference for metadata functions (see Reference guide section)
