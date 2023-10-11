"""
    estimatenoise!(nmrdata)

Estimate the rms noise level in the data and update `:noise` metadata.

If called on an `Array` of data, each item will be updated.

# Algorithm
Data are sorted into numerical order, and the highest and lowest 12.5% of data are discarded
(so that 75% of the data remain). These values are then fitted to a truncated gaussian
distribution via maximum likelihood analysis.

The log-likelihood function is:
```math
\\log L(\\mu, \\sigma) = \\sum_i{\\log P(y_i, \\mu, \\sigma)}
```

where the likelihood of an individual data point is:
```math
\\log P(y,\\mu,\\sigma) =
    \\log\\frac{
        \\phi\\left(\\frac{x-\\mu}{\\sigma}\\right)
    }{
        \\sigma \\cdot \\left[\\Phi\\left(\\frac{b-\\mu}{\\sigma}\\right) -
            \\Phi\\left(\\frac{a-\\mu}{\\sigma}\\right)\\right]}
```

and ``\\phi(x)`` and ``\\Phi(x)`` are the standard normal pdf and cdf functions.
"""
function estimatenoise!(d::NMRData)
    α = 0.25 # fraction of data to discard for noise estimation

    nsamples = 1000
    n0 = length(d)
    step = Int(ceil(n0/nsamples))

    if isreal(data(d))
        vd = vec(data(d))
    else
        # TODO consider multicomplex
        @warn "estimatenoise! doesn't handle multicomplex numbers correctly. Working with real values only."
        vd = vec(real(data(d)))
    end
    y = sort(vd[1:step:end])
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

estimatenoise!(spectra::Array{<:NMRData}) = map(estimatenoise!, spectra)
