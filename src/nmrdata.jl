# fix for DimensionalData plotting bug
#val(x::T) where {T<:Dict} = x

# define traits for pseudodimension
@traitdef HasPseudoDimension{D}

# adapted from expansion of @traitimpl
# this is a pure function because it only depends on the type definition of NMRData
Base.@pure function SimpleTraits.trait(t::Type{HasPseudoDimension{D}}) where D<:DimensionalArray{T,N,A} where {T,N,A}
    any(map(dim->(typeintersect(dim, TimeDim) != Union{}), A.parameters)) ? HasPseudoDimension{D} : Not{HasPseudoDimension{D}}
end

# example implementation:
# @traitfn f(x::X) where {X; HasPseudoDimension{X}} = "Fake!"
# @traitfn f(x::X) where {X; Not{HasPseudoDimension{X}}} = "The real deal!"
