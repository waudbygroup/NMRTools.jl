# Dimensions

NMRTools uses semantic dimension types to represent different kinds of NMR data axes. These types extend the [DimensionalData.jl](https://github.com/rafaqz/DimensionalData.jl) framework.

## Dimension Type Hierarchy

```
NMRDimension
├── FrequencyDimension    # Chemical shift axes (ppm)
│   ├── F1Dim, F2Dim, F3Dim, F4Dim
├── NonFrequencyDimension # Non-frequency axes
│   ├── TimeDimension     # Time-based axes
│   │   ├── T1Dim, T2Dim, T3Dim, T4Dim  # FID time domains
│   │   ├── TrelaxDim     # Relaxation/delay times
│   │   └── TkinDim       # Kinetic time points
│   ├── GradientDimension # Gradient strength axes
│   │   └── G1Dim, G2Dim, G3Dim, G4Dim
│   ├── OffsetDimension   # Frequency offset axes
│   │   └── OffsetDim
│   ├── FieldDimension    # RF field strength axes
│   │   └── SpinlockDim
│   └── UnknownDimension  # Untyped axes
│       └── X1Dim, X2Dim, X3Dim, X4Dim
```

## Frequency Dimensions

`FrequencyDimension` types (`F1Dim`, `F2Dim`, etc.) represent chemical shift axes with units in ppm. These are automatically created when loading processed NMR data.

## Time Dimensions

- **TrelaxDim**: Used for arrayed time delays in relaxation experiments (R1, R2, R1rho durations, nutation pulse lengths, mixing times). The `:delay_type` metadata stores the experiment context (`:relaxation`, `:r1rho`, `:calibration`, etc.).
- **TkinDim**: Used for kinetic time points in time-resolved experiments.

## Gradient Dimensions

`GradientDimension` types (`G1Dim`, `G2Dim`, etc.) are used for diffusion experiments where gradient strength is arrayed. Units are typically T/m (Tesla per meter).

## Offset Dimensions

`OffsetDim` is used for experiments where frequency offset is arrayed, such as CEST or off-resonance R1rho. Units are typically ppm.

## Field Dimensions

`SpinlockDim` is used for experiments where RF field strength is arrayed, such as R1rho relaxation dispersion. Units are Hz (RF field strength = 1/4τ₉₀).

## Dimension Setter Functions

These functions create new NMRData objects with updated dimension types:

- `setrelaxtimes(spec, dim, times, units)` - Set relaxation/delay dimension
- `setkinetictimes(spec, dim, times, units)` - Set kinetic time dimension
- `setgradientlist(spec, dim, values, Gmax)` - Set gradient dimension
- `setoffsets(spec, dim, offsets, units)` - Set offset dimension
- `setspinlockfield(spec, dim, fields, units)` - Set spinlock field dimension

## Working with Dimensions

### Accessing Dimensions

```julia
# Get all dimensions
dims(spec)

# Get a specific dimension by type
dims(spec, F1Dim)
dims(spec, TrelaxDim)

# Get dimension by index
dims(spec, 1)
dims(spec, 2)
```

### Dimension Values

```julia
# Get axis values as a vector
collect(dims(spec, F1Dim))

# Access dimension metadata
spec[F1Dim, :units]      # "ppm"
spec[TrelaxDim, :units]  # "s"
```

### Replacing Dimensions

```julia
# Replace a dimension with a new type
newspec = replacedimension(spec, 2, TrelaxDim(times))
```

## Automatic Dimension Assignment

When loading annotated pulse programmes, NMRTools automatically assigns semantic dimension types based on the `dimensions` array in the annotations. See the [annotations documentation](ref-annotations.md) for details.
