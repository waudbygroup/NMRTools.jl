"""
    estimatenoise(d::NMRData)

Estimate the rms noise level in the data and update `:noise` metadata.
"""
function estimatenoise!(d::NMRData)
    α = 0.25 # fraction of data to discard for noise estimation

    nsamples = 1000
    n0 = length(d)
    step = Int(ceil(n0/nsamples))

    y = sort(vec(data(d))[1:step:end])
    n = length(y)

    # select central subset of points
    i1 = ceil(Int,(α/2)*n)
    i2 = floor(Int,(1-α/2)*n)
    y = y[i1:i2]

    μ0 = mean(y)
    σ0 = std(y)
    a = y[1]
    b = y[end]
    #histogram(y)|>display

    # MLE of truncated normal distribution
    𝜙(x) = (1/sqrt(2π))*exp.(-0.5*x.^2)
    𝛷(x) = 0.5*erfc.(-x/sqrt(2))
    logP(x,μ,σ) = @. log(𝜙((x-μ)/σ) / (σ*(𝛷((b-μ)/σ) - 𝛷((a-μ)/σ))))
    ℒ(p) = -sum(logP(y, p...))

    p0 = [μ0, σ0]
    res = optimize(ℒ, p0)
    p = Optim.minimizer(res)
    d[:noise] = abs(p[2])
end



"""
    estimatenoise(spectra::Array{<:NMRData,1})

Estimate the rms noise level and update `:noise` metadata for a list of spectra.
"""
estimatenoise!(spectra::Array{<:NMRData,1}) = [estimatenoise!(spectrum) for spectrum in spectra]
