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
    metadata(new_spec, dim_no)[:offsetppm] += offsetppm
    metadata(new_spec, dim_no)[:offsethz] += offsetppm * metadata(new_spec, dim_no, :bf)
    metadata(new_spec, dim_no)[:sf] += offsetppm * metadata(new_spec, dim_no, :bf) / 1e6

    return new_spec
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
    _find_1h_axis(spec)

Find the first 1H axis in the spectrum. Returns the axis number or nothing if not found.
"""
function _find_1h_axis(spec)
    for i in 1:length(dims(spec))
        if dims(spec, i) isa FrequencyDimension
            nucleus = detect_nucleus(spec, i)
            if nucleus == H1
                return i
            end
        end
    end
    return nothing
end

"""
    _detect_solvent(spec)

Detect whether the spectrum was acquired under aqueous conditions by checking
the solvent parameter in acquisition data.

Returns :aqueous, :organic, or :unknown.
"""
function _detect_solvent(spec)
    solvent = acqus(spec, :solvent)
    if !ismissing(solvent) && solvent isa String
        solvent_upper = uppercase(solvent)
        if occursin("H2O", solvent_upper) || occursin("D2O", solvent_upper)
            return :aqueous
        else
            return :organic
        end
    end
    return :unknown
end

"""
    reference(spec; kwargs...)
    reference(spec, axis; kwargs...)  
    reference(spec, axis, old_shift => new_shift; kwargs...)
    reference(spec, axes, old_shifts => new_shifts; kwargs...)

Reference frequency axes in NMR spectra with intelligent defaults and heteronuclear support.

# Single argument form - ultimate convenience
- `reference(spec)`: Finds 1H axis automatically, applies water referencing, propagates to all dimensions

# Two argument forms - axis-specific referencing
- `reference(spec, axis)`: Water referencing on specified axis with propagation
- `reference(spec, axis; propagate=false)`: Water referencing without propagation

# Explicit shift referencing
- `reference(spec, axis, old_shift => new_shift)`: Reference specific chemical shifts
- `reference(spec, axes, old_shifts => new_shifts)`: Multiple axes simultaneously

# Arguments
- `spec`: NMRData object to reference
- `axis`: Axis to reference (integer index or dimension type like F1Dim)
- `axes`: Vector of axes for multi-axis referencing
- `old_shift => new_shift`: Pair specifying current and desired chemical shifts
- `old_shifts => new_shifts`: Vectors of current and desired chemical shifts

# Keyword Arguments
- `propagate::Bool=true`: Whether to apply heteronuclear referencing to other dimensions
- `reference_standard::Symbol=:auto`: Reference standard (:TMS, :DSS, or :auto for detection)
- `temperature::Union{Nothing,Real}=nothing`: Temperature in Kelvin (default: parse from acqus(:te))
- `verbose::Bool=true`: Whether to print informational messages

# Examples
```julia
# Ultimate convenience - automatic detection and water referencing
reference(spec)

# Water referencing with axis control  
reference(spec, F1Dim)
reference(spec, F1Dim, propagate=false)

# Explicit shift referencing
reference(spec, F1Dim, -0.07 => 0.0)  # correct small offset
reference(spec, F1Dim, 4.70 => 4.85)  # reference water to literature value

# Multiple axes simultaneously
reference(spec, [F1Dim, F2Dim], [4.7, 120.0] => [0.0, 118.0])
```

See also [`add_offset`](@ref), [`xi_ratio`](@ref), [`water_chemical_shift`](@ref).
"""
function reference(spec; 
                  propagate::Bool=true,
                  reference_standard::Symbol=:auto,
                  temperature::Union{Nothing,Real}=nothing,
                  verbose::Bool=true)
    
    # Find 1H axis automatically
    h1_axis = _find_1h_axis(spec)
    if h1_axis === nothing
        throw(NMRToolsError("No 1H axis found in spectrum for automatic referencing"))
    end
    
    if verbose
        axis_type = h1_axis == 1 ? "F1Dim" : h1_axis == 2 ? "F2Dim" : "F$(h1_axis)Dim"
        @info "Detected 1H axis: $axis_type"
    end
    
    # Apply water referencing to 1H axis
    return reference(spec, h1_axis; 
                    propagate=propagate, 
                    reference_standard=reference_standard, 
                    temperature=temperature, 
                    verbose=verbose)
end

function reference(spec, axis; 
                  propagate::Bool=true,
                  reference_standard::Symbol=:auto,
                  temperature::Union{Nothing,Real}=nothing,
                  verbose::Bool=true)
                  
    # Get temperature for water chemical shift calculation
    temp_K = if temperature !== nothing
        temperature
    else
        temp_acqus = acqus(spec, :te)
        if !ismissing(temp_acqus)
            temp_acqus  # Assuming acqus(:te) returns temperature in Kelvin
        else
            if verbose
                @warn "Temperature not found in acquisition parameters and not provided. Cannot apply temperature-dependent water referencing."
            end
            return spec  # Return unchanged if no temperature available
        end
    end
    
    # Detect reference standard based on solvent
    if reference_standard == :auto
        solvent_type = _detect_solvent(spec)
        if solvent_type == :aqueous
            reference_standard = :DSS
            if verbose
                @info "Detected aqueous conditions from solvent parameter. Using DSS reference standard."
            end
        elseif solvent_type == :organic
            reference_standard = :TMS
            if verbose
                @info "Detected organic conditions from solvent parameter. Using TMS reference standard."
            end
        else
            # Default to DSS if uncertain
            reference_standard = :DSS
            if verbose
                @info "Solvent type unclear. Defaulting to DSS (aqueous conditions)."
            end
        end
    end
    
    # Calculate water chemical shift at the given temperature
    water_shift = water_chemical_shift(temp_K)
    if verbose
        @info "Temperature correction: Water chemical shift at $(round(temp_K - 273.15, digits=1))°C is $(round(water_shift, digits=3)) ppm"
    end
    
    # Reference water to 0.0 ppm
    result = reference(spec, axis, water_shift => 0.0; 
                      propagate=propagate, 
                      reference_standard=reference_standard, 
                      verbose=verbose)
    
    return result
end

function reference(spec, axis, shift_pair::Pair; 
                  propagate::Bool=true,
                  reference_standard::Symbol=:auto,
                  verbose::Bool=true)
                  
    old_shift, new_shift = shift_pair
    
    # First apply the basic referencing
    result = add_offset(spec, axis, new_shift - old_shift)
    
    if verbose
        @info "Applied referencing: $(old_shift) ppm → $(new_shift) ppm (offset: $(round(new_shift - old_shift, digits=3)) ppm)"
    end
    
    # Apply heteronuclear referencing if requested
    if propagate
        # Get the axis number for comparison
        target_axis_no = if axis isa Int
            axis
        else
            findfirst(d -> d isa axis, dims(result))
        end
        
        # Determine reference standard if auto
        if reference_standard == :auto
            solvent_type = _detect_solvent(spec)
            reference_standard = solvent_type == :organic ? :TMS : :DSS
            if verbose
                std_name = reference_standard == :TMS ? "TMS (organic)" : "DSS (aqueous)"
                @info "Using $(std_name) standard for heteronuclear referencing"
            end
        end
        
        h1_offset = new_shift - old_shift
        
        # Apply heteronuclear referencing to other frequency dimensions
        for i in 1:length(dims(result))
            if i == target_axis_no || !(dims(result, i) isa FrequencyDimension)
                continue  # Skip the referenced axis and non-frequency dimensions
            end
            
            nucleus = detect_nucleus(result, i)
            if nucleus !== nothing && nucleus != H1
                try
                    xi = xi_ratio(nucleus, reference_standard=reference_standard)
                    hetero_offset = h1_offset / xi
                    result = add_offset(result, i, hetero_offset)
                    
                    if verbose
                        axis_name = i == 1 ? "F1Dim" : i == 2 ? "F2Dim" : "F$(i)Dim"
                        @info "Applied heteronuclear referencing for $(axis_name) ($(nucleus)): XI ratio = $(round(xi, digits=6)), offset = $(round(hetero_offset, digits=3)) ppm"
                    end
                catch e
                    if verbose
                        axis_name = i == 1 ? "F1Dim" : i == 2 ? "F2Dim" : "F$(i)Dim"
                        @warn "Could not apply heteronuclear referencing for $(axis_name) (nucleus: $nucleus): $e"
                    end
                end
            elseif verbose && nucleus === nothing
                axis_name = i == 1 ? "F1Dim" : i == 2 ? "F2Dim" : "F$(i)Dim"
                @warn "Could not detect nucleus type for $(axis_name) - skipping heteronuclear referencing"
            end
        end
        
        if verbose
            @info "Heteronuclear referencing complete using $(reference_standard) standard"
        end
    end
    
    return result
end

function reference(spec, axes, shift_pair::Pair{<:AbstractVector, <:AbstractVector}; kwargs...)
    old_shifts, new_shifts = shift_pair
    
    if length(axes) != length(old_shifts) || length(old_shifts) != length(new_shifts)
        throw(NMRToolsError("reference: axes, old_shifts, and new_shifts must have the same length"))
    end
    
    result = spec
    for (axis, old_shift, new_shift) in zip(axes, old_shifts, new_shifts)
        # Apply referencing without propagation for multi-axis case to avoid conflicts
        result = reference(result, axis, old_shift => new_shift; propagate=false, kwargs...)
    end
    
    return result
end