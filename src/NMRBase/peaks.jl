abstract type AbstractPeak{N} end

struct SimplePeak{N} <: AbstractPeak{N}
    intensity::Any
    δ::Any
    δfwhm::Any
end

# create nice show/display methods for peaks and lists of peaks
import Base: show, length, getindex, iterate
function show(io::IO, ::MIME"text/plain", p::SimplePeak{N}) where {N}
    return println(io,
                   "SimplePeak{$N} with intensity=$(p.intensity), δ=$(p.δ), δfwhm=$(p.δfwhm)")
end
function show(io::IO, ::MIME"text/plain", peaks::Vector{<:AbstractPeak{N}}) where {N}
    println(io, "Vector of $(length(peaks)) SimplePeak{$N} objects")
    if length(peaks) == 0
        return
    end
    println(io, "\tIndex\tδ\tIntensity\tδfwhm")
    for (i, p) in enumerate(peaks)
        println(io, "\t$i\t$(p.δ)\t$(p.intensity)\t$(p.δfwhm)")
    end
end

function detectpeaks(A::NMRData{T,1}; snr_threshold=10) where {T}
    y = abs.(data(A)) / A[:noise]
    pks = peakproms!(; min=snr_threshold)(findmaxima(y))
    if length(pks.indices) == 0
        return SimplePeak{1}[]
    end
    i = pks.indices
    w = peakwidths(pks).widths
    δ = data(A, F1Dim)[i]
    Δδ = abs(data(A, F1Dim)[2] - data(A, F1Dim)[1])
    δfwhm = w .* Δδ
    intensities = data(A)[i]
    return [SimplePeak{1}(intensities[j], δ[j], δfwhm[j]) for j in eachindex(i)]
end