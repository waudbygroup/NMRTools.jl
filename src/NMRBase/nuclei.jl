"""
Nucleus
Enumeration of common NMR-active nuclei.
"""
@enum Nucleus begin
    H1
    H2
    C12
    C13
    N14
    N15
    F19
    P31
end

"""
    spin(n::Nucleus)

Return the spin quantum number of nucleus `n`.

# Arguments
- `n`: Nucleus enum

# Returns
- Spin as a `Rational` or `nothing` if not found
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

Return the gyromagnetic ratio in Hz/T of nucleus `n`.

# Arguments
- `n`: Nucleus enum

# Returns
- Gyromagnetic ratio in Hz/T as a `Float64`, or `nothing` if not found
"""
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