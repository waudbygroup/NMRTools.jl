"""
    NMRDimension

Abstract supertype for all axes used in NMRData objects.

See also [`FrequencyDimension`](@ref) and [`NonFrequencyDimension`](@ref).
"""
abstract type NMRDimension{T} <: DimensionalData.Dimension{T} end

"""
    FrequencyDimension <: NMRDimension

Abstract supertype for frequency dimensions used in NMRData objects.
Concrete types `F1Dim`, `F2Dim`, `F3Dim` and `F4Dim` are generated for
use in creating objects.

See also [`NonFrequencyDimension`](@ref).
"""
abstract type FrequencyDimension{T} <: NMRDimension{T} end

"""
    NonFrequencyDimension <: NMRDimension

Abstract supertype for non-frequency dimensions used in NMRData objects.
Sub-types include [`TimeDimension`](@ref), [`GradientDimension`](@ref), 
and [`UnknownDimension`](@ref).

See also [`FrequencyDimension`](@ref).
"""
abstract type NonFrequencyDimension{T} <: NMRDimension{T} end

"""
    TimeDimension <: NonFrequencyDimension <: NMRDimension

Abstract supertype for time dimensions used in NMRData objects.
Concrete types `T1Dim`, `T2Dim`, `T3Dim` and `T4Dim` are generated for
time-domains representing frequency evolution, and `TrelaxDim` and
`TkinDim` are generated for representing relaxation and real-time
kinetics.
"""
abstract type TimeDimension{T} <: NonFrequencyDimension{T} end
# abstract type QuadratureDimension{T} <: NMRDimension{T} end

"""
    UnknownDimension <: NonFrequencyDimension <: NMRDimension

Abstract supertype for unknown, non-frequency dimensions used in NMRData objects.
Concrete types `X1Dim`, `X2Dim`, `X3Dim` and `X4Dim` are generated for
use in creating objects.
"""
abstract type UnknownDimension{T} <: NonFrequencyDimension{T} end

"""
    GradientDimension <: NonFrequencyDimension <: NMRDimension

Abstract supertype for gradient-encoded dimensions used in NMRData objects.
Concrete types `G1Dim`, `G2Dim`, `G3Dim` and `G4Dim` are generated for
use in creating objects.
"""
abstract type GradientDimension{T} <: NonFrequencyDimension{T} end

# override DimensionalData.Dimensions macro to generate default metadata
macro NMRdim(typ::Symbol, supertyp::Symbol, args...)
    return NMRdimmacro(typ, supertyp, args...)
end
function NMRdimmacro(typ, supertype, name::String=string(typ))
    esc(quote
            Base.@__doc__ struct $typ{T} <: $supertype{T}
                val::T
            end
            function $typ(val::AbstractArray; kw...)
                v = values(kw)
                # e.g. values(kw) = (metadata = NoMetadata(),)
                if :metadata ∉ keys(kw)
                    # if no metadata defined, define it
                    # alternatively, if there is valid metadata, merge in the defaults
                    @debug "Creating default dimension metadata"
                    v = merge((metadata=defaultmetadata($typ),), v)
                elseif v[:metadata] isa Metadata{$typ}
                    @debug "Merging dimension metadata with defaults"
                    v2 = merge(v, (metadata=defaultmetadata($typ),))
                    merge!(v2[:metadata].val, v[:metadata].val)
                    v = v2
                elseif v[:metadata] isa Dict
                    @debug "Merging metadata dictionary with defaults"
                    md = v[:metadata]
                    v = merge(v, (metadata=defaultmetadata($typ),))
                    merge!(v[:metadata].val, md)
                else
                    # if NoMetadata (or an invalid type), define the correct default metadata
                    @debug "Dimension metadata is NoMetadata - replace with defaults"
                    v = merge(v, (metadata=defaultmetadata($typ),))
                end
                val = AutoLookup(val, v)
                return $typ{typeof(val)}(val)
                # @show tmpdim = $typ{typeof(val)}(val)
                # @show newlookup = DimensionalData.Dimensions._format(tmpdim, axes(tmpdim,1))
                # return $typ{typeof(newlookup)}(newlookup)
            end
            function $typ(val::T) where {T<:DimensionalData.Dimensions.LookupArrays.LookupArray}
                # HACK - this would better be replaced with a call to DD.format in the function above
                # e.g.
                # DimensionalData.Dimensions.format(DimensionalData.LookupArrays.val(axH), DimensionalData.LookupArrays.basetypeof(axH), Base.OneTo(11))
                return $typ{T}(val)
            end
            $typ() = $typ(:)
            Dimensions.name(::Type{<:$typ}) = $(QuoteNode(Symbol(name)))
            Dimensions.key2dim(::Val{$(QuoteNode(typ))}) = $typ()
        end)
end

@NMRdim F1Dim FrequencyDimension
@NMRdim F2Dim FrequencyDimension
@NMRdim F3Dim FrequencyDimension
@NMRdim F4Dim FrequencyDimension
@NMRdim T1Dim TimeDimension
@NMRdim T2Dim TimeDimension
@NMRdim T3Dim TimeDimension
@NMRdim T4Dim TimeDimension
@NMRdim TrelaxDim TimeDimension
@NMRdim TkinDim TimeDimension
# @NMRdim Q1Dim QuadratureDimension
# @NMRdim Q2Dim QuadratureDimension
# @NMRdim Q3Dim QuadratureDimension
# @NMRdim Q4Dim QuadratureDimension
@NMRdim X1Dim UnknownDimension
@NMRdim X2Dim UnknownDimension
@NMRdim X3Dim UnknownDimension
@NMRdim X4Dim UnknownDimension
@NMRdim G1Dim GradientDimension
@NMRdim G2Dim GradientDimension
@NMRdim G3Dim GradientDimension
@NMRdim G4Dim GradientDimension
# @NMRdim SpatialDim NMRDimension

# Getters ########
"""
    data(nmrdimension)

Return the numerical data associated with an NMR dimension.
"""
data(d::NMRDimension) = d.val.data

"""
    getω(axis)

Return the offsets (in rad/s) for points along a frequency axis.
"""
getω(ax::FrequencyDimension) = 2π * ax[:bf] * (data(ax) .- ax[:offsetppm])

"""
    getω(axis, δ)

Return the offset (in rad/s) for a chemical shift (or list of shifts) on a frequency axis.
"""
getω(ax::FrequencyDimension, δ) = 2π * ax[:bf] * (δ .- ax[:offsetppm])



"""
    add_offset!(data::NMRData, dim_ref, offset)

Add an offset to a frequency dimension in an NMRData object. The dimension can be specified as a numerical index or an object like `F1Dim`.
The metadata is copied using `replacedimension`, and an entry is added or updated in the dimension metadata to record the offset change.
"""
function add_offset(spec, dim_ref, offsetppm)
    dim_no = if dim_ref isa Int
        dim_ref
    else
        findfirst(d -> d isa dim_ref, dims(spec))
    end
    # check that dim_no is valid (not nothing, and within the range of dims)
    if isnothing(dim_no) || dim_no > length(spec.dims) || dim_no < 1
        throw(NMRToolsError("add_offset: Dimension $dim_ref not found in NMRData object"))
    end

    dim = dims(spec, dim_no)

    new_data = data(dim) .+ offsetppm
    md = deepcopy(metadata(dim))
    if dim_no == 1
        newdim = F1Dim(new_data, metadata=md)
    elseif dim_no == 2
        newdim = F2Dim(new_data, metadata=md)
    elseif dim_no == 3
        newdim = F3Dim(new_data, metadata=md)
    end
    new_spec = replacedimension(spec, dim_no, newdim)
    
    if :referenceoffset ∉ keys(metadata(new_spec, dim_no))
        metadata(new_spec, dim_no)[:referenceoffset] = offsetppm
    else
        metadata(new_spec, dim_no)[:referenceoffset] += offsetppm
    end

    # adjust other metadata
    if metadata(new_spec, dim_no)[:offsetppm] !== nothing
        metadata(new_spec, dim_no)[:offsetppm] += offsetppm
    end
    if metadata(new_spec, dim_no)[:offsethz] !== nothing && metadata(new_spec, dim_no)[:bf] !== nothing
        metadata(new_spec, dim_no)[:offsethz] += offsetppm * metadata(new_spec, dim_no, :bf)
    end
    if haskey(metadata(new_spec, dim_no), :sf) && metadata(new_spec, dim_no)[:sf] !== nothing && metadata(new_spec, dim_no)[:bf] !== nothing
        metadata(new_spec, dim_no)[:sf] += offsetppm * metadata(new_spec, dim_no, :bf) / 1e6
    end

    return new_spec
end

"""
    reference(spectrum, axis, old_shift => new_shift)
    reference(spectrum, axes, old_shifts => new_shifts)

Convenient chemical shift referencing function that calculates the offset needed to
move a peak from `old_shift` to `new_shift` and applies it using `add_offset`.

# Arguments
- `spectrum`: NMRData object to reference
- `axis`: Dimension to reference (can be integer index or dimension object like F1Dim)
- `old_shift => new_shift`: Pair specifying the current position and desired position

For multiple axes, pass vectors/tuples:
- `axes`: Vector or tuple of dimensions
- `old_shifts => new_shifts`: Pair of vectors specifying current and desired positions

# Examples
```julia
# Reference F1 dimension: move peak from 4.7 ppm to 0.0 ppm
spec_ref = reference(spec, 1, 4.7 => 0.0)

# Reference F2 dimension using dimension object
spec_ref = reference(spec, F2Dim, 8.2 => 8.5)

# Reference multiple dimensions simultaneously
spec_ref = reference(spec, [1, 2], [4.7, 120.0] => [0.0, 118.0])
```

See also [`add_offset`](@ref).
"""
function reference(spec, axis, shift_pair::Pair)
    old_shift, new_shift = shift_pair
    offset = new_shift - old_shift
    return add_offset(spec, axis, offset)
end

function reference(spec, axes, shift_pair::Pair{<:AbstractVector, <:AbstractVector})
    old_shifts, new_shifts = shift_pair
    
    if length(axes) != length(old_shifts) || length(old_shifts) != length(new_shifts)
        throw(NMRToolsError("reference: axes, old_shifts, and new_shifts must have the same length"))
    end
    
    result = spec
    for (axis, old_shift, new_shift) in zip(axes, old_shifts, new_shifts)
        offset = new_shift - old_shift
        result = add_offset(result, axis, offset)
    end
    
    return result
end

"""
    detect_nucleus(spec, axis)

Attempt to detect the nucleus type for a given axis based on metadata and chemical shift range.

Returns a `Nucleus` enum value or `nothing` if detection fails.
"""
function detect_nucleus(spec, axis)
    dim_no = if axis isa Int
        axis
    else
        findfirst(d -> d isa axis, dims(spec))
    end
    
    if isnothing(dim_no)
        return nothing
    end
    
    # Try to get from metadata first
    if haskey(metadata(spec, dim_no), :label)
        label = metadata(spec, dim_no)[:label]
        if label isa String
            label_upper = uppercase(label)
            if occursin("1H", label_upper) || occursin("H", label_upper)
                return H1
            elseif occursin("13C", label_upper) || occursin("C", label_upper)
                return C13
            elseif occursin("15N", label_upper) || occursin("N", label_upper)
                return N15
            elseif occursin("19F", label_upper) || occursin("F", label_upper)
                return F19
            elseif occursin("31P", label_upper) || occursin("P", label_upper)
                return P31
            end
        end
    end
    
    # Try to detect from chemical shift range if metadata detection failed
    axis_data = data(dims(spec, dim_no))
    if !isempty(axis_data)
        min_shift = minimum(axis_data)
        max_shift = maximum(axis_data)
        range_span = max_shift - min_shift
        
        # Typical chemical shift ranges for different nuclei
        if min_shift >= -5 && max_shift <= 20 && range_span < 30
            return H1  # 1H typically 0-15 ppm
        elseif min_shift >= 0 && max_shift <= 250 && range_span > 50
            return C13  # 13C typically 0-220 ppm
        elseif min_shift >= 70 && max_shift <= 180 && range_span > 30
            return N15  # 15N typically 100-140 ppm for proteins
        elseif min_shift >= -200 && max_shift <= 0 && range_span > 50
            return F19  # 19F typically negative values
        elseif min_shift >= -50 && max_shift <= 50 && range_span > 20
            return P31  # 31P typically around 0 ppm
        end
    end
    
    return nothing
end

"""
    water_chemical_shift(temperature_celsius)

Calculate the chemical shift of water based on temperature using the formula:
δ(H₂O) = 7.83 - T/96.9

where T is temperature in °C.

# Arguments
- `temperature_celsius`: Temperature in degrees Celsius

# Returns
- Chemical shift of water in ppm

# Reference
- Gottlieb, H. E.; Kotlyar, V.; Nudelman, A. J. Org. Chem. 1997, 62, 7512-7515.
"""
function water_chemical_shift(temperature_celsius)
    return 7.83 - temperature_celsius / 96.9
end

"""
    reference_heteronuclear(spectrum, h1_axis, h1_reference_shift; keyword_args...)

Reference all frequency axes in a spectrum based on a single 1H reference.

This function references the 1H dimension first, then calculates the appropriate
referencing for all other frequency dimensions using XI ratios. This enables
simultaneous referencing of heteronuclear experiments.

# Arguments
- `spectrum`: NMRData object to reference
- `h1_axis`: The 1H axis (integer index or dimension object like F1Dim)
- `h1_reference_shift`: The desired chemical shift for the 1H reference (e.g., 0.0 for DSS)
- `reference_standard`: Reference standard (:TMS, :DSS, or :auto to detect)
- `temperature`: Temperature in °C for water referencing (if applicable)
- `h1_old_shift`: Current position of the 1H reference peak (default 4.7 for water)
- `aqueous`: Whether aqueous conditions (:auto, true, false)
- `verbose`: Whether to print informational messages

# Examples
```julia
# Reference a 1H,15N HSQC with DSS at 0.0 ppm
spec_ref = reference_heteronuclear(spec, 1, 0.0, reference_standard=:DSS)

# Reference with water at 25°C (automatically detects aqueous conditions)
spec_ref = reference_heteronuclear(spec, 1, 0.0, temperature=25)

# Reference everything relative to TMS
spec_ref = reference_heteronuclear(spec, F1Dim, 0.0, reference_standard=:TMS)
```

See also [`reference`](@ref), [`xi_ratio`](@ref), [`water_chemical_shift`](@ref).
"""
function reference_heteronuclear(spectrum, h1_axis, h1_reference_shift; 
                                reference_standard::Symbol=:auto, 
                                temperature::Union{Nothing,Real}=nothing,
                                h1_old_shift::Real=4.7, 
                                aqueous::Union{Symbol,Bool}=:auto, 
                                verbose::Bool=true)
    
    # Determine reference standard
    if reference_standard == :auto
        if aqueous == :auto
            # Try to detect from acquisition parameters or use water detection
            if temperature !== nothing
                reference_standard = :DSS
                aqueous = true
                if verbose
                    @info "Detected aqueous conditions from temperature parameter. Using DSS reference standard."
                end
            else
                # Default to DSS for now - could add more sophisticated detection
                reference_standard = :DSS
                aqueous = true
                if verbose
                    @info "No clear indication of solvent type. Defaulting to DSS (aqueous conditions)."
                end
            end
        elseif aqueous == true || aqueous == :DSS
            reference_standard = :DSS
        elseif aqueous == false || aqueous == :TMS
            reference_standard = :TMS
        end
    end
    
    # Handle water temperature correction if specified
    if temperature !== nothing
        water_shift = water_chemical_shift(temperature)
        if verbose
            @info "Temperature correction: Water chemical shift at $(temperature)°C is $(round(water_shift, digits=3)) ppm"
        end
        if h1_old_shift ≈ 4.7  # Default water position from Bruker
            h1_old_shift = water_shift
            if verbose
                @info "Adjusting reference position from 4.7 ppm to $(round(water_shift, digits=3)) ppm based on temperature"
            end
        end
    end
    
    # First, reference the 1H dimension
    result = reference(spectrum, h1_axis, h1_old_shift => h1_reference_shift)
    h1_offset = h1_reference_shift - h1_old_shift
    
    if verbose
        @info "Applied 1H referencing: $(h1_old_shift) ppm → $(h1_reference_shift) ppm (offset: $(round(h1_offset, digits=3)) ppm)"
    end
    
    # Now reference all other frequency dimensions using XI ratios
    for i in 1:length(result.dims)
        if i == (h1_axis isa Int ? h1_axis : findfirst(d -> d isa h1_axis, dims(result)))
            continue  # Skip the 1H dimension we already referenced
        end
        
        dim = dims(result, i)
        if dim isa FrequencyDimension
            nucleus = detect_nucleus(result, i)
            if nucleus !== nothing && nucleus != H1
                try
                    xi = xi_ratio(nucleus, reference_standard=reference_standard)
                    hetero_offset = h1_offset / xi
                    result = add_offset(result, i, hetero_offset)
                    
                    if verbose
                        @info "Applied heteronuclear referencing for $(nucleus): XI ratio = $(round(xi, digits=6)), offset = $(round(hetero_offset, digits=3)) ppm"
                    end
                catch e
                    if verbose
                        @warn "Could not apply heteronuclear referencing for axis $i (nucleus: $nucleus): $e"
                    end
                end
            elseif verbose && nucleus === nothing
                @warn "Could not detect nucleus type for axis $i - skipping heteronuclear referencing"
            end
        end
    end
    
    if verbose
        @info "Heteronuclear referencing complete using $(reference_standard) standard"
    end
    
    return result
end