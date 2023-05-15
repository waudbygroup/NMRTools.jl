"""
    AbstractNMRData <: DimensionalData.AbstractDimArray

Abstract supertype for objects that wrap an array of NMR data, and metadata about
its contents.

`AbstractNMRData`s inherit from [`AbstractDimArray`]($DDarraydocs)
from DimensionalData.jl. They can be indexed as regular Julia arrays or with
DimensionalData.jl [`Dimension`]($DDdimdocs)s.
"""
abstract type AbstractNMRData{T,N,D,A} <: AbstractDimArray{T,N,D,A} end

# Base methods #####################################################################################

function Base.:(==)(A::AbstractNMRData{T,N}, B::AbstractNMRData{T,N}) where {T,N}
    return size(A) == size(B) && all(A .== B)
end

Base.parent(A::AbstractNMRData) = A.data
# NOTE In the future, specialise for file-based data (see Rasters.jl/array.jl)
Base.Array(A::AbstractNMRData) = Array(parent(A))
Base.collect(A::AbstractNMRData) = collect(parent(A))
# TODO define similar() to inherit metadata appropriately

# Interface methods ################################################################################

"""
    missingval(x)

Returns the value representing missing data in the dataset
"""
function missingval end
missingval(x) = missing
missingval(A::AbstractNMRData) = A.missingval

# DimensionalData methods ##########################################################################

# Rebuild types of AbstractNMRData
function DD.rebuild(X::A, data, dims::Tuple, refdims, name,
                    metadata=metadata(X), missingval=missingval(X)) where {A<:AbstractNMRData}
    # HACK use A.name.wrapper to return the type (i.e. constructor) stripped of parameters.
    # This may not be a stable feature. See discussions:
    # - https://discourse.julialang.org/t/get-generic-constructor-of-parametric-type/57189/5
    # - https://github.com/JuliaObjects/ConstructionBase.jl/blob/master/src/constructorof.md
    return (A.name.wrapper)(data, dims, refdims, name, metadata, missingval)
end

function DD.rebuild(A::AbstractNMRData;
                    data=parent(A), dims=dims(A), refdims=refdims(A), name=name(A),
                    metadata=metadata(A), missingval=missingval(A))
    return rebuild(A, data, dims, refdims, name, metadata, missingval)
end

# NOTE In the future, specialise for file-based data (see Rasters.jl/array.jl)
function DD.modify(f, A::AbstractNMRData)
    newdata = f(parent(A))
    size(newdata) == size(A) ||
        error("$f returns an array with size $(size(newdata)) when the original size was $(size(A))")
    return rebuild(A, newdata)
end

# function DD.DimTable(As::Tuple{<:AbstractNMRData,Vararg{<:AbstractNMRData}}...)
#     return DD.DimTable(DimStack(map(read, As...)))
# end

# Concrete implementation ##########################################################################

"""
    NMRData <: AbstractNMRData
    NMRData(A::AbstractArray{T,N}, dims; kw...)
    NMRData(A::AbstractNMRData; kw...)

A generic [`AbstractNMRData`](@ref) for NMR array data. It holds memory-backed arrays.

# Keywords

- `dims`: `Tuple` of `NMRDimension`s for the array.
- `name`: `Symbol` name for the array, which will also retreive named layers if `NMRData`
    is used on a multi-layered file like a NetCDF.
- `missingval`: value representing missing data, normally detected from the file. Set manually
    when you know the value is not specified or is incorrect. This will *not* change any
    values in the NMRData, it simply assigns which value is treated as missing. To replace all of
    the missing values in the NMRData, use [`replace_missing`](@ref).
- `metadata`: `ArrayMetadata` object for the array, or `NoMetadata()`.

# Internal Keywords

In some cases it is possible to set these keywords as well.

- `data`: can replace the data in an `AbstractNMRData`

- `refdims`: `Tuple of` position `Dimension`s the array was sliced from, defaulting to `()`.
"""
struct NMRData{T,N,D<:Tuple,R<:Tuple,A<:AbstractArray{T,N},Na,Me,Mi} <:
       AbstractNMRData{T,N,D,A}
    data::A
    dims::D
    refdims::R
    name::Na
    metadata::Me
    missingval::Mi
end

function NMRData(A::AbstractArray, dims::Tuple;
                 refdims=(), name=Symbol(""), metadata=defaultmetadata(NMRData), missingval=missing)
    return NMRData(A, Dimensions.format(dims, A), refdims, name, metadata, missingval)
end

function NMRData(A::AbstractArray{<:Any,1}, dims::Tuple{<:Dimension,<:Dimension,Vararg};
                 kw...)
    return NMRData(reshape(A, map(length, dims)), dims; kw...)
end

# function NMRData(table, dims::Tuple; name=first(_not_a_dimcol(table, dims)), kw...)
#     Tables.istable(table) ||
#         throw(ArgumentError("First argument to `NMRData` is not a table or other known object: $table"))
#     isnothing(name) && throw(UndefKeywordError(:name))
#     cols = Tables.columns(table)
#     A = reshape(cols[name], map(length, dims))
#     return NMRData(A, dims; name, kw...)
# end

NMRData(A::AbstractArray; dims, kw...) = NMRData(A, dims; kw...)

function NMRData(A::AbstractDimArray;
                 data=parent(A), dims=dims(A), refdims=refdims(A),
                 name=name(A), metadata=metadata(A), missingval=missingval(A), kw...)
    return NMRData(data, dims; refdims, name, metadata, missingval, kw...)
end

# function NMRData(filename::AbstractString, dims::Tuple{<:Dimension,<:Dimension,Vararg};
#                  kw...)
#     return NMRData(filename; dims, kw...)
# end

# TODO ??
# DD.dimconstructor(::Tuple{<:Dimension{<:AbstractProjected},Vararg{<:Dimension}}) = NMRData


# Getters ##########################################################################################
data(A::NMRData) = A.data
data(A::NMRData, dim) = data(dims(A, dim))

# Methods ##########################################################################################
"""
    scale(d::AbstractNMRData)

Return a scaling factor for the data combining the number of scans, receiver gain, and, if
specified, the sample concentration.
"""
function scale(d::AbstractNMRData)
    # get ns, rg, and concentration, with safe defaults in case missing
    ns = get(metadata(d), :ns, 1)
    rg = get(metadata(d), :rg, 1)
    conc = get(metadata(d), :conc, 1)
    return ns * rg * conc
end
