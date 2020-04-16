# Concrete implementation ######################################################

"""
    NMRData(data, dims, refdims, name)

The main structure for holding MNR data. A subtype of `AbstractDimensionalArray`, which
maintains and updates its dimensions through transformations and moves dimensions to
`refdims` after reducing operations (like e.g. `mean`).
"""
struct NMRData{T,N,D<:Tuple,R<:Tuple,A<:AbstractArray{T,N},Na<:AbstractString,Me} <: AbstractDimensionalArray{T,N,D,A}
    data::A
    dims::D
    refdims::R
    name::Na
    metadata::Me
    function NMRData(data::A, dims::D, refdims::R, name::Na, metadata::Me
                             ) where {D,R,A<:AbstractArray{T,N},Na,Me} where {T,N}
        map(dims, size(data)) do d, s
            if !(val(d) isa Colon) && length(d) != s
                throw(DimensionMismatch(
                    "dims must have same size as data. This was not true for $dims and size $(size(data)) $(A)."
                ))
            end
        end
        new{T,N,D,R,A,Na,Me}(data, dims, refdims, name, metadata)
    end
end
"""
    NMRData(data, dims::Tuple [, name::String]; refdims=(), metadata=nothing)

Constructor with optional `name`, and keyword `refdims` and `metadata`.

Example:
```julia
using Dates, DimensionalData

ti = (Ti(DateTime(2001):Month(1):DateTime(2001,12)),
x = X(10:10:100))
A = NMRData(rand(12,10), (ti, x), "example")

julia> A[X(Near([12, 35])), Ti(At(DateTime(2001,5)))];

julia> A[Near(DateTime(2001, 5, 4)), Between(20, 50)];
```
"""
NMRData(A::AbstractArray, dims, name::String=""; refdims=(), metadata=nothing) =
    NMRData(A, DimensionalData.formatdims(A, DimensionalData._to_tuple(dims)), refdims, name, metadata)
#_to_tuple(t::T where T <: Tuple) = t
#_to_tuple(t) = tuple(t)

# Getters
import DimensionalData.refdims, DimensionalData.data, DimensionalData.name, DimensionalData.metadata, DimensionalData.label, DimensionalData.rebuild
refdims(A::NMRData) = A.refdims
data(A::NMRData) = A.data
name(A::NMRData) = A.name
metadata(A::NMRData) = A.metadata
label(A::NMRData) = name(A)

# AbstractDimensionalArray interface
@inline rebuild(A::NMRData, data::AbstractArray, dims::Tuple,
                refdims::Tuple, name::AbstractString, metadata) =
    NMRData(data, dims, refdims, name, metadata)

# Array interface (AbstractDimensionalArray takes care of everything else)
Base.@propagate_inbounds Base.setindex!(A::NMRData, x, I::Vararg{DimensionalData.StandardIndices}) =
    setindex!(data(A), x, I...)



## additional metadata accessor functions
import Base.getindex
metadata(A::NMRData, key::Symbol) = get(metadata(A), key, missing)
metadata(A::NMRData, dim, key::Symbol) = get(metadata(A, dim), key, missing)
getindex(A::NMRData, key::Symbol) = get(metadata(A), key, missing)
getindex(A::NMRData, dim, key::Symbol) = get(metadata(A, dim), key, missing)

"""
    @traitdef HasPseudoDimension{D}

A trait indicating whether the data object has a non-frequency domain dimension.

# Example

```julia
@traitfn f(x::X) where {X; HasPseudoDimension{X}} = "Fake!"
@traitfn f(x::X) where {X; Not{HasPseudoDimension{X}}} = "The real deal!"
```
"""
@traitdef HasPseudoDimension{D}

# adapted from expansion of @traitimpl
# this is a pure function because it only depends on the type definition of NMRData
Base.@pure function SimpleTraits.trait(t::Type{HasPseudoDimension{D}}) where D<:NMRData{T,N,A} where {T,N,A}
    any(map(dim->(typeintersect(dim, TimeDim) != Union{}), A.parameters)) ? HasPseudoDimension{D} : Not{HasPseudoDimension{D}}
end



"""
    haspseudodimension(spectrum)

Return true if the spectrum contains a non-frequency domain dimension.

# Example

```julia
julia> y2=loadnmr("exampledata/2D_HN/test.ft2");
julia> haspseudodimension(y2)
false
julia> y3=loadnmr("exampledata/pseudo3D_HN_R2/ft/test%03d.ft2");
julia> haspseudodimension(y3)
true
```
"""
function haspseudodimension(spectrum::NMRData{T,N,A}) where {T,N,A}
    any(map(dim->(typeintersect(dim, TimeDim) != Union{}), A.parameters))
end
