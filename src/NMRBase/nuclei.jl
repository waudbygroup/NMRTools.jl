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

# Dictionary mapping nucleus strings to enum values
const NUCLEUS_LOOKUP = Dict("H1" => H1, "1H" => H1,
                            "H2" => H2, "2H" => H2,
                            "C12" => C12, "12C" => C12,
                            "C13" => C13, "13C" => C13,
                            "N14" => N14, "14N" => N14,
                            "N15" => N15, "15N" => N15,
                            "F19" => F19, "19F" => F19,
                            "P31" => P31, "31P" => P31)

"""
    nucleus(label::AbstractString) -> Nucleus

Parse a nucleus from a string label, returning the corresponding `Nucleus` enum value.

The function accepts common NMR nucleus notation formats:
- Mass number followed by element symbol: "1H", "13C", "15N", "19F", "31P"
- Element symbol followed by mass number: "H1", "C13", "N15", "F19", "P31"

# Examples
```julia
nucleus("19F")  # returns F19
nucleus("1H")   # returns H1
nucleus("13C")  # returns C13
nucleus("15N")  # returns N15
```

Throws `ArgumentError` if the nucleus is not recognised or not defined in the `Nucleus` enum.
"""
function nucleus(label::AbstractString)
    # Remove any whitespace and convert to uppercase
    clean_label = uppercase(strip(label))

    # Look up in the dictionary
    nucleus = get(NUCLEUS_LOOKUP, clean_label, nothing)
    if nucleus !== nothing
        return nucleus
    end

    throw(ArgumentError("Unknown nucleus: $label"))
end