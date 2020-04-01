import DimensionalData: metadata # need to extend to cover general metadata calls

"""
    NMRData(data, metadata)

The main structure for holding NMR spectral data.
"""
struct NMRData{T,N,S<:AbstractArray} <: AbstractArray{T,N}
    parent::S
    metadata::Dict{Any,Any}
end

NMRData(data::AbstractArray{T,N}, metadata = Dict{Any,Any}()) where {T,N} =
    NMRData{T,N,typeof(data)}(data, metadata)
NMRData(data::AbstractArray, dims::Tuple, metadata = Dict{Any,Any}()) =
    NMRData(DimensionalArray(data, dims), metadata)

# forward array interface methods to contained data
@forward NMRData.parent (Base.size, Base.length, Base.getindex, Base.iterate, DimensionalData.dims)

# define additional methods for metadata
metadata(d::NMRData) = getfield(d, :metadata)
metadata(d::NMRData, axis::Int) = metadata(dims(d, axis))
metadata(d::NMRData, axis::Union{Dimension,Type{<:Dimension}}) = metadata(dims(d, axis))

# default constructors for dimensions to create empty dictionarys for metadata
# X(val) = X(val, UnknownGrid(), Dict{Any,Any}())
# Y(val) = Y(val, UnknownGrid(), Dict{Any,Any}())
# Z(val) = Z(val, UnknownGrid(), Dict{Any,Any}())
# Ti(val) = Ti(val, UnknownGrid(), Dict{Any,Any}())
