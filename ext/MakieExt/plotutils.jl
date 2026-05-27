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

# Build a vector of n colours for a series of spectra. Defaults to HSV
# evenly spaced around the hue circle (matching PlotsExt) so each spectrum
# is visually distinct without yellow-disappears-on-white issues. Users
# can pass an explicit vector via `colors`, a single colour to repeat, or
# override the colourmap.
function _series_poscolors(arg, n::Integer; colormap=nothing)
    if arg isa AbstractVector
        return [_parse_colorant(arg[mod1(i, length(arg))]) for i in 1:n]
    elseif !isnothing(arg)
        return fill(_parse_colorant(arg), n)
    end
    if isnothing(colormap)
        return [HSV(h, 0.9, 0.85) for h in (0:(n - 1)) .* (360.0 / n)]
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

# Merge user-facing axis overrides (`title`, `xlabel`, `ylabel`) and the
# `axis=NamedTuple(...)` escape hatch onto the default axis kwargs.
function _axis_overrides(defaults; title=nothing, xlabel=nothing,
                         ylabel=nothing, axis=NamedTuple())
    overrides = NamedTuple()
    isnothing(title)  || (overrides = merge(overrides, (; title)))
    isnothing(xlabel) || (overrides = merge(overrides, (; xlabel)))
    isnothing(ylabel) || (overrides = merge(overrides, (; ylabel)))
    return merge(defaults, overrides, axis)
end

# Position aliases for Makie.axislegend. Makie's convention is two-letter
# (e.g. :rt for top-right); we also accept friendlier spellings.
const _LEGEND_POS_ALIAS = Dict(
    :topright => :rt, :topleft => :lt, :bottomright => :rb, :bottomleft => :lb,
    :top => :ct, :bottom => :cb, :left => :lc, :right => :rc,
    true => :rt,
)

function _apply_legend!(ax::Makie.Axis, legend)
    legend === false && return nothing
    legend isa Bool && legend &&
        return Makie.axislegend(ax; position=:rt)
    if legend isa Symbol
        pos = get(_LEGEND_POS_ALIAS, legend, legend)
        return Makie.axislegend(ax; position=pos)
    end
    legend isa AbstractString &&
        return Makie.axislegend(ax, legend)
    if legend isa NamedTuple
        return Makie.axislegend(ax; legend...)
    end
    throw(ArgumentError("legend must be false / true / a position symbol / a title string / a NamedTuple"))
end
