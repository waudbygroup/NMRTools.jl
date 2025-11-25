# Frequency lists

Frequency lists are used in NMR experiments to specify arrays of frequencies for selective excitation, CEST, or other variable-frequency experiments. On Bruker spectrometers, these are stored in files like `fq1list` through `fq8list`.

NMRTools represents frequency lists as [`FQList`](@ref) structures that preserve encoding information (Hz vs ppm, relative vs absolute) and provide safe conversion functions.

## Accessing frequency lists

Frequency lists are automatically imported when loading data:

```julia
# Load CEST experiment
spec = loadnmr("path/to/cest/experiment")

# Get frequency list
fqlist = acqus(spec, :fq1list)
```

## Extracting frequency values

Use `getppm()` and `getoffset()` to safely extract frequency values. These functions handle all unit conversions automatically.

### Get absolute chemical shifts (ppm)

```julia
dim = dims(spec, F2Dim)
ppm_values = getppm(fqlist, dim)
```

### Get offsets from carrier (Hz)

```julia
dim = dims(spec, F2Dim)
offset_hz = getoffset(fqlist, dim)
```

!!! tip
    Always use `getppm()` and `getoffset()` rather than accessing raw values directly. These functions handle all encoding schemes correctly.

## Conversion formulas

The conversion logic automatically handles all four encoding schemes:

### getppm(): Convert to absolute ppm

| Encoding | Formula |
|:---------|:--------|
| Hz, relative | ```math \mathrm{ppm} = \frac{v}{\mathrm{BF}} + \mathrm{offset_{ppm}} ``` |
| Hz, absolute | ```math \mathrm{ppm} = \frac{v}{\mathrm{BF}} ``` |
| ppm, relative | ```math \mathrm{ppm} = v + \mathrm{offset_{ppm}} ``` |
| ppm, absolute | ```math \mathrm{ppm} = v ``` |

### getoffset(): Convert to offset in Hz

| Encoding | Formula |
|:---------|:--------|
| Hz, relative | ```math \mathrm{offset_{Hz}} = v ``` |
| Hz, absolute | ```math \mathrm{offset_{Hz}} = v - \mathrm{offset_{Hz}} ``` |
| ppm, relative | ```math \mathrm{offset_{Hz}} = v \times \mathrm{BF} ``` |
| ppm, absolute | ```math \mathrm{offset_{Hz}} = (v - \mathrm{offset_{ppm}}) \times \mathrm{BF} ``` |

where $v$ is the stored value, BF is the base frequency (MHz), and offset is the carrier offset.

## Creating frequency lists

Construct `FQList` objects programmatically:

```@example fqlist
using NMRTools

# Frequency list in Hz, relative to carrier
fq_rel = FQList([100.0, 200.0, 300.0], :Hz, true)

# Frequency list in ppm, absolute (chemical shifts)
fq_abs = FQList([7.5, 8.0, 8.5], :ppm, false)
```
