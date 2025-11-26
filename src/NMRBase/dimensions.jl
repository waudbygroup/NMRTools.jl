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
getω(ax::FrequencyDimension) = 2π * ax[:bf] * (data(ax) .- ax[:offsetppm]) * 1e-6

"""
    getω(axis, δ)

Return the offset (in rad/s) for a chemical shift (or list of shifts) on a frequency axis.
"""
getω(ax::FrequencyDimension, δ) = 2π * ax[:bf] * (δ .- ax[:offsetppm]) * 1e-6

"""
    shiftdim!(data::NMRData, dim_ref, offset)

Add an offset to a frequency dimension in an NMRData object. The dimension can be specified as a numerical index or an object like `F1Dim`.
The metadata is copied using `replacedimension`, and an entry is added or updated in the dimension metadata to record the offset change.
"""
function shiftdim(spec, dim_ref, offsetppm)
    dim_no = if dim_ref isa Int
        dim_ref
    else
        findfirst(d -> d isa dim_ref, dims(spec))
    end
    # check that dim_no is valid (not nothing, and within the range of dims)
    if isnothing(dim_no) || dim_no > length(spec.dims) || dim_no < 1
        throw(NMRToolsError("shiftdim: Dimension $dim_ref not found in NMRData object"))
    end
    # check that the dimension is a FrequencyDimension
    if !(dims(spec, dim_no) isa FrequencyDimension)
        throw(NMRToolsError("shiftdim: Dimension $dim_ref is not a FrequencyDimension"))
    end

    dim = dims(spec, dim_no)

    new_data = data(dim) .+ offsetppm
    md = deepcopy(metadata(dim))
    if dim_no == 1
        newdim = F1Dim(new_data; metadata=md)
    elseif dim_no == 2
        newdim = F2Dim(new_data; metadata=md)
    elseif dim_no == 3
        newdim = F3Dim(new_data; metadata=md)
    end
    new_spec = replacedimension(spec, dim_no, newdim)

    if :referenceoffset ∉ keys(metadata(new_spec, dim_no))
        metadata(new_spec, dim_no)[:referenceoffset] = offsetppm
    else
        metadata(new_spec, dim_no)[:referenceoffset] += offsetppm
    end

    # adjust other metadata
    metadata(new_spec, dim_no)[:offsetppm] += offsetppm
    metadata(new_spec, dim_no)[:offsethz] += 1e-6 * offsetppm *
                                             metadata(new_spec, dim_no, :bf)
    metadata(new_spec, dim_no)[:sf] += 1e-6 * offsetppm * metadata(new_spec, dim_no, :bf)

    return new_spec
end