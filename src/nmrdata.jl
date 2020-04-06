import DimensionalData: metadata # need to extend to cover general metadata calls

"""
    NMRData(data, metadata)

The main structure for holding NMR spectral data.
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

# redefine axis functions to include metadata
# X(x) = X(x; metadata=Dict())
# Y(x) = Y(x; metadata=Dict())
# Z(x) = Z(x; metadata=Dict())
# Ti(x) = Ti(x; metadata=Dict())

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

##
# number of dimensions
ndim(d::NMRData{T,N,A}) where {T,N,A} = N
