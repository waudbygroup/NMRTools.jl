"""
    fitexp(A::NMRData{T,2}, selector)

# Examples

```julia
y = loadnmr("exampledata/pseudo2D_XSTE/test.ft1")
y = settval(y, LinRange(0.05, 0.95, 10))
rate, plt = fitexp(y, Between(7.5,9))
display(plt)
```
"""
fitexp(A::D, selector) where {D<:NMRData{T,2} where T} =
        fitexp(SimpleTraits.trait(HasPseudoDimension{D}), A, selector)

function fitexp(::Type{HasPseudoDimension{D}}, A::D, selector) where {D<:NMRData{T, 2} where T}
    # @show A[selector,:]
    # @show data(A[selector,:])
    integrals = vec(data(sum(A[selector,:],dims=X)))
    integrals /= maximum(integrals)

    t = tval(A)
    tscale = maximum(t) / 2

    @. model(t, p) = p[1] * exp(-p[2] * t)
    p0 = [1.0, 1.0] # take a rough guess of initial rate based on observed time points
    fit = curve_fit(model, t / tscale, integrals, p0)
    pfit = coef(fit)
    err = stderror(fit)
    k = (pfit[2] ± err[2]) / tscale

    x = LinRange(0, maximum(t)*1.1, 50)
    yfit = model(x, [pfit[1], pfit[2] / tscale])

    p1 = plot(x, yfit)
    scatter!(p1, t, integrals, legend=nothing)
    xlabel!(p1, label(A,Ti))
    ylabel!(p1, "Integrated signal")
    ylims!(p1, 0, maximum(yfit)*1.1)
    title!(p1, "")

    p2 = plot(A[:,1],linecolor=:grey)
    p2 = plot!(p2, A[selector,1], fill=(0,:orange), linecolor=:red)
    title!(p2, "")
    #xlims!(p2, (0,10))

    plt = plot(p1, p2, layout=(2,1), size=(600,600))

    return k, plt
end



"""
    fitdiffusion(A::NMRData{T,2}, selector; δ=0.004, Δ=0.1, σ=0.9, Gmax=0.55)

# Examples

```julia
y = loadnmr("exampledata/pseudo2D_XSTE/test.ft1")
y = settval(y, LinRange(0.05, 0.95, 10))
rH, D = fitdiffusion(y, Between(7.5,9))
```
"""
fitdiffusion(A::X, selector; δ=0.004, Δ=0.1, σ=0.9, Gmax=0.55, solvent=:h2o, T=298, showplot=true) where {X<:NMRData{T,2} where T} =
        fitdiffusion(SimpleTraits.trait(HasPseudoDimension{X}), A, selector, δ, Δ, σ, Gmax, solvent, T, showplot)

function fitdiffusion(::Type{HasPseudoDimension{X}}, A::X, selector, δ, Δ, σ, Gmax, solvent, T, showplot) where {X<:NMRData{T, 2} where T}
    g = tval(A) * Gmax
    γ = 2.675e8;
    q = (γ*δ*σ*g).^2 * (Δ - δ/3)
    lab = label(A)

    y = settval(A, q) # create copy of data containing q values
    label!(y,Ti,"q / s m-2")

    D, plt = fitexp(y, selector)

    if solvent==:h2o
        A = 802.25336
        a = 3.4741e-3
        b = -1.7413e-5
        c = 2.7719e-8
        gamma = 1.53026
        T0 = 225.334
    elseif solvent==:d2o
        A = 885.60402
        a = 2.799e-3
        b = -1.6342e-5
        c = 2.9067e-8
        gamma = 1.55255
        T0 = 231.832
    else
        @error "fitdiffusion: solvent not recognised (should be :h2o or :d2o)"
    end

    DT = T - T0
    k = 1.38e-23
    η = A * (DT + a*DT^2 + b*DT^3 + c*DT^4)^(-gamma)
    rH = k*T / (6π*η*0.001 * D) * 1e10 # in Å

    plt.subplots[1].attr[:title] = "$(lab): rH = $(rH) Å"

    showplot && display(plt)

    return rH, D, plt
end
