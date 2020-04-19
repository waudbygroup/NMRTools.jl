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
NMRData(A::AbstractArray, dims, name::String=""; refdims=(), metadata=Dict()) =
    NMRData(A, DimensionalData.formatdims(A, DimensionalData._to_tuple(dims)), refdims, name, metadata)
#_to_tuple(t::T where T <: Tuple) = t
#_to_tuple(t) = tuple(t)

# Getters
refdims(A::NMRData) = A.refdims
data(A::NMRData) = A.data
name(A::NMRData) = A.name

# get axis values
xval(A::NMRData) = dims(A,X).val
yval(A::NMRData) = dims(A,Y).val
zval(A::NMRData) = dims(A,Z).val
tval(A::NMRData) = dims(A,Ti).val

# metadata accessor functions
metadata(A::NMRData) = A.metadata
metadata(A::NMRData, key::Symbol) = get(metadata(A), key, missing)
metadata(A::NMRData, dim, key::Symbol) = get(metadata(A, dim), key, missing)
getindex(A::NMRData, key::Symbol) = get(metadata(A), key, missing)
getindex(A::NMRData, dim, key::Symbol) = get(metadata(A, dim), key, missing)
setindex!(A::NMRData, v, key::Symbol) = setindex!(metadata(A), v, key)  #(metadata(A)[key] = v)
setindex!(A::NMRData, v, dim, key::Symbol) = setindex!(metadata(A,dim), v, key)  #(metadata(A, dim)[key] = v)

# acqus accessor functions
acqus(A::NMRData) = get(A.metadata, :acqus, missing)
acqus(A::NMRData, key::String) = ismissing(acqus(A)) ? missing : get(acqus(A), uppercase(key), missing)
acqus(A::NMRData, key::Symbol) = acqus(A, string(key))
acqus(A::NMRData, key, index::Int) = acqus(A, key)[index]

# label accessor functions
label(A::NMRData) = get(metadata(A),:label,"")
label(A::NMRData, dim) = get(metadata(A, dim),:label,"")
label!(A::NMRData, labeltext::AbstractString) = (metadata(A)[:label] = labeltext)
label!(A::NMRData, dim, labeltext::AbstractString) = (metadata(A, dim)[:label] = labeltext)


# AbstractDimensionalArray interface
@inline rebuild(A::NMRData, data::AbstractArray, dims::Tuple,
                refdims::Tuple, name::AbstractString, metadata) =
    NMRData(data, dims, refdims, name, metadata)

# Array interface (AbstractDimensionalArray takes care of everything else)
Base.@propagate_inbounds Base.setindex!(A::NMRData, x, I::Vararg{DimensionalData.StandardIndices}) =
    setindex!(data(A), x, I...)



function settvals(A::NMRData, tvals)
    haspseudodimension(A) || throw(NMRToolsException("cannot set t values: data does not have a non-frequency dimension."))

    taxis = Ti(tvals, metadata=metadata(A,Ti))
    # two cases to consider: (x, t) or (x, y, t)
    if ndims(A) == 2
        newdims = (dims(A,X), taxis)
    else
        newdims = (dims(A,X), dims(A,Y), taxis)
    end
    NMRData(A.data, newdims, A.name, refdims=A.refdims, metadata=A.metadata)
end



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



"""
    scale(d::NMRData)

Return a scaling factor for the data combining the number of scans, receiver gain, and, if
specified, the sample concentration.
"""
function scale(d::NMRData)
    # get ns, rg, and concentration, with safe defaults in case missing
    ns = get(metadata(d), :ns, 1)
    rg = get(metadata(d), :rg, 1)
    conc = get(metadata(d), :conc, 1)
    return ns * rg * conc
end
