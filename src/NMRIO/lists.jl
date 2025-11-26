"""
    FQList(values, unit::Symbol, relative::Bool)

Represents a frequency list. `unit` can be `:Hz` or `:ppm`, and `relative`
indicates whether the frequency is given relative to SFO (true) or BF (false).

Raw values can be extracted using the `data` function, or (better) as absolute
chemical shifts (in ppm) or relative offsets (in Hz) using [`getppm`](@ref) and
[`getoffset`](@ref) functions.

See also: [`getppm`](@ref), [`getoffset`](@ref).
"""
struct FQList{T}
    values::Vector{T}
    unit::Symbol
    relative::Bool
end

data(f::FQList) = f.values

"""
    getppm(f::FQList, ax::FrequencyDimension)

Return frequency list values in ppm (in absolute terms, i.e. relative to 0 ppm).

See also: [`getoffset`](@ref)
"""
function getppm(f::FQList, ax::FrequencyDimension)
    if f.relative
        ppm0 = ax[:offsetppm]
    else
        ppm0 = 0
    end
    if f.unit == :ppm
        ppm = f.values
    else
        # convert Hz to ppm
        bf = ax[:bf]
        ppm = 1e6 .* f.values ./ bf
    end
    return ppm .+ ppm0
end

"""
    getoffset(f::FQList, ax::FrequencyDimension)

Return frequency list values as offsets relative to the spectrometer frequency, in Hz.

See also: [`getppm`](@ref)
"""
function getoffset(f::FQList, ax::FrequencyDimension)
    if f.relative
        if f.unit == :ppm
            # ppm, relative
            return f.values .* ax[:bf] .* 1e-6
        else
            # Hz, relative
            return f.values
        end
    else
        if f.unit == :ppm
            # ppm, absolute
            return (f.values .- ax[:offsetppm]) .* ax[:bf] .* 1e-6
        else
            # Hz, absolute
            return f.values .- ax[:offsethz]
        end
    end
end