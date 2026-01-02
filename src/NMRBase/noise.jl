"""
    estimatenoise(nmrdata; sigma=4.0, maxiter=10) -> NMRData

Estimate the rms noise level in the data and update `:noise` metadata.
Returns the NMRData object with noise estimate stored in metadata.

If called on an `Array` of data, each item will be updated.

# Keyword arguments
- `sigma`: threshold (in units of MAD) for outlier rejection during iterative clipping (default: 4.0)
- `maxiter`: maximum iterations for sigma clipping (default: 10)

# Algorithm
1. Subsample each frequency dimension based on the correlation length of its window function,
   to obtain approximately independent samples.
2. Compute first differences along each frequency dimension. This removes baseline offsets
   and suppresses broad signals (e.g. water), while preserving noise characteristics.
3. Estimate noise using the Median Absolute Deviation (MAD), which is robust to outliers
   (signal peaks). The MAD is scaled by 1.4826 to give an estimate of the standard deviation
   for Gaussian noise.
4. Iteratively clip outliers beyond `sigma` × MAD until convergence, to further improve
   robustness against residual signal contamination.
5. Scale by ``1/\\sqrt{2^D}`` where ``D`` is the number of frequency dimensions, to account
   for variance doubling from each differencing operation.

# Examples
```julia
spec = loadnmr("experiment/1/pdata/1")
spec = estimatenoise(spec)  # Estimate and store noise level
spec[:noise]  # Access the noise estimate
```

See also [`correlationlength`](@ref).
"""
function estimatenoise(d::NMRData; sigma=4.0, maxiter=10)
    # identify frequency dimensions and calculate subsampling steps
    freqdims = Int[]
    steps = ones(Int, ndims(d))
    for i in 1:ndims(d)
        ax = dims(d, i)
        if ax isa FrequencyDimension
            push!(freqdims, i)
            window = get(metadata(ax), :window, NullWindow())
            sw = get(metadata(ax), :swhz, 1.0)
            steps[i] = max(1, ceil(Int, correlationlength(window, sw)))
        end
    end
    nfreqdims = length(freqdims)

    # subsample to break correlations (creates a view where possible)
    indices = ntuple(i -> 1:steps[i]:size(d, i), ndims(d))
    y = realest.(view(data(d), indices...))

    # take first differences along each frequency dimension
    for i in freqdims
        y = diff(y; dims=i)
    end
    y = vec(y)

    # iterative sigma clipping with MAD
    for _ in 1:maxiter
        med = median(y)
        mad = median(abs.(y .- med))
        threshold = sigma * 1.4826 * mad
        mask = abs.(y .- med) .< threshold
        sum(mask) == length(y) && break  # converged
        y = y[mask]
    end

    # final noise estimate with scaling for differencing
    d[:noise] = 1.4826 * median(abs.(y .- median(y))) / sqrt(2.0^nfreqdims)

    return d
end

estimatenoise(spectra::Array{<:NMRData}) = map(estimatenoise, spectra)
