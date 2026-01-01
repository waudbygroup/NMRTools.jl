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

## Design Decisions

### TrelaxDim: General Purpose Delay Dimension

Keep `TrelaxDim` as a single, general-purpose dimension for all arrayed time delays:

| Experiment Type | Arrayed Parameter | Dimension |
|-----------------|-------------------|-----------|
| R1 relaxation | Recovery delay | `TrelaxDim` |
| R2 relaxation | Echo delay | `TrelaxDim` |
| R1ρ relaxation | Spinlock duration | `TrelaxDim` |
| Nutation calibration | Pulse duration | `TrelaxDim` |
| ZZ-exchange | Mixing time | `TrelaxDim` |

**Rationale**: All are fundamentally "arrayed time delays". The specific experiment type is captured in annotations, not the dimension type. This keeps the implementation parsimonious.

### Enriched TrelaxDim Metadata

Extend `TrelaxDim` default metadata to store experiment context:

```julia
function defaultmetadata(::Type{<:TrelaxDim})
    defaults = Dict{Symbol,Any}(
        :label => "Relaxation time",
        :units => nothing,
        :delay_type => nothing,   # :relaxation, :nutation, :mixing, etc.
        :nucleus => nothing       # Which nucleus (for labeling)
    )
    return Metadata{TrelaxDim}(defaults)
end
```

### New Dimension Types (Minimal)

Only add types for genuinely different physical quantities:

```julia
# Offset dimension (for CEST, R1rho off-resonance)
abstract type OffsetDimension{T} <: NonFrequencyDimension{T} end
@NMRdim OffsetDim OffsetDimension "Offset"

# Field strength dimension (for R1rho dispersion - B1 field in Hz)
abstract type FieldDimension{T} <: NonFrequencyDimension{T} end
@NMRdim SpinlockDim FieldDimension "Spinlock field"
```

## Proposed Changes

### Phase 1: Enrich TrelaxDim Metadata

Update `src/NMRBase/metadata.jl`:

```julia
function defaultmetadata(::Type{<:TrelaxDim})
    defaults = Dict{Symbol,Any}(
        :label => "Relaxation time",
        :units => nothing,
        :delay_type => nothing,   # :relaxation, :nutation, :mixing
        :nucleus => nothing
    )
    return Metadata{TrelaxDim}(defaults)
end
```

### Phase 2: New Dimension Types

Add to `src/NMRBase/dimensions.jl`:

```julia
# Offset dimensions (for CEST, R1rho off-resonance)
abstract type OffsetDimension{T} <: NonFrequencyDimension{T} end
@NMRdim OffsetDim OffsetDimension "Offset"

# Field strength dimension (for R1rho dispersion)
abstract type FieldDimension{T} <: NonFrequencyDimension{T} end
@NMRdim SpinlockDim FieldDimension "Spinlock field"
```

Add default metadata:

```julia
function defaultmetadata(::Type{<:OffsetDimension})
    defaults = Dict{Symbol,Any}(
        :label => "Offset",
        :units => "ppm",
        :nucleus => nothing
    )
    return Metadata{OffsetDimension}(defaults)
end

function defaultmetadata(::Type{<:FieldDimension})
    defaults = Dict{Symbol,Any}(
        :label => "Field strength",
        :units => "Hz"
    )
    return Metadata{FieldDimension}(defaults)
end
```

### Phase 3: New Dimension Setters

Add to `src/NMRBase/nmrdata.jl`:

```julia
"""
    setoffsets(A::NMRData, [dimnumber], offsets, units="ppm")

Return a new NMRData with an offset axis (for CEST, R1rho off-resonance, etc.).
"""
function setoffsets(A::NMRData, dimnumber::Integer, offsets::AbstractVector, units="ppm")
    newdim = OffsetDim(offsets)
    newA = replacedimension(A, dimnumber, newdim)
    label!(newA, newdim, "Offset")
    newA[newdim, :units] = units
    return newA
end

function setoffsets(A::NMRData, offsets::AbstractVector, units="ppm")
    # Find unique non-frequency dimension (same pattern as setrelaxtimes)
    hasnonfrequencydimension(A) ||
        throw(NMRToolsError("cannot set offset values: no non-frequency dimension"))
    nonfreqdims = isa.(dims(A), NonFrequencyDimension)
    sum(nonfreqdims) == 1 ||
        throw(NMRToolsError("multiple non-frequency dimensions - specify dimension number"))
    olddimnumber = findfirst(nonfreqdims)
    return setoffsets(A, olddimnumber, offsets, units)
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

function setspinlockfield(A::NMRData, fields::AbstractVector, units="Hz")
    hasnonfrequencydimension(A) ||
        throw(NMRToolsError("cannot set spinlock field: no non-frequency dimension"))
    nonfreqdims = isa.(dims(A), NonFrequencyDimension)
    sum(nonfreqdims) == 1 ||
        throw(NMRToolsError("multiple non-frequency dimensions - specify dimension number"))
    olddimnumber = findfirst(nonfreqdims)
    return setspinlockfield(A, olddimnumber, fields, units)
end
```

### Phase 4: Extend annotate! Function

Modify `annotate!` in `src/NMRIO/annotation.jl`:

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

    # Apply dimension transformations based on annotations
    _apply_dimension_annotations!(spec, annotations)

    return annotations
end
```

### Phase 5: Dimension Application Logic

Add to `src/NMRIO/annotation.jl`:

```julia
"""
    _apply_dimension_annotations!(spec::NMRData, ann::Dict)

Apply semantic dimension types based on the dimensions array in annotations.
Modifies the spectrum in-place by replacing dimensions.
"""
function _apply_dimension_annotations!(spec::NMRData, ann::Dict)
    dimensions = get(ann, "dimensions", nothing)
    isnothing(dimensions) && return

    for (i, dim_spec) in enumerate(dimensions)
        _apply_single_dimension!(spec, i, dim_spec, ann)
    end
end

function _apply_single_dimension!(spec, dim_index, dim_spec::String, ann)
    parts = split(dim_spec, ".")

    # Skip simple dimensions like "f1", "f2" - already correct
    length(parts) == 1 && return

    block_name = parts[1]  # e.g., "relaxation", "diffusion", "cest", "r1rho"
    param_name = parts[2]  # e.g., "duration", "offset", "g", "power"

    # Get the parameter block from annotations
    block = get(ann, block_name, nothing)
    isnothing(block) && return

    # Get the actual values (already resolved)
    values = get(block, param_name, nothing)
    isnothing(values) && return

    # Dispatch to specific handler based on block and parameter
    if param_name == "duration"
        _apply_duration!(spec, dim_index, values, block_name)
    elseif param_name == "g"
        _apply_gradient!(spec, dim_index, values, block)
    elseif param_name == "offset"
        _apply_offset!(spec, dim_index, values, block)
    elseif param_name == "power"
        _apply_power!(spec, dim_index, values, block)
    end
end
```

### Phase 6: Specific Dimension Handlers

```julia
function _apply_duration!(spec, dim_index, values, block_name)
    # All duration arrays use TrelaxDim
    # Set appropriate label based on experiment type
    label = if block_name == "relaxation"
        "Relaxation delay"
    elseif block_name == "r1rho"
        "Spinlock duration"
    elseif block_name == "calibration"
        "Pulse duration"
    else
        "Delay"
    end

    newdim = TrelaxDim(values)
    newspec = replacedimension(spec, dim_index, newdim)
    label!(newspec, newdim, label)
    newspec[newdim, :units] = "s"
    newspec[newdim, :delay_type] = Symbol(block_name)

    # Copy back to original spec (in-place modification)
    _update_dimension!(spec, dim_index, dims(newspec, dim_index))
end

function _apply_gradient!(spec, dim_index, values, block)
    gmax = get(block, "gmax", nothing)
    # Use existing setgradientlist logic
    if isnothing(gmax)
        @warn "No gmax specified for diffusion gradient axis"
        gmax = 0.55  # Default assumption
    end
    gvals = gmax * values

    if dim_index == 1
        newdim = G1Dim(gvals)
    elseif dim_index == 2
        newdim = G2Dim(gvals)
    else
        newdim = G3Dim(gvals)
    end

    newspec = replacedimension(spec, dim_index, newdim)
    label!(newspec, newdim, "Gradient strength")
    newspec[newdim, :units] = "T m⁻¹"

    _update_dimension!(spec, dim_index, dims(newspec, dim_index))
end

function _apply_offset!(spec, dim_index, values, block)
    channel = get(block, "channel", nothing)
    isnothing(channel) && return

    # Convert FQList to ppm if needed
    if values isa FQList
        freq_dim_index = _find_frequency_dim_for_channel(spec, channel)
        if !isnothing(freq_dim_index)
            freq_dim = dims(spec, freq_dim_index)
            offset_values = ppm(values, freq_dim)
        else
            offset_values = data(values)  # Fall back to raw values
        end
    else
        offset_values = values
    end

    newdim = OffsetDim(offset_values)
    newspec = replacedimension(spec, dim_index, newdim)
    label!(newspec, newdim, "Saturation offset")
    newspec[newdim, :units] = "ppm"
    newspec[newdim, :nucleus] = channel

    _update_dimension!(spec, dim_index, dims(newspec, dim_index))
end

function _apply_power!(spec, dim_index, values, block)
    channel = get(block, "channel", nothing)
    isnothing(channel) && return

    # Convert Power values to Hz using reference pulse
    ref_pulse = referencepulse(spec, channel)
    if isnothing(ref_pulse)
        @warn "No reference pulse found for channel $channel, cannot convert power to Hz"
        return
    end
    ref_duration, ref_power = ref_pulse

    # Convert Power array to Hz
    if eltype(values) <: Power
        field_hz = [hz(p, ref_power, ref_duration, 90.0) for p in values]
    else
        field_hz = values  # Assume already in Hz
    end

    newdim = SpinlockDim(field_hz)
    newspec = replacedimension(spec, dim_index, newdim)
    label!(newspec, newdim, "Spinlock field")
    newspec[newdim, :units] = "Hz"

    _update_dimension!(spec, dim_index, dims(newspec, dim_index))
end

"""
Update a dimension in-place by modifying the spec's dims tuple.
"""
function _update_dimension!(spec, dim_index, newdim)
    # Replace dimension in the dims tuple
    current_dims = collect(dims(spec))
    current_dims[dim_index] = newdim
    # Note: This requires rebuilding the NMRData - see implementation details
end

function _find_frequency_dim_for_channel(spec, channel::String)
    # If channel is "f1", "f2", look up the nucleus
    m = match(r"^f(\d+)$", channel)
    if !isnothing(m)
        nuc_index = parse(Int, m.captures[1])
        nuc_str = acqus(spec, Symbol("nuc$nuc_index"))
        if !isnothing(nuc_str) && !ismissing(nuc_str)
            channel = nuc_str
        end
    end

    # Find dimension with matching nucleus
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

1. **Enrich TrelaxDim metadata** in `metadata.jl`:
   - Add `:delay_type` and `:nucleus` fields

2. **New dimension types** in `dimensions.jl`:
   - `OffsetDimension` and `OffsetDim`
   - `FieldDimension` and `SpinlockDim`
   - Default metadata for each

3. **New setter functions** in `nmrdata.jl`:
   - `setoffsets()` for offset dimensions
   - `setspinlockfield()` for field strength dimensions

4. **Dimension application logic** in `annotation.jl`:
   - `_apply_dimension_annotations!()` main entry point
   - `_apply_duration!()` - uses existing `TrelaxDim`
   - `_apply_gradient!()` - uses existing `GxDim`
   - `_apply_offset!()` - uses new `OffsetDim`
   - `_apply_power!()` - uses new `SpinlockDim`
   - Helper: `_find_frequency_dim_for_channel()`

5. **Extend annotate!** to call `_apply_dimension_annotations!()`

6. **Exports** in `NMRBase.jl`

## Summary of New Types

| Type | Purpose | Units | Used For |
|------|---------|-------|----------|
| `TrelaxDim` (existing) | Arrayed time delays | s | R1, R2, R1ρ duration, nutation |
| `OffsetDim` (new) | Frequency offsets | ppm | CEST, R1ρ off-resonance |
| `SpinlockDim` (new) | B1 field strength | Hz | R1ρ dispersion |

## Testing Strategy

1. **Unit tests** for new dimension types and setters
2. **Integration tests** using existing test data:
   - `test/test-data/19f-cest-ts3/` - verify CEST offset → OffsetDim
   - `test/test-data/19f-r1rho-onres-ts4/` - verify R1rho duration → TrelaxDim, power → SpinlockDim
3. **Backwards compatibility**: All existing tests must pass

## Export Additions

`NMRBase.jl`:
```julia
export OffsetDim, OffsetDimension
export SpinlockDim, FieldDimension
export setoffsets, setspinlockfield
```
