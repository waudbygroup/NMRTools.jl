import DimensionalData: metadata # need to extend to cover general metadata calls

"""
    NMRData(data, metadata)

The main structure for holding NMR spectral data.
Access metadata associated with the whole spectrum as `metadata(d)[:field]`, and metadata associated
with invidual dimensions as `metadata(d,X)[:field]`.

# Metadata fields
- `:filename`
- `:pulseprogram`

# Axis metadata fields
- `:swhz`
- `:bf`
- `:offsethz`
- `:window`


"""
struct NMRData{T,N,A<:AbstractArray} <: AbstractArray{T,N}
    parent::A
    metadata::Dict{Any,Any}
end

NMRData(data::AbstractArray{T,N}, metadata = Dict()) where {T,N} =
    NMRData{T,N,typeof(data)}(data, metadata)
NMRData(data::AbstractArray, dims::Tuple, metadata = Dict()) =
    NMRData(DimensionalArray(data, dims), metadata)

# forward array interface methods to contained data
@forward NMRData.parent (Base.size, Base.length, Base.getindex, Base.iterate, DimensionalData.dims)

# define axis functions to include metadata
struct X{T,IM<:IndexMode,M} <: XDim{T,IM,M}
    val::T
    mode::IM
    metadata::M
end
struct Y{T,IM<:IndexMode,M} <: YDim{T,IM,M}
    val::T
    mode::IM
    metadata::M
end
struct Z{T,IM<:IndexMode,M} <: ZDim{T,IM,M}
    val::T
    mode::IM
    metadata::M
end
struct Ti{T,IM<:IndexMode,M} <: TimeDim{T,IM,M}
    val::T
    mode::IM
    metadata::M
end
X(val=:, metadata=Dict()) = X(val, AutoIndex(), metadata)
Y(val=:, metadata=Dict()) = Y(val, AutoIndex(), metadata)
Z(val=:, metadata=Dict()) = Z(val, AutoIndex(), metadata)
Ti(val=:, metadata=Dict()) = Ti(val, AutoIndex(), metadata)
DimensionalData.name(::Type{<:X}) = "X"
DimensionalData.name(::Type{<:Y}) = "Y"
DimensionalData.name(::Type{<:Z}) = "Z"
DimensionalData.name(::Type{<:Ti}) = "T"
DimensionalData.shortname(::Type{<:X}) = "X"
DimensionalData.shortname(::Type{<:Y}) = "Y"
DimensionalData.shortname(::Type{<:Z}) = "Z"
DimensionalData.shortname(::Type{<:Ti}) = "T"


# define additional methods for metadata
metadata(d::NMRData) = getfield(d, :metadata)
metadata(d::NMRData, dim::Int) = metadata(dims(d, dim))
metadata(d::NMRData, dim::Union{Dimension,Type{<:Dimension}}) = metadata(dims(d, dim))

##
# define traits for pseudodimension
@traitdef HasPseudoDimension{D}

# adapted from expansion of @traitimpl
# this is a pure function because it only depends on the type definition of NMRData
Base.@pure function SimpleTraits.trait(t::Type{HasPseudoDimension{D}}) where D<:NMRData{T,N,A} where {T,N,A}
    any(map(dim->(typeintersect(dim, TimeDim) != Union{}), A.parameters[3].parameters)) ? HasPseudoDimension{D} : Not{HasPseudoDimension{D}}
end

# example implementation:
# @traitfn f(x::X) where {X; HasPseudoDimension{X}} = "Fake!"
# @traitfn f(x::X) where {X; Not{HasPseudoDimension{X}}} = "The real deal!"
