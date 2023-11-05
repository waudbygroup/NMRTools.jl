"""
    spin(n::Nucleus)

Return the spin quantum number of nucleus `n`, or `nothing` if not defined.

# Examples
```jldoctest
julia> spin(H1)
1//2
```

See also [`Coherence`](@ref).
"""
function spin(n::Nucleus)
    dic = Dict(H1 => 1 // 2,
               H2 => 1,
               C12 => 0,
               C13 => 1 // 2,
               N14 => 1,
               N15 => 1 // 2,
               F19 => 1 // 2,
               P31 => 1 // 2)
    return get(dic, n, nothing)
end

"""
    gyromagneticratio(n::Nucleus)
    gyromagneticratio(c::Coherence)

Return the gyromagnetic ratio in Hz/T of a nucleus, or calculate the effective gyromagnetic
ratio of a coherence. This is equal to the product of the individual gyromagnetic ratios
with their coherence orders.

Returns `nothing` if not defined.

# Examples
```jldoctest
julia> gyromagneticratio(H1)
2.6752218744e8

julia> gyromagneticratio(SQ(H1))
2.6752218744e8

julia> gyromagneticratio(MQ(((H1,1),(C13,1))))
3.3480498744e8

julia> gyromagneticratio(MQ(((H1,0),)))
0.0
```

See also [`Nucleus`](@ref), [`Coherence`](@ref).
"""
function gyromagneticratio end

function gyromagneticratio(n::Nucleus)
    dic = Dict(H1 => 267.52218744e6,
               H2 => 41.065e6,
               C13 => 67.2828e6,
               N14 => 19.331e6,
               N15 => -27.116e6,
               F19 => 251.815e6,
               P31 => 108.291e6)
    return get(dic, n, nothing)
end

gyromagneticratio(c::SQ) = gyromagneticratio(c.nucleus)
function gyromagneticratio(c::MQ)
    return sum([gyromagneticratio(t[1]) * t[2] for t in c.coherences])
end
