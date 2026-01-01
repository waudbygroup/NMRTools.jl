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

# Xi ratios for indirect chemical shift referencing
# These are the ratios of heteronuclear reference frequencies to 1H reference frequency
# Used for the unified chemical shift scale (IUPAC recommendations)

# DSS-based Xi ratios (aqueous solutions)
# References:
# - 2H: Markley et al., 1998, Pure Appl. Chem. 70, 117-142 (DSS-CD3)
# - 13C: Wishart et al., 1995, J. Biomol. NMR 6, 135-140 (DSS-CD3)
# - 15N: Wishart et al., 1995, J. Biomol. NMR 6, 135-140 (liquid NH3 capillary)
# - 19F: Maurer and Kalbitzer, 1996, J. Magn. Reson. B113, 177-178 (TFA sphere)
# - 31P: Maurer and Kalbitzer, 1996, J. Magn. Reson. B113, 177-178 (H3PO4 sphere)
const XI_DSS = Dict(H1 => 1.0,
                    H2 => 0.1535060886,
                    C13 => 0.251449530,
                    N15 => 0.101329118,
                    F19 => 0.94094011,
                    P31 => 0.40480742)

# TMS-based Xi ratios (organic solvents)
# References: IUPAC recommendations 2001/2008
# - 2H: same as DSS (deuterated solvents)
# - 13C: TMS methyl carbon
# - 15N: liquid NH3 (external)
# - 19F: CFCl3
# - 31P: H3PO4 85%
const XI_TMS = Dict(H1 => 1.0,
                    H2 => 0.1535060886,
                    C13 => 0.25145020,
                    N15 => 0.101329118,
                    F19 => 0.94094011,
                    P31 => 0.40480742)

"""
    xi_ratio(n::Nucleus; aqueous=true)

Return the Xi ratio for nucleus `n`, used for indirect chemical shift referencing.

The Xi ratio is defined as the ratio of the reference frequency of nucleus X to the
1H reference frequency (TMS or DSS). This enables indirect referencing of heteronuclear
dimensions from a single 1H reference.

# Arguments
- `n::Nucleus`: The nucleus for which to retrieve the Xi ratio
- `aqueous=true`: If `true`, use DSS-based ratios (aqueous solutions).
                  If `false`, use TMS-based ratios (organic solvents).

# Returns
- The Xi ratio as a Float64, or `nothing` if not defined for this nucleus.

# Examples
```jldoctest
julia> xi_ratio(C13)
0.25144953

julia> xi_ratio(C13; aqueous=true)
0.25144953

julia> xi_ratio(C13; aqueous=false)
0.2514502

julia> xi_ratio(N15)
0.101329118
```

# References
- Markley et al., 1998, Pure Appl. Chem. 70, 117-142
- Wishart et al., 1995, J. Biomol. NMR 6, 135-140
- Maurer and Kalbitzer, 1996, J. Magn. Reson. B113, 177-178
- IUPAC recommendations 2001/2008

See also [`reference`](@ref), [`Nucleus`](@ref).
"""
function xi_ratio(n::Nucleus; aqueous=true)
    dic = aqueous ? XI_DSS : XI_TMS
    return get(dic, n, nothing)
end
