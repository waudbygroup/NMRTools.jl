# Chemical Shift Referencing

NMRTools provides comprehensive chemical shift referencing capabilities, including:
- Direct referencing of individual dimensions
- Indirect referencing of heteronuclear dimensions using IUPAC Xi ratios
- Temperature-dependent water referencing for aqueous samples

## Basic Referencing

To reference a spectrum, specify the dimension and the old and new chemical shift values:

```julia
using NMRTools

# Load a spectrum
spec = loadnmr("hsqc.ft2")

# Reference the 1H dimension
spec = reference(spec, H1, -0.12 => 0)

# Or use dimension types
spec = reference(spec, F1Dim, -0.12 => 0)

# Or use dimension indices
spec = reference(spec, 1, -0.12 => 0)
```

## Indirect Referencing

By default, when you reference one dimension, NMRTools will automatically apply indirect referencing to all other frequency dimensions using IUPAC Xi ratios. This ensures consistent referencing across all dimensions based on a single reference point.

```julia
# Reference 1H - 15N dimension will be automatically referenced too
spec = reference(spec, H1, -0.12 => 0)

# Disable indirect referencing if needed
spec = reference(spec, H1, -0.12 => 0; indirect=false)
```

The Xi ratios used depend on whether the solvent is aqueous (DSS-based) or organic (TMS-based):

| Nucleus | DSS (aqueous) | TMS (organic) |
|---------|---------------|---------------|
| ¹H      | 1.0           | 1.0           |
| ²H      | 0.153506088   | 0.153506088   |
| ¹³C     | 0.251449530   | 0.25145020    |
| ¹⁵N     | 0.101329118   | 0.10136767    |
| ¹⁹F     | 0.940866982   | 0.94094011    |
| ³¹P     | 0.404807356   | 0.40480742    |

NMRTools automatically detects aqueous solvents from the spectrum metadata, or you can specify explicitly:

```julia
# Force DSS (aqueous) Xi ratios
spec = reference(spec, H1, -0.12 => 0; aqueous=true)

# Force TMS (organic) Xi ratios
spec = reference(spec, H1, -0.12 => 0; aqueous=false)
```

## Multi-Dimension Referencing

Reference multiple dimensions at once:

```julia
# Reference both 1H and 15N dimensions
spec = reference(spec, [H1, N15], [-0.12 => 0, 120.0 => 118.5])

# Or using dimension types
spec = reference(spec, [F1Dim, F2Dim], [-0.12 => 0, 120.0 => 118.5])
```

## Water Referencing

For aqueous samples, NMRTools can automatically reference to water based on the sample temperature:

```julia
# Reference to water (temperature from metadata)
spec = reference(spec)

# Specify temperature manually (in Kelvin)
spec = reference(spec; temperature=298.15)
```

The water chemical shift is calculated using the empirical formula:

δ(H₂O) = 7.83 − T / 96.9

where T is the temperature in Kelvin. Bruker spectrometers typically set the water reference to 4.7 ppm when locking, so the correction is applied relative to this default.

