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

# ── Normalisation ────────────────────────────────────────────────────────
#
# NMR data carries `scale(spec)` = ns·rg·concentration (the expected signal
# magnitude) and a `:noise` RMS level. The `normalize` argument is handled
# differently for *intensity* plots vs *contour/volume* plots:
#
#   • Intensity plots (1D lines, pseudo-2D heatmap/stack/waterfall) divide
#     the DATA by a scaling factor so spectra at different concentrations or
#     receiver gains are directly comparable → `_normalization_divisor`.
#
#   • Contour/volume plots (2D, 3D) leave the data in RAW units and instead
#     position the threshold σ (2D contour base = 5σ, 3D volume floor).
#     Data and σ are therefore both raw and mutually consistent — we do NOT
#     divide σ by `scale` here, precisely because the data isn't divided
#     either → `_contour_sigma`.
#
# `normalize` accepts:
#   false        — no normalisation        (divisor 1;       σ = own noise)
#   true         — self-normalise          (divisor = scale; σ = own noise)
#   ref::NMRData — normalise to a reference (divisor = own scale;
#                  σ = noise(ref)·scale(spec)/scale(ref) — a common,
#                  concentration-aware floor so overlaid spectra compare
#                  fairly: a 2× more concentrated spectrum needs 2× taller
#                  peaks to break the same contour threshold)

"""
    _normalization_divisor(spec, normalize) -> Real

Factor to divide intensity data by before plotting. `false` → 1; `true` or
a reference spectrum → `scale(spec)` (1D always self-normalises — the
reference only affects contour σ, matching the Plots extension).
"""
function _normalization_divisor(spec::AbstractNMRData, normalize)
    normalize === false && return one(eltype(_realdata(spec)))
    (normalize === true || normalize isa AbstractNMRData) && return scale(spec)
    throw(ArgumentError("normalize must be true, false, or a reference NMRData"))
end

"""
    _contour_sigma(spec, normalize) -> Real

Noise level σ for 2D contour base levels (`5σ`) and the 3D volume floor.
Data is left raw, so σ is raw too. `false`/`true` → `spec[:noise]`; a
reference spectrum → that reference's noise rescaled by the concentration
ratio `scale(spec)/scale(ref)`.
"""
function _contour_sigma(spec::AbstractNMRData, normalize)
    (normalize === false || normalize === true) && return spec[:noise]
    normalize isa AbstractNMRData &&
        return normalize[:noise] * scale(spec) / scale(normalize)
    throw(ArgumentError("normalize must be true, false, or a reference NMRData"))
end

_theme_palette() = Makie.wong_colors()

# Build a vector of n colours for a series of spectra.
# - Explicit `arg` (vector or scalar) wins.
# - Explicit `colormap` samples a colourmap at n points.
# - 1–5 spectra: Makie's default Wong palette (themable, perceptual).
# - 6+ spectra: HSV evenly spaced around the hue circle (matching PlotsExt;
#   distinguishable without yellow-on-white visibility issues).
function _series_poscolors(arg, n::Integer; colormap=nothing)
    if arg isa AbstractVector
        return [_parse_colorant(arg[mod1(i, length(arg))]) for i in 1:n]
    elseif !isnothing(arg)
        return fill(_parse_colorant(arg), n)
    end
    if !isnothing(colormap)
        cs = Makie.to_colormap(colormap)
        return [cs[round(Int, 1 + (i - 1) * (length(cs) - 1) / max(n - 1, 1))]
                for i in 1:n]
    end
    if n <= 5
        pal = _theme_palette()
        return [_parse_colorant(pal[mod1(i, length(pal))]) for i in 1:n]
    end
    return [HSV(h, 0.9, 0.85) for h in (0:(n - 1)) .* (360.0 / n)]
end

function _series_negcolors(arg, poscolors)
    if arg isa AbstractVector
        return [_parse_colorant(arg[mod1(i, length(arg))]) for i in eachindex(poscolors)]
    elseif !isnothing(arg)
        return fill(_parse_colorant(arg), length(poscolors))
    end
    return [_derive_negcolor(c) for c in poscolors]
end

# Count Contour plots already in the axis, divide by 2 (pos+neg per
# spectrum). Used to advance the Wong colour cycler across successive
# `nmrplot!` calls on 2D spectra so overlays don't all share Wong[1].
function _existing_2d_count(ax::Makie.Axis)
    n = 0
    for p in ax.scene.plots
        p isa Makie.Contour && (n += 1)
    end
    return n ÷ 2
end

# Merge user-facing axis overrides (`title`, `xlabel`, `ylabel`, `zlabel`)
# and the `axis=NamedTuple(...)` escape hatch onto the default axis kwargs.
function _axis_overrides(defaults; title=nothing, xlabel=nothing,
                         ylabel=nothing, zlabel=nothing, axis=NamedTuple())
    overrides = NamedTuple()
    isnothing(title)  || (overrides = merge(overrides, (; title)))
    isnothing(xlabel) || (overrides = merge(overrides, (; xlabel)))
    isnothing(ylabel) || (overrides = merge(overrides, (; ylabel)))
    isnothing(zlabel) || (overrides = merge(overrides, (; zlabel)))
    return merge(defaults, overrides, axis)
end

# Position aliases for Makie.axislegend. Makie's convention is two-letter
# (e.g. :rt for top-right); we also accept friendlier spellings.
const _LEGEND_POS_ALIAS = Dict(
    :topright => :rt, :topleft => :lt, :bottomright => :rb, :bottomleft => :lb,
    :top => :ct, :bottom => :cb, :left => :lc, :right => :rc,
    true => :rt,
)

function _resolve_legend_position(legend)
    if legend isa Symbol
        return get(_LEGEND_POS_ALIAS, legend, legend)
    elseif legend === true
        return :rt
    end
    return :rt
end

function _apply_legend!(ax::Makie.Axis, legend)
    legend === false && return nothing
    legend isa Bool && legend &&
        return Makie.axislegend(ax; position=:rt)
    legend isa Symbol &&
        return Makie.axislegend(ax; position=_resolve_legend_position(legend))
    legend isa AbstractString &&
        return Makie.axislegend(ax, legend)
    legend isa NamedTuple &&
        return Makie.axislegend(ax; legend...)
    throw(ArgumentError("legend must be false / true / a position symbol / a title string / a NamedTuple"))
end

# Variant for contour series: Makie's auto-generated legend entries for
# `Contour` plots ignore the line colour, so we build `LineElement`s
# explicitly from the resolved colours.
function _apply_contour_legend!(ax::Makie.Axis, legend, labels, colors)
    legend === false && return nothing
    nonempty = [(l, c) for (l, c) in zip(labels, colors) if !isempty(l)]
    isempty(nonempty) && return nothing
    entries = [Makie.LineElement(; color=c) for (_, c) in nonempty]
    labs = [l for (l, _) in nonempty]
    if legend isa AbstractString
        return Makie.axislegend(ax, entries, labs, legend; position=:rt)
    elseif legend isa NamedTuple
        return Makie.axislegend(ax, entries, labs; legend...)
    else
        return Makie.axislegend(ax, entries, labs;
                                position=_resolve_legend_position(legend))
    end
end
