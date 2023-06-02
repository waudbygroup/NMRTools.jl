abstract type NMRDimension{T} <: DimensionalData.Dimension{T} end
abstract type FrequencyDimension{T} <: NMRDimension{T} end
abstract type NonFrequencyDimension{T} <: NMRDimension{T} end
abstract type TimeDimension{T} <: NonFrequencyDimension{T} end
# abstract type QuadratureDimension{T} <: NMRDimension{T} end
abstract type UnknownDimension{T} <: NonFrequencyDimension{T} end
abstract type GradientDimension{T} <: NonFrequencyDimension{T} end

# override DimensionalData.Dimensions macro to generate default metadata
macro NMRdim(typ::Symbol, supertyp::Symbol, args...)
    NMRdimmacro(typ, supertyp, args...)
end
function NMRdimmacro(typ, supertype, name::String=string(typ))
    quote
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
            $typ{typeof(val)}(val)
            # @show tmpdim = $typ{typeof(val)}(val)
            # @show newlookup = DimensionalData.Dimensions._format(tmpdim, axes(tmpdim,1))
            # return $typ{typeof(newlookup)}(newlookup)
        end
        function $typ(val::T) where {T<:DimensionalData.Dimensions.LookupArrays.LookupArray}
            # HACK - this would better be replaced with a call to DD.format in the function above
            # e.g.
            # DimensionalData.Dimensions.format(DimensionalData.LookupArrays.val(axH), DimensionalData.LookupArrays.basetypeof(axH), Base.OneTo(11))
            $typ{T}(val)
        end
        $typ() = $typ(:)
        Dimensions.name(::Type{<:$typ}) = $(QuoteNode(Symbol(name)))
        Dimensions.key2dim(::Val{$(QuoteNode(typ))}) = $typ()
    end |> esc
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
data(d::NMRDimension) = d.val.data