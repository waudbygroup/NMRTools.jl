"""
    Coherence

Abstract supertype for representing coherences.

See also [`SQ`](@ref), [`MQ`](@ref).
"""
abstract type Coherence end

"""
    SQ(nucleus::Nucleus, label=="")

Representation of a single quantum coherence on a given nucleus.

See also [`Nucleus`](@ref), [`MQ`](@ref).
"""
struct SQ <: Coherence
    nucleus::Nucleus
    label::String
    SQ(nuc, label="") = new(nuc, label)
end

"""
    MQ(coherences, label=="")

Representation of a multiple-quantum coherence. Coherences are specified as a tuple of tuples,
of the form `(nucleus, coherenceorder)`

# Examples
```jldoctest
julia> MQ(((H1,1), (C13,-1)), "ZQ")
MQ(((H1, 1), (C13, -1)), "ZQ")

julia> MQ(((H1,3), (C13,1)), "QQ")
MQ(((H1, 3), (C13, 1)), "QQ")
```

See also [`Nucleus`](@ref), [`SQ`](@ref).
"""
struct MQ <: Coherence
    coherences::Tuple{Vararg{Tuple{Nucleus,Int}}}
    label::String
    MQ(coherences, label="") = new(coherences, label)
end

"""
    coherenceorder(coherence)

Calculate the total coherence order.

# Examples
```jldoctest
julia> coherenceorder(SQ(H1))
1

julia> coherenceorder(MQ(((H1,1),(C13,1))))
2

julia> coherenceorder(MQ(((H1,1),(C13,-1))))
0

julia> coherenceorder(MQ(((H1,3),(C13,1))))
4

julia> coherenceorder(MQ(((H1,0),)))
0
```
See also [`Nucleus`](@ref), [`SQ`](@ref), [`MQ`](@ref).
"""
function coherenceorder end

coherenceorder(c::SQ) = 1
function coherenceorder(c::MQ)
    return sum([t[2] for t in c.coherences])
end
