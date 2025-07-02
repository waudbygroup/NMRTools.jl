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

"""
    XI_RATIOS

Dictionary containing XI ratios (ratio of frequency relative to 1H) for different nuclei
in TMS (organic solvents) and DSS (aqueous solvents) according to IUPAC recommendations.

Reference: https://nmr.chem.ucsb.edu/protocols/refppm.html
           Pure Appl. Chem. 2001, 73, 1795-1818
"""
const XI_RATIOS = Dict(
    :TMS => Dict(
        H1 => 1.0,  # 1H is the reference
        C13 => 0.251449530,  # 13C
        N15 => 0.101329118,  # 15N
        F19 => 0.940062227,  # 19F
        P31 => 0.404808636   # 31P
    ),
    :DSS => Dict(
        H1 => 1.0,  # 1H is the reference
        C13 => 0.251449530,  # 13C (same as TMS)
        N15 => 0.101329118,  # 15N (same as TMS) 
        F19 => 0.940062227,  # 19F (same as TMS)
        P31 => 0.404808636   # 31P (same as TMS)
    )
)

"""
    xi_ratio(nucleus; reference_standard=:TMS)

Return the XI ratio for a nucleus relative to 1H for the specified reference standard.

# Arguments
- `nucleus`: The nucleus (e.g., C13, N15)
- `reference_standard`: Either `:TMS` for organic solvents or `:DSS` for aqueous solvents

# Examples
```julia
xi_ratio(C13)  # Returns 0.251449530 for TMS
xi_ratio(N15, reference_standard=:DSS)  # Returns 0.101329118 for DSS
```
"""
function xi_ratio(nucleus::Nucleus; reference_standard::Symbol=:TMS)
    if reference_standard ∉ [:TMS, :DSS]
        throw(NMRToolsError("reference_standard must be :TMS or :DSS"))
    end
    
    ratios = XI_RATIOS[reference_standard]
    if nucleus ∉ keys(ratios)
        throw(NMRToolsError("XI ratio not defined for nucleus $nucleus"))
    end
    
    return ratios[nucleus]
end

"""
    water_chemical_shift(temperature_kelvin)

Calculate the chemical shift of water based on temperature using the formula:
δ(H₂O) = 7.83 - (T-273.15)/96.9

where T is temperature in Kelvin.

# Arguments
- `temperature_kelvin`: Temperature in Kelvin

# Returns
- Chemical shift of water in ppm

# Reference
- Gottlieb, H. E.; Kotlyar, V.; Nudelman, A. J. Org. Chem. 1997, 62, 7512-7515.
"""
function water_chemical_shift(temperature_kelvin)
    temperature_celsius = temperature_kelvin - 273.15
    return 7.83 - temperature_celsius / 96.9
end
