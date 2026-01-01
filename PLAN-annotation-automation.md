# Plan: Automatic Axis and Value Application from Pulse Program Annotations

## Overview

Extend the `annotate!` function to automatically apply semantic axes and values to NMRData dimensions based on parsed pulse program annotations. This will eliminate the need for manual calls to `setrelaxtimes()`, `setgradientlist()`, etc.

## Current State

### What exists:
1. **Annotation parsing** (`src/NMRIO/annotation.jl`):
   - Parses YAML annotations from pulse programs (`;@ ` lines)
   - Resolves parameter references (p1, pl1, d20 → actual values)
   - Resolves programmatic lists (linear/log spacing, counter-based)
   - Stores annotations in `spec[:annotations]`

2. **Dimension types** (`src/NMRBase/dimensions.jl`):
   - `FrequencyDimension`: F1Dim-F4Dim
   - `TimeDimension`: T1Dim-T4Dim, **TrelaxDim**, **TkinDim**
   - `GradientDimension`: G1Dim-G4Dim
   - `UnknownDimension`: X1Dim-X4Dim

3. **Dimension setters** (`src/NMRBase/nmrdata.jl`):
   - `setrelaxtimes(spec, [dim], values, units)` → TrelaxDim
   - `setkinetictimes(spec, [dim], values, units)` → TkinDim
   - `setgradientlist(spec, [dim], values, Gmax)` → GxDim

4. **Annotation schema** (`ANNOTATIONS.md`):
   - `dimensions`: array specifying what each dimension represents
   - `relaxation`: {model, channel, duration}
   - `diffusion`: {type, coherence, big_delta, little_delta, g, gmax, shape}
   - `r1rho`: {channel, power, duration, offset}
   - `cest`: {channel, power, duration, offset}
   - `calibration.nutation`: {channel, power, duration, model, offset}

### Example annotation in pulse program:
```yaml
;@ experiment_type: [r1rho, 1d]
;@ dimensions: [r1rho.duration, r1rho.power, f1]
;@ r1rho: {channel: f1, power: powerlist, duration: taulist, offset: 0}
```

## Proposed Changes

### Phase 1: Core Infrastructure

#### 1.1 New function: `applyannotations!`

Create a new function in `annotation.jl` that applies semantic meaning from annotations to NMRData dimensions:

```julia
"""
    applyannotations!(spec::NMRData)

Apply semantic axis types and values from annotations to NMRData dimensions.
Automatically converts UnknownDimension axes to appropriate types based on
the experiment_type and dimension declarations.

Called automatically by loadnmr() after annotate!().
"""
function applyannotations!(spec::NMRData)
    hasannotations(spec) || return spec

    ann = annotations(spec)
    dimensions = get(ann, "dimensions", nothing)
    isnothing(dimensions) && return spec

    # Apply dimension-specific transformations
    for (i, dim_spec) in enumerate(dimensions)
        spec = _apply_dimension_annotation!(spec, i, dim_spec, ann)
    end

    return spec
end
```

#### 1.2 Dimension mapping logic

```julia
function _apply_dimension_annotation!(spec, dim_index, dim_spec, ann)
    # Parse dimension specification (e.g., "relaxation.duration", "cest.offset", "f1")
    # dim_spec can be:
    #   - "f1", "f2", etc. (frequency dimension - already correct)
    #   - "relaxation.duration" (relaxation time axis)
    #   - "diffusion.g" (gradient strength axis)
    #   - "cest.offset" (saturation offset axis)
    #   - "r1rho.duration", "r1rho.power" (R1rho parameters)

    parts = split(dim_spec, ".")

    if length(parts) == 1
        # Simple dimension like "f1" - skip
        return spec
    end

    block_name = parts[1]  # e.g., "relaxation", "diffusion", "cest", "r1rho"
    param_name = parts[2]  # e.g., "duration", "offset", "g", "power"

    # Get the parameter block from annotations
    block = get(ann, block_name, nothing)
    isnothing(block) && return spec

    # Get the actual values
    values = get(block, param_name, nothing)
    isnothing(values) && return spec

    # Apply based on block type and parameter
    return _convert_dimension!(spec, dim_index, block_name, param_name, values, ann)
end
```

### Phase 2: Experiment-Specific Handlers

#### 2.1 Relaxation experiments (R1, R2, etc.)

```julia
function _convert_relaxation_dimension!(spec, dim_index, values)
    # values should be an array of relaxation delays (in seconds)
    # Convert to TrelaxDim
    return setrelaxtimes(spec, dim_index, values, "s")
end
```

#### 2.2 Diffusion experiments (DOSY, STE)

```julia
function _convert_diffusion_dimension!(spec, dim_index, param, values, ann)
    if param == "g"
        # Gradient strength array
        gmax = get(ann["diffusion"], "gmax", nothing)
        return setgradientlist(spec, dim_index, values, gmax)
    end
    # Other diffusion parameters could be handled here
    return spec
end
```

#### 2.3 CEST experiments

Need a new dimension type for saturation offsets:

```julia
# In dimensions.jl - new dimension type
abstract type OffsetDimension{T} <: NonFrequencyDimension{T} end
@NMRdim CestOffsetDim OffsetDimension
@NMRdim R1rhoOffsetDim OffsetDimension
```

```julia
function _convert_cest_dimension!(spec, dim_index, param, values, ann)
    if param == "offset"
        # Convert FQList to ppm values relative to a frequency axis
        # Need to find the correct frequency axis based on channel
        channel = get(ann["cest"], "channel", "f1")
        freq_dim = _resolve_channel_to_dim(spec, channel)

        if values isa FQList
            offset_ppm = ppm(values, dims(spec, freq_dim))
        else
            offset_ppm = values
        end

        return setcestoffsets(spec, dim_index, offset_ppm)
    end
    return spec
end
```

#### 2.4 R1rho experiments

```julia
function _convert_r1rho_dimension!(spec, dim_index, param, values, ann)
    if param == "duration"
        return setrelaxtimes(spec, dim_index, values, "s")
    elseif param == "power"
        # New dimension type for spinlock power
        return setspinlockpower(spec, dim_index, values)
    elseif param == "offset"
        # Similar to CEST offset handling
        return setr1rhooffsets(spec, dim_index, values)
    end
    return spec
end
```

### Phase 3: New Dimension Types and Setters

#### 3.1 New dimension types (in `dimensions.jl`)

```julia
# Offset dimensions (for CEST, R1rho off-resonance)
abstract type OffsetDimension{T} <: NonFrequencyDimension{T} end
@NMRdim CestOffsetDim OffsetDimension "CEST offset"
@NMRdim R1rhoOffsetDim OffsetDimension "R1rho offset"

# Power dimension (for R1rho dispersion)
abstract type PowerDimension{T} <: NonFrequencyDimension{T} end
@NMRdim SpinlockPowerDim PowerDimension "Spinlock power"
```

#### 3.2 New setter functions (in `nmrdata.jl`)

```julia
"""
    setcestoffsets(A::NMRData, [dimnumber], offsets, units="ppm")

Return a new NMRData with a CEST offset axis containing the passed values.
"""
function setcestoffsets(A::NMRData, dimnumber::Integer, offsets::AbstractVector, units="ppm")
    newdim = CestOffsetDim(offsets)
    newA = replacedimension(A, dimnumber, newdim)
    label!(newA, newdim, "CEST offset")
    newA[newdim, :units] = units
    return newA
end

"""
    setspinlockpower(A::NMRData, [dimnumber], powers, units="Hz")

Return a new NMRData with a spinlock power axis.
"""
function setspinlockpower(A::NMRData, dimnumber::Integer, powers::AbstractVector, units="Hz")
    newdim = SpinlockPowerDim(powers)
    newA = replacedimension(A, dimnumber, newdim)
    label!(newA, newdim, "Spinlock power")
    newA[newdim, :units] = units
    return newA
end
```

### Phase 4: Integration with loadnmr

Update `loadnmr()` in `src/NMRIO/loadnmr.jl`:

```julia
function loadnmr(filename; experimentfolder=nothing, allcomponents=false)
    # ... existing code ...

    # 6. parse and resolve pulse programme annotations
    annotate!(spectrum)

    # 7. NEW: apply annotations to convert dimensions
    applyannotations!(spectrum)

    # 8. add sample information if available
    addsampleinfo!(spectrum)

    return spectrum
end
```

### Phase 5: Helper Functions

#### 5.1 Channel-to-dimension resolution

```julia
"""
    _resolve_channel_to_dim(spec, channel)

Resolve a channel specification (e.g., "f1", "f2") to a dimension index.
"""
function _resolve_channel_to_dim(spec, channel::String)
    # channel is typically "f1", "f2", etc.
    m = match(r"f(\d+)", channel)
    isnothing(m) && return nothing

    # f1 = first nucleus = look for matching frequency dimension
    nuc_index = parse(Int, m.captures[1])
    nuc_symbol = Symbol("nuc$nuc_index")
    target_nuc = acqus(spec, nuc_symbol)

    # Find frequency dimension with this nucleus
    for (i, d) in enumerate(dims(spec))
        if d isa FrequencyDimension
            dim_nuc = metadata(d, :nucleus)
            if dim_nuc == nucleus(target_nuc)
                return i
            end
        end
    end
    return nothing
end
```

#### 5.2 Power unit conversion

```julia
"""
Convert power values to Hz (B1 field strength).
"""
function _power_to_hz(power::Power, pulse_duration)
    # B1 = 1 / (4 * p90)
    # For a pulse at the given power level, calculate the effective field
    # This is approximate and depends on pulse calibration
    return 1 / (4 * pulse_duration)
end
```

## Implementation Order

1. **Phase 1**: Core `applyannotations!` infrastructure
   - Create `_apply_dimension_annotation!` dispatcher
   - Add call in `loadnmr()`

2. **Phase 2**: Relaxation experiments (simplest case)
   - Map `relaxation.duration` → `TrelaxDim`
   - Test with R1/R2 datasets

3. **Phase 3**: Diffusion experiments
   - Map `diffusion.g` → `GxDim`
   - Handle `gmax` parameter

4. **Phase 4**: New dimension types
   - Add `CestOffsetDim`, `R1rhoOffsetDim`, `SpinlockPowerDim`
   - Add corresponding setter functions

5. **Phase 5**: CEST and R1rho experiments
   - Map `cest.offset` → `CestOffsetDim`
   - Map `r1rho.duration` → `TrelaxDim`
   - Map `r1rho.power` → `SpinlockPowerDim`
   - Handle FQList → ppm conversion

6. **Phase 6**: Calibration experiments
   - Map `calibration.nutation.duration` → appropriate type

## Testing Strategy

1. **Unit tests** for each dimension mapping function
2. **Integration tests** using existing test data:
   - `test/test-data/19f-r1rho-onres-ts4/` (R1rho with duration + power)
   - `test/test-data/19f-cest-ts3/` (CEST with offset)
   - `test/test-data/15n-xste-ts3/` (diffusion)
3. **Round-trip tests**: Load data, verify dimension types and values

## Export Additions

Add to `NMRBase.jl` exports:
```julia
export CestOffsetDim, R1rhoOffsetDim, SpinlockPowerDim
export setcestoffsets, setspinlockpower, setr1rhooffsets
export applyannotations!  # If users need manual control
```

## Backwards Compatibility

- `applyannotations!` is called automatically but is non-destructive if no annotations exist
- Manual `setrelaxtimes()`, etc. still work for data without annotations
- Existing tests should continue to pass

## Future Extensions

1. **Nutation calibration**: Map pulse duration arrays
2. **Multiple relaxation channels**: Support R1/R2 on different nuclei
3. **Coherence order tracking**: Store and display coherence pathways
4. **Automatic plotting labels**: Use dimension metadata for plot annotations
