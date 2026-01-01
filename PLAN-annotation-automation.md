# Plan: Automatic Axis and Value Application from Pulse Program Annotations

## Overview

Extend the `annotate!` function to automatically apply semantic axes and values to NMRData dimensions based on parsed pulse program annotations. This will eliminate the need for manual calls to `setrelaxtimes()`, `setgradientlist()`, etc.

## Current State

### What already exists:

1. **Annotation parsing** (`src/NMRIO/annotation.jl`):
   - `annotate!()` parses YAML annotations from pulse programs (`;@ ` lines)
   - Resolves parameter references (p1, pl1, d20 → actual values)
   - Resolves programmatic lists (linear/log spacing, counter-based)
   - Stores annotations in `spec[:annotations]`

2. **Power handling** (`src/NMRBase/power.jl`):
   - `Power` type with dB/Watts conversion
   - **`hz(p::Power, ref_p::Power, ref_pulselength, ref_pulseangle_deg)`** - converts power to RF field strength in Hz using reference pulse

3. **Reference pulse access** (`src/NMRBase/metadata.jl:325-343`):
   - **`referencepulse(spec, nucleus)`** - returns `(pulse_length, power)` tuple from annotations

4. **FQList handling** (`src/NMRIO/lists.jl`):
   - `FQList` type for frequency lists with unit/relativity tracking
   - **`ppm(f::FQList, ax::FrequencyDimension)`** - converts to absolute ppm
   - **`hz(f::FQList, ax::FrequencyDimension)`** - converts to offset Hz

5. **Dimension types** (`src/NMRBase/dimensions.jl`):
   - `FrequencyDimension`: F1Dim-F4Dim
   - `TimeDimension`: T1Dim-T4Dim, **TrelaxDim**, **TkinDim**
   - `GradientDimension`: G1Dim-G4Dim
   - `UnknownDimension`: X1Dim-X4Dim

6. **Dimension setters** (`src/NMRBase/nmrdata.jl`):
   - `setrelaxtimes(spec, [dim], values, units)` → TrelaxDim
   - `setkinetictimes(spec, [dim], values, units)` → TkinDim
   - `setgradientlist(spec, [dim], values, Gmax)` → GxDim

### Example annotation in pulse program:
```yaml
;@ experiment_type: [r1rho, 1d]
;@ dimensions: [r1rho.duration, r1rho.power, f1]
;@ reference_pulse:
;@ - {channel: f1, duration: p1, power: pl1}
;@ r1rho: {channel: f1, power: powerlist, duration: taulist, offset: 0}
```

## Proposed Changes

### Phase 1: New Dimension Types

Add to `src/NMRBase/dimensions.jl`:

```julia
# Offset dimensions (for CEST, R1rho off-resonance)
abstract type OffsetDimension{T} <: NonFrequencyDimension{T} end
@NMRdim OffsetDim OffsetDimension "Offset"

# Power/field strength dimension (for R1rho dispersion, nutation)
abstract type FieldDimension{T} <: NonFrequencyDimension{T} end
@NMRdim SpinlockDim FieldDimension "Spinlock field"
@NMRdim NutationDim FieldDimension "Nutation field"
```

Add default metadata for these:

```julia
function defaultmetadata(::Type{<:OffsetDimension})
    defaults = Dict{Symbol,Any}(:label => "Offset",
                                :units => "ppm",
                                :nucleus => nothing)
    return Metadata{OffsetDimension}(defaults)
end

function defaultmetadata(::Type{<:FieldDimension})
    defaults = Dict{Symbol,Any}(:label => "Field strength",
                                :units => "Hz")
    return Metadata{FieldDimension}(defaults)
end
```

### Phase 2: New Dimension Setters

Add to `src/NMRBase/nmrdata.jl`:

```julia
"""
    setoffsets(A::NMRData, [dimnumber], offsets, units="ppm")

Return a new NMRData with an offset axis (for CEST, R1rho, etc.).
"""
function setoffsets(A::NMRData, dimnumber::Integer, offsets::AbstractVector, units="ppm")
    newdim = OffsetDim(offsets)
    newA = replacedimension(A, dimnumber, newdim)
    label!(newA, newdim, "Offset")
    newA[newdim, :units] = units
    return newA
end

# Single non-frequency dimension version
function setoffsets(A::NMRData, offsets::AbstractVector, units="ppm")
    # ... similar to setrelaxtimes pattern ...
end

"""
    setspinlockfield(A::NMRData, [dimnumber], fields, units="Hz")

Return a new NMRData with a spinlock field strength axis.
"""
function setspinlockfield(A::NMRData, dimnumber::Integer, fields::AbstractVector, units="Hz")
    newdim = SpinlockDim(fields)
    newA = replacedimension(A, dimnumber, newdim)
    label!(newA, newdim, "Spinlock field")
    newA[newdim, :units] = units
    return newA
end
```

### Phase 3: Extend annotate! Function

Modify `annotate!` in `src/NMRIO/annotation.jl` to apply dimensions after resolving annotations:

```julia
function annotate!(spec::NMRData)
    pp = pulseprogram(spec)
    if isnothing(pp) || ismissing(pp) || length(pp) == 0
        return nothing
    end
    annotations = parse_annotations(pp)

    # Check schema version
    schema_version = get(annotations, "schema_version", nothing)
    if isnothing(schema_version)
        return nothing
    elseif schema_version != "0.0.2"
        @warn "Pulse programme uses unsupported schema version $schema_version..."
        return nothing
    end

    # Resolve parameter references to actual values
    resolve_parameter_references!(annotations, spec)

    # Resolve programmatic list patterns
    resolve_programmatic_lists!(annotations, spec)

    # Reverse dimensions to match data order
    if haskey(annotations, "dimensions")
        annotations["dimensions"] = reverse(annotations["dimensions"])
    end

    # Store annotations
    spec[:annotations] = annotations

    # NEW: Apply dimension transformations based on annotations
    spec = _apply_dimension_annotations!(spec, annotations)

    return annotations
end
```

### Phase 4: Dimension Application Logic

Add to `src/NMRIO/annotation.jl`:

```julia
"""
    _apply_dimension_annotations!(spec::NMRData, ann::Dict)

Apply semantic dimension types based on the dimensions array in annotations.
Modifies dimensions in-place where appropriate.
"""
function _apply_dimension_annotations!(spec::NMRData, ann::Dict)
    dimensions = get(ann, "dimensions", nothing)
    isnothing(dimensions) && return spec

    for (i, dim_spec) in enumerate(dimensions)
        spec = _apply_single_dimension!(spec, i, dim_spec, ann)
    end

    return spec
end

function _apply_single_dimension!(spec, dim_index, dim_spec::String, ann)
    parts = split(dim_spec, ".")

    # Skip simple dimensions like "f1", "f2" - already correct
    length(parts) == 1 && return spec

    block_name = parts[1]  # e.g., "relaxation", "diffusion", "cest", "r1rho"
    param_name = parts[2]  # e.g., "duration", "offset", "g", "power"

    # Get the parameter block from annotations
    block = get(ann, block_name, nothing)
    isnothing(block) && return spec

    # Get the actual values (already resolved)
    values = get(block, param_name, nothing)
    isnothing(values) && return spec

    # Dispatch to specific handler
    if block_name == "relaxation" && param_name == "duration"
        return _apply_relaxation_duration!(spec, dim_index, values)

    elseif block_name == "diffusion" && param_name == "g"
        return _apply_diffusion_gradient!(spec, dim_index, values, block)

    elseif block_name in ("cest", "r1rho") && param_name == "offset"
        return _apply_offset!(spec, dim_index, values, block, ann)

    elseif block_name in ("cest", "r1rho") && param_name == "power"
        return _apply_spinlock_power!(spec, dim_index, values, block, ann)

    elseif block_name == "r1rho" && param_name == "duration"
        return _apply_relaxation_duration!(spec, dim_index, values)

    elseif block_name == "calibration" && param_name == "duration"
        return _apply_nutation_duration!(spec, dim_index, values, block)
    end

    return spec
end
```

### Phase 5: Specific Dimension Handlers

```julia
function _apply_relaxation_duration!(spec, dim_index, values)
    # values is array of delay times in seconds
    return setrelaxtimes(spec, dim_index, values, "s")
end

function _apply_diffusion_gradient!(spec, dim_index, values, block)
    # values is array of relative gradient strengths (0-1)
    gmax = get(block, "gmax", nothing)
    return setgradientlist(spec, dim_index, values, gmax)
end

function _apply_offset!(spec, dim_index, values, block, ann)
    channel = get(block, "channel", nothing)
    isnothing(channel) && return spec

    # Find the frequency dimension for this channel
    freq_dim_index = _find_frequency_dim_for_channel(spec, channel, ann)
    isnothing(freq_dim_index) && return spec

    # Convert FQList to ppm if needed
    if values isa FQList
        freq_dim = dims(spec, freq_dim_index)
        offset_ppm = ppm(values, freq_dim)
    else
        offset_ppm = values
    end

    return setoffsets(spec, dim_index, offset_ppm, "ppm")
end

function _apply_spinlock_power!(spec, dim_index, values, block, ann)
    channel = get(block, "channel", nothing)
    isnothing(channel) && return spec

    # Get reference pulse for this channel to convert Power → Hz
    ref_pulse = referencepulse(spec, channel)
    isnothing(ref_pulse) && return spec
    ref_duration, ref_power = ref_pulse

    # Convert Power values to Hz using existing hz() function
    if values isa AbstractVector && eltype(values) <: Power
        # Use hz(p::Power, ref_p::Power, ref_pulselength, ref_pulseangle_deg)
        # Reference pulse is 90° by convention
        field_hz = [hz(p, ref_power, ref_duration, 90.0) for p in values]
    elseif values isa AbstractVector
        # Already numeric (Hz assumed)
        field_hz = values
    else
        return spec
    end

    return setspinlockfield(spec, dim_index, field_hz, "Hz")
end

function _apply_nutation_duration!(spec, dim_index, values, block)
    # Nutation calibration: array of pulse durations
    # Just use TrelaxDim for now, could make a dedicated type
    return setrelaxtimes(spec, dim_index, values, "s")
end
```

### Phase 6: Helper Function for Channel Resolution

```julia
"""
    _find_frequency_dim_for_channel(spec, channel, ann)

Find the frequency dimension index corresponding to a channel specification.
Channel can be "f1", "19F", "1H", etc.
"""
function _find_frequency_dim_for_channel(spec, channel::String, ann)
    # If channel is "f1", "f2", etc., look up the nucleus
    m = match(r"^f(\d+)$", channel)
    if !isnothing(m)
        nuc_index = parse(Int, m.captures[1])
        nuc_str = acqus(spec, Symbol("nuc$nuc_index"))
        if !isnothing(nuc_str) && !ismissing(nuc_str)
            channel = nuc_str  # e.g., "19F"
        end
    end

    # Now find dimension with matching nucleus
    for (i, d) in enumerate(dims(spec))
        if d isa FrequencyDimension
            dim_nuc = metadata(d, :nucleus)
            if !isnothing(dim_nuc) && string(dim_nuc) == channel
                return i
            end
        end
    end

    return nothing
end
```

## Implementation Order

1. **New dimension types** in `dimensions.jl`:
   - `OffsetDimension` abstract type and `OffsetDim` concrete type
   - `FieldDimension` abstract type with `SpinlockDim`, `NutationDim`
   - Default metadata for each

2. **New setter functions** in `nmrdata.jl`:
   - `setoffsets()` for offset dimensions
   - `setspinlockfield()` for field strength dimensions

3. **Dimension application logic** in `annotation.jl`:
   - `_apply_dimension_annotations!()` dispatcher
   - Individual handlers using existing `setrelaxtimes()`, `setgradientlist()`
   - New handlers for offsets and power using new setters

4. **Extend annotate!** to call `_apply_dimension_annotations!()`

5. **Exports** in `NMRBase.jl` and `NMRIO.jl`

## Key Design Decisions

1. **Integrate into annotate!**: Rather than creating a separate function, extend the existing `annotate!` to apply dimensions. This keeps the API simple.

2. **Leverage existing functions**:
   - Use `hz(Power, ref_Power, ref_pulselength, 90.0)` for spinlock power → Hz conversion
   - Use `ppm(FQList, FrequencyDimension)` for offset → ppm conversion
   - Use `referencepulse(spec, nucleus)` to get reference pulse parameters

3. **Minimal new types**: Only add truly new dimension types (`OffsetDim`, `SpinlockDim`) - don't duplicate functionality that exists in `TrelaxDim` or `GradientDimension`.

4. **Graceful degradation**: If annotations are incomplete, leave dimensions unchanged. Existing manual workflow still works.

## Testing Strategy

1. **Unit tests** for new dimension types and setters
2. **Integration tests** using existing test data:
   - `test/test-data/19f-cest-ts3/` - verify CEST offset → OffsetDim with ppm values
   - `test/test-data/19f-r1rho-onres-ts4/` - verify R1rho duration → TrelaxDim, power → SpinlockDim
3. **Backwards compatibility**: All existing tests must pass

## Export Additions

`NMRBase.jl`:
```julia
export OffsetDim, OffsetDimension
export SpinlockDim, NutationDim, FieldDimension
export setoffsets, setspinlockfield
```
