"""
    Nucleus

Enumeration of common nuclei associated with biomolecular NMR. Nuclei are named e.g. `H1`, `C13`.

Defined nuclei: `H1`, `H2`, `C12`, `C13`, `N14`, `N15`, `F19`, `P31`.

See also [`spin`](@ref), [`gyromagneticratio`](@ref), [`Coherence`](@ref).
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
