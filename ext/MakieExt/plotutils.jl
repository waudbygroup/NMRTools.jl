contourlevels(spacing=1.7, n=12) = (spacing^i for i in 0:(n - 1))

mutable struct ContourState
    level_mult::Observable{Float64}
    spacing::Float64
end

const _CONTOUR_STATES = WeakKeyDict{Makie.Axis,ContourState}()
const _KEYBOARD_REGISTERED = WeakKeyDict{Makie.Axis,Bool}()

function _get_or_create_contour_state!(ax::Makie.Axis, spacing::Float64)
    state = get!(() -> ContourState(Observable(1.0), spacing), _CONTOUR_STATES, ax)
    state.spacing = spacing
    return state
end

# Register a keyboard handler on the first nmrplot! call for this axis.
# ax.scene is used; in GLMakie all scenes in a window share the same event
# system, so this is equivalent to registering on the parent Figure.
function _register_contour_keyboard!(ax::Makie.Axis)
    get(_KEYBOARD_REGISTERED, ax, false) && return
    _KEYBOARD_REGISTERED[ax] = true
    on(events(ax.scene).keyboardbutton) do event
        (event.action == Keyboard.press || event.action == Keyboard.repeat) || return
        state = get(_CONTOUR_STATES, ax, nothing)
        isnothing(state) && return
        if event.key == Keyboard.up
            state.level_mult[] *= state.spacing
        elseif event.key == Keyboard.down
            state.level_mult[] /= state.spacing
        end
    end
end

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

# Constrain an Axis to `xlims` and rescale y to the data falling *within*
# that x-window — so a strong peak outside the window doesn't flatten the
# region of interest. `specs` are the 1D spectra plotted, `offsets` their
# per-spectrum vertical offsets (for stacked series), `normalize` the same
# value passed to plotting. The x-axis reversal is handled by the Axis's
# `xreversed` attribute, so limits are stored in ascending data order.
function _autoscale_to_xlims!(ax, specs, normalize, xlims; pad=0.05,
                              offsets=nothing)
    lo, hi = minmax(Float64(first(xlims)), Float64(last(xlims)))
    ymin = Inf
    ymax = -Inf
    for (k, spec) in enumerate(specs)
        Afwd = reorder(spec, ForwardOrdered)
        xd = data(dims(Afwd, 1))
        yd = _realdata(Afwd) ./ _normalization_divisor(Afwd, normalize)
        off = isnothing(offsets) ? 0.0 : offsets[k]
        @inbounds for i in eachindex(xd)
            if lo <= xd[i] <= hi
                v = yd[i] + off
                v < ymin && (ymin = v)
                v > ymax && (ymax = v)
            end
        end
    end
    if isfinite(ymin) && isfinite(ymax) && ymax > ymin
        p = pad * (ymax - ymin)
        ax.limits[] = ((lo, hi), (ymin - p, ymax + p))
    else
        ax.limits[] = ((lo, hi), nothing)
    end
    return ax
end

# Vertical separation between successive spectra in a stacked 1D series.
function _vstack_delta(v, normalize, vstack)
    if vstack isa Bool
        vstack || return 0.0
        return maximum(maximum(abs.(_realdata(A))) /
                       _normalization_divisor(A, normalize) for A in v) / length(v)
    elseif vstack isa Number
        return maximum(maximum(abs.(_realdata(A))) /
                       _normalization_divisor(A, normalize) for A in v) /
               length(v) * vstack
    else
        throw(ArgumentError("vstack must be a Bool or Number"))
    end
end

# Normalise a user-supplied limit (nothing, or any 2-element order) to an
# ascending (lo, hi) tuple. Axis reversal is handled by `xreversed` etc.,
# so limits are always stored ascending.
_lim_pair(::Nothing) = nothing
_lim_pair(l) = (Float64(minimum(l)), Float64(maximum(l)))

# How many times we've drawn a pseudo-2D spectrum into a given axis.
# Returns 1 on the first call, 2 on the next, etc. Used to advance the
# colour cycle on overlays. We track this explicitly rather than inspecting
# `ax.scene.plots`, because an Axis3 populates its scene with framework
# plots even before any data is added (which would make a fresh axis look
# like an overlay).
const _OVERLAY_COUNT = WeakKeyDict{Any,Int}()
function _next_overlay_index!(ax)
    n = get(_OVERLAY_COUNT, ax, 0) + 1
    _OVERLAY_COUNT[ax] = n
    return n
end

# Apply explicit axis limits generally (no auto-scaling). Works for 2D Axis
# and 3D Axis3; each of xlims/ylims/zlims may be `nothing` (keep auto).
function _apply_axis_limits!(ax::Makie.Axis, xlims, ylims)
    (isnothing(xlims) && isnothing(ylims)) && return ax
    ax.limits[] = (_lim_pair(xlims), _lim_pair(ylims))
    return ax
end

function _apply_axis_limits!(ax::Makie.Axis3, xlims, ylims, zlims=nothing)
    (isnothing(xlims) && isnothing(ylims) && isnothing(zlims)) && return ax
    try
        ax.limits[] = (_lim_pair(xlims), _lim_pair(ylims), _lim_pair(zlims))
    catch err
        @warn "nmrplot: could not apply 3D axis limits" exception = err
    end
    return ax
end

# ── Normalisation ────────────────────────────────────────────────────────
#
# NMR data carries `scale(spec)` = ns·rg·concentration (the expected signal
# magnitude) and a `:noise` RMS level. The `normalize` argument is handled
# differently for *intensity* plots vs *contour* plots:
#
#   • Intensity plots (1D lines, pseudo-2D heatmap/flat/waterfall) divide
#     the DATA by a scaling factor so spectra at different concentrations or
#     receiver gains are directly comparable → `_normalization_divisor`.
#
#   • Contour plots (2D, 3D) leave the data in RAW units and instead
#     position the threshold σ (2D base = 5σ, 3D iso-surface = level·σ).
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

Noise level σ for 2D contour base levels (`5σ`) and 3D iso-surfaces
(`level·σ`). Data is left raw, so σ is raw too. `false`/`true` →
`spec[:noise]`; a reference spectrum → that reference's noise rescaled by
the concentration ratio `scale(spec)/scale(ref)`.
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
    isnothing(title) || (overrides = merge(overrides, (; title)))
    isnothing(xlabel) || (overrides = merge(overrides, (; xlabel)))
    isnothing(ylabel) || (overrides = merge(overrides, (; ylabel)))
    isnothing(zlabel) || (overrides = merge(overrides, (; zlabel)))
    return merge(defaults, overrides, axis)
end

function _apply_legend!(ax::Makie.Axis, legend)
    legend === false && return nothing
    legend isa Bool && legend &&
        return Makie.axislegend(ax; position=:rt)
    legend isa Symbol &&
        return Makie.axislegend(ax; position=legend)
    legend isa AbstractString &&
        return Makie.axislegend(ax, legend)
    legend isa NamedTuple &&
        return Makie.axislegend(ax; legend...)
    throw(ArgumentError("legend must be false / true / a Makie position symbol (e.g. :rt, :lt) / a title string / a NamedTuple"))
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
    elseif legend === true
        return Makie.axislegend(ax, entries, labs; position=:rt)
    else
        return Makie.axislegend(ax, entries, labs; position=legend)
    end
end
