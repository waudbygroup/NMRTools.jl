"""
    FQList(values, unit::Symbol, relative::Bool)
    FQList(values, unit::Symbol, relative::Bool, bf, sfo)

Represents a frequency list. `unit` can be `:Hz` or `:ppm`, and `relative`
indicates whether the frequency is given relative to SFO (true) or BF (false).

`bf` and `sfo` optionally record the reference base and carrier frequencies (in Hz)
of the spectrometer channel this list belongs to. When present, the list can be
converted to ppm or Hz on its own — without a detected frequency axis — using the
single-argument [`ppm`](@ref) and [`hz`](@ref) methods. See [`withreference`](@ref)
to attach a reference from a channel dictionary.

Raw values can be extracted using the `data` function, or (better) as absolute
chemical shifts (in ppm) or relative offsets (in Hz) using [`ppm`](@ref) and
[`hz`](@ref) functions.

See also: [`ppm`](@ref), [`hz`](@ref), [`withreference`](@ref).
"""
struct FQList{T} <: AbstractVector{T}
    values::Vector{T}
    unit::Symbol
    relative::Bool
    bf::Union{Float64,Nothing}
    sfo::Union{Float64,Nothing}
end

FQList(values, unit::Symbol, relative::Bool) = FQList(values, unit, relative, nothing, nothing)

data(f::FQList) = f.values
Base.size(f::FQList) = size(f.values)
Base.IndexStyle(::Type{<:FQList}) = IndexLinear()
Base.getindex(f::FQList, i::Int) = f.values[i]
Base.setindex!(f::FQList, v, i::Int) = (f.values[i] = v)

"""
    withreference(f::FQList, channel) -> FQList

Return a copy of frequency list `f` with its reference base and carrier frequencies
(`:bf`, `:sfo`) populated from a channel dictionary (see [`channel`](@ref)). This
makes the list self-describing, so it can be converted to ppm or Hz without a
detected frequency axis.
"""
function withreference(f::FQList, ch::AbstractDict)
    return FQList(f.values, f.unit, f.relative, get(ch, :bf, nothing), get(ch, :sfo, nothing))
end

"""
    ppm(f::FQList, ax::FrequencyDimension)

Return frequency list values in ppm (in absolute terms, i.e. relative to 0 ppm).

See also: [`hz`](@ref)
"""
function NMRBase.ppm(f::FQList, ax::NMRBase.FrequencyDimension)
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
    ppm(f::FQList)

Return frequency list values in ppm (in absolute terms, i.e. relative to 0 ppm),
using the reference frequencies (`:bf`, `:sfo`) stored on the list. Throws an error
if no reference is attached — see [`withreference`](@ref).

See also: [`hz`](@ref)
"""
function NMRBase.ppm(f::FQList)
    isnothing(f.bf) &&
        throw(NMRToolsError("FQList has no reference frequency; cannot convert to ppm. See `withreference`."))
    if f.relative
        isnothing(f.sfo) &&
            throw(NMRToolsError("FQList has no reference carrier frequency (sfo); cannot convert relative list to ppm."))
        ppm0 = (f.sfo - f.bf) * 1e6 / f.bf
    else
        ppm0 = 0
    end
    ppm = f.unit == :ppm ? f.values : 1e6 .* f.values ./ f.bf
    return ppm .+ ppm0
end

"""
    hz(f::FQList, ax::FrequencyDimension)

Return frequency list values as offsets relative to the spectrometer frequency, in Hz.

See also: [`ppm`](@ref)
"""
function NMRBase.hz(f::FQList, ax::NMRBase.FrequencyDimension)
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

"""
    hz(f::FQList)

Return frequency list values as offsets relative to the spectrometer carrier frequency,
in Hz, using the reference frequencies (`:bf`, `:sfo`) stored on the list. Throws an
error if no reference is attached — see [`withreference`](@ref).

See also: [`ppm`](@ref)
"""
function NMRBase.hz(f::FQList)
    if f.relative
        if f.unit == :ppm
            isnothing(f.bf) &&
                throw(NMRToolsError("FQList has no reference frequency; cannot convert ppm list to Hz."))
            return f.values .* f.bf .* 1e-6
        else
            # Hz, relative
            return f.values
        end
    else
        (isnothing(f.bf) || isnothing(f.sfo)) &&
            throw(NMRToolsError("FQList has no reference frequency; cannot convert absolute list to Hz."))
        offsethz = f.sfo - f.bf
        if f.unit == :ppm
            offsetppm = offsethz * 1e6 / f.bf
            return (f.values .- offsetppm) .* f.bf .* 1e-6
        else
            return f.values .- offsethz
        end
    end
end