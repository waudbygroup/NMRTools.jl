contourlevels(spacing=1.7, n=12) = (spacing^i for i in 0:(n - 1))

_parse_colorant(c::Colorant) = c
_parse_colorant(c) = parse(Colorant, c)

function _derive_negcolor(poscolor)
    hsv = convert(HSV, _parse_colorant(poscolor))
    return HSV(hsv.h, hsv.s * 0.4, min(1.0, max(0.5, hsv.v + 0.4)))
end

axislabel(dat::NMRData, n=1) = axislabel(dims(dat, n))
axislabel(dim::FrequencyDimension) = "$(label(dim)) chemical shift (ppm)"
function axislabel(dim::NMRDimension)
    return isnothing(units(dim)) ? "$(label(dim))" : "$(label(dim)) ($(units(dim)))"
end

_realdata(A::AbstractNMRData) = data(A)
_realdata(A::AbstractNMRData{<:Multicomplex}) = realest.(data(A))

# Three-way logic for the `normalize` argument mirroring PlotsExt:
#   normalize = true  → use the spectrum's own scale
#   normalize = false → no scaling
#   normalize = ref::NMRData → scale relative to ref
# Returns the scalar by which to divide the data and the contour-level σ.
function _resolve_normalize(spec::AbstractNMRData, normalize)
    if normalize === false
        return (one(eltype(_realdata(spec))), spec[:noise])
    elseif normalize === true
        return (scale(spec), spec[:noise])
    elseif normalize isa AbstractNMRData
        return (scale(spec), normalize[:noise] * scale(spec) / scale(normalize))
    else
        throw(ArgumentError("normalize must be true, false or a reference spectrum"))
    end
end

_theme_palette() = Makie.wong_colors()

# Build a vector of n colours for a series of spectra. Short series use the
# theme palette, long series fall through to a sequential colormap so that
# colour encodes order along the series axis.
function _series_poscolors(arg, n::Integer; colormap=:viridis)
    if arg isa AbstractVector
        return [_parse_colorant(arg[mod1(i, length(arg))]) for i in 1:n]
    elseif !isnothing(arg)
        return fill(_parse_colorant(arg), n)
    end
    pal = _theme_palette()
    if n <= length(pal)
        return [_parse_colorant(pal[i]) for i in 1:n]
    end
    cs = Makie.to_colormap(colormap)
    return [cs[round(Int, 1 + (i - 1) * (length(cs) - 1) / max(n - 1, 1))] for i in 1:n]
end

function _series_negcolors(arg, poscolors)
    if arg isa AbstractVector
        return [_parse_colorant(arg[mod1(i, length(arg))]) for i in eachindex(poscolors)]
    elseif !isnothing(arg)
        return fill(_parse_colorant(arg), length(poscolors))
    end
    return [_derive_negcolor(c) for c in poscolors]
end
