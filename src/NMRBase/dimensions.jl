abstract type NMRDimension{T} <: DimensionalData.Dimension{T} end

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

@NMRdim FrequencyDim NMRDimension
@NMRdim TimeDim NMRDimension
@NMRdim UnknownDim NMRDimension
# @NMRdim QuadratureDim NMRDimension
# @NMRdim GradientDim NMRDimension
# @NMRdim SpatialDim NMRDimension


# Getters ########
data(d::NMRDimension) = d.val.data