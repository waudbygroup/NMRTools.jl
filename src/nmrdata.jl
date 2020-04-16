# additional metadata accessor functions
import DimensionalData.metadata, Base.getindex
metadata(A::DimensionalArray, key::Symbol) = get(metadata(A), key, missing)
metadata(A::DimensionalArray, dim, key::Symbol) = get(metadata(A, dim), key, missing)
getindex(A::DimensionalArray, key::Symbol) = get(metadata(A), key, missing)
getindex(A::DimensionalArray, dim, key::Symbol) = get(metadata(A, dim), key, missing)

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
Base.@pure function SimpleTraits.trait(t::Type{HasPseudoDimension{D}}) where D<:DimensionalArray{T,N,A} where {T,N,A}
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
function haspseudodimension(spectrum::DimensionalArray{T,N,A}) where {T,N,A}
    any(map(dim->(typeintersect(dim, TimeDim) != Union{}), A.parameters))
end



"""
    isnmrdata(A)

Return true if `A` is NMRTools-compatible NMR data. This is indicated by the existence
field, `:NMRTools`, within the metadata.
"""
# isnmrdata(X) = false
# isnmrdata(X::DimensionalArray) = @show get(metadata(X), :NMRTools, false)
#
# @traitdef IsNMRData{X}
# @traitimpl IsNMRData{X} <- isnmrdata(X)
#
# function isnmrdata(x::DimensionalArray)
#    println("isnmrdata(x::DimensionalArray) running")
#    try
#       get(metadata(x),:NMRTools, false)
#     catch
#         false
#     end
# end
