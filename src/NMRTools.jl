module NMRTools

using Lazy
using Reexport
using SimpleTraits
@reexport using DimensionalData

#
# struct NMRData{T,N,S<:AbstractDimensionalArray} <: AbstractArray{T,N}
#     parent::S
#     metadata::Dict{Any,Any}
# end
#
# NMRData(data::AbstractArray{T,N}, metadata = Dict{Any,Any}()) where {T,N} =
#     NMRData{T,N,typeof(data)}(data, metadata)
#
# # forward array interface methods to contained data
# @forward NMRData.parent (Base.size, Base.length, Base.getindex, Base.iterate, DimensionalData.dims)
#
# # define additional methods for metadata
# metadata(d::NMRData) = getfield(d, :metadata)
# metadata(d::NMRData, axis::Int) = metadata(dims(d, axis))
# metadata(d::NMRData, axis::Union{Dimension,Type{<:Dimension}}) = metadata(dims(d, axis))
#
# # default constructors for dimensions to create empty dictionarys for metadata
# X(val=:) = X(val, UnknownGrid(), Dict{Any,Any}())
# Y(val=:) = Y(val, UnknownGrid(), Dict{Any,Any}())
# Z(val=:) = Z(val, UnknownGrid(), Dict{Any,Any}())
# Ti(val=:) = Ti(val, UnknownGrid(), Dict{Any,Any}())

export NMRData
export HasPseudoDimension
export ndim#, X, Y, Z, Ti

include("nmrdata.jl")


end # module
