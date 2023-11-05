### A Pluto.jl notebook ###
# v0.19.26

using Markdown
using InteractiveUtils

# ╔═╡ e6011ab0-015c-11ee-28ee-558654f02fbc
# ╠═╡ show_logs = false
# add packages
begin
	using Pkg
	Pkg.add("NMRTools")
	Pkg.add("Plots")
	Pkg.add("LsqFit")
	Pkg.add("Measurements")
	Pkg.add("PlutoUI")
	using NMRTools
	using Plots
	using LsqFit
	using Measurements
	using PlutoUI
end

# ╔═╡ 618325a3-f519-4805-b55c-d55458683b8a
md"# NMRTools diffusion analysis"

# ╔═╡ 35a2b544-ff30-4b52-a82d-401fc6f73f8f
begin
	# select input data
	inputfile = "/Users/chris/.julia/dev/NMRTools/exampledata/pseudo2D_XSTE/1/pdata/1"
	dat = loadnmr(inputfile)

	# specify gradient points
	gradients = LinRange(0.05, 0.95, 10)
	Gmax = 0.50 # T/m
	
	coherence = SQ(H1)             # coherence for diffusion encoding
								   # for MQ coherences, try e.g. MQ(((H1,3),))
	δ = acqus(dat, :p, 30) * 2e-6  # gradient pulse length
	Δ = acqus(dat, :d, 20)         # diffusion delay
	σ = 0.9                        # shape factor for SMSQ10

	# select chemical shift ranges for plotting and fitting
	plotrange = Between(6, 10)
	selector = Between(7.6, 8.6)

	# estimate solution viscosity to determine the hydrodynamic radius
	solvent = :h2o # or :d2o
	T = acqus(dat, :te) # K
	
	md"## setup"
end

# ╔═╡ 0ab0f876-e285-4ddb-b6f0-67d8702bc369
function viscosity(solvent, T)
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
        @error "solvent not recognised (should be :h2o or :d2o)"
    end

    DT = T - T0
    k = 1.38e-23
	
    return A * (DT + a*DT^2 + b*DT^3 + c*DT^4)^(-gamma)
end

# ╔═╡ e969bcdc-0d37-43c0-a255-f37b8daebe89
# ╠═╡ show_logs = false
begin
	spec = setgradientlist(dat, gradients, Gmax)
	
	γ = gyromagneticratio(coherence)
	g = data(dims(spec, G1Dim))
	
	integrals = vec(data(sum(spec[selector,:],dims=F1Dim)))
    integrals /= maximum(integrals)

	# fitting
	model(g, p) = p[1] * exp.(-(γ*δ*σ*g).^2 .* (Δ - δ/3) .* p[2] .* 1e-10)
    p0 = [1.0, 1.0] # rough guess of scaled diffusion coefficient
    fit = curve_fit(model, g, integrals, p0)
    pfit = coef(fit)
    err = stderror(fit)
	D = (pfit[2] ± err[2]) * 1e-10

	k = 1.38e-23
	rH = k*T / (6π*viscosity(solvent, T)*0.001 * D) * 1e9 # in nm

	# plot results
	x = LinRange(0, maximum(g)*1.1, 50)
    yfit = model(x, pfit)

    p1 = scatter(g, integrals, label="observed",
			frame=:box,
			xlabel="G / T m-1",
			ylabel="Integrated signal",
			title="D = $D m2 s-1\nrH = $rH nm",
			ylims=(0,Inf),
			widen=true,
			grid=nothing)
    plot!(p1, x, yfit, label="fit")

    p2 = plot(spec[plotrange,1],linecolor=:black)
    plot!(p2, spec[selector,1], fill=(0,:orange), linecolor=:red)
	hline!(p2, [0], c=:grey)
    title!(p2, "")
    #xlims!(p2, (0,10))

    plt = plot(p1, p2, layout=(2,1), size=(600,600))
end

# ╔═╡ c14dd1b7-fa81-43d3-941c-3904b4f7abd2
md"""
## fit results
* diffusion coefficient = $D m² s⁻¹
* hydrodynamic radius = $rH nm
* temperature = $T K
* viscosity = $(round(viscosity(solvent, T), sigdigits=5)) mPa⋅s
"""

# ╔═╡ cf857799-eca7-4d2a-b17d-99a62a518cc0
begin
    buf = IOBuffer()
    show(buf, MIME("application/pdf"), plt)
    DownloadButton(take!(buf), "diffusion-fit.pdf")
end

# ╔═╡ 5ff5982c-6159-4c5e-97bc-f5e29133bb3a
wireframe(spec[selector,:])

# ╔═╡ 37a5b150-a23d-4209-b089-db9e0da878f6
heatmap(spec[plotrange,:])

# ╔═╡ Cell order:
# ╟─618325a3-f519-4805-b55c-d55458683b8a
# ╠═35a2b544-ff30-4b52-a82d-401fc6f73f8f
# ╟─c14dd1b7-fa81-43d3-941c-3904b4f7abd2
# ╟─cf857799-eca7-4d2a-b17d-99a62a518cc0
# ╠═e969bcdc-0d37-43c0-a255-f37b8daebe89
# ╠═5ff5982c-6159-4c5e-97bc-f5e29133bb3a
# ╠═37a5b150-a23d-4209-b089-db9e0da878f6
# ╠═0ab0f876-e285-4ddb-b6f0-67d8702bc369
# ╠═048d4e1f-7d34-4784-9cc9-6d91bde0b06d
# ╠═e6011ab0-015c-11ee-28ee-558654f02fbc
