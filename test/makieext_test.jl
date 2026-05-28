using NMRTools
using Artifacts
using LazyArtifacts
using Test
using CairoMakie

"""
notes on testing, to generate plots:

]activate --temp
]dev .
]add CairoMakie
using NMRTools, CairoMakie
"""

@testset "MakieExt: 1D 19F" begin
    dat = exampledata("1D_19F")
    fig, ax, plt = nmrplot(dat)

    @test fig isa Makie.Figure
    @test ax isa Makie.Axis
    @test plt isa Makie.Lines
    @test ax.xreversed[] == true
    @test ax.xlabel[] == "19F chemical shift (ppm)"
    @test ax.xgridvisible[] == false
    @test ax.yticksvisible[] == false
end

@testset "MakieExt: 2D HN" begin
    dat = exampledata("2D_HN")
    fig, ax, plt = nmrplot(dat)

    @test fig isa Makie.Figure
    @test ax isa Makie.Axis
    @test ax.xreversed[] == true
    @test ax.yreversed[] == true
    @test ax.title[] == "13C,15N ubiquitin"
    # Positive + negative contour layers added.
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2
end

@testset "MakieExt: 2D HN colour overrides" begin
    dat = exampledata("2D_HN")
    fig, ax, plt = nmrplot(dat; poscolor=:red)
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2

    fig, ax, plt = nmrplot(dat; poscolor=:blue, negcolor=:red)
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2

    fig, ax, plt = nmrplot(dat; poscolor=:limegreen, negcontours=false)
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 1

    # `color=` is an alias for `poscolor=` — negative contour is auto-derived,
    # not coloured the same as positive.
    fig, ax, plt = nmrplot(dat; color=:red)
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2
    # Explicit negcolor wins even when color/poscolor is set.
    fig, ax, plt = nmrplot(dat; color=:green, negcolor=:red)
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2
end

@testset "MakieExt: top-level axis overrides" begin
    dat = exampledata("2D_HN")
    fig, ax, plt = nmrplot(dat; title="My HN", xlabel="¹H", ylabel="¹⁵N")
    @test ax.title[] == "My HN"
    @test ax.xlabel[] == "¹H"
    @test ax.ylabel[] == "¹⁵N"
end

@testset "MakieExt: legend kwarg" begin
    dats = exampledata("2D_HN_titration")
    fig, ax, plt = nmrplot(dats; legend=true)
    @test any(c -> c isa Makie.Legend, fig.content)

    fig, ax, plt = nmrplot(dats; legend=:topleft)
    @test any(c -> c isa Makie.Legend, fig.content)

    fig, ax, plt = nmrplot(dats)
    @test !any(c -> c isa Makie.Legend, fig.content)
end

@testset "MakieExt: nmrplot! forwards from Figure / FigureAxisPlot" begin
    dat = exampledata("2D_HN")
    fap = nmrplot(dat)
    # Both forms should work.
    plt2 = nmrplot!(fap, dat; poscolor=:red)
    @test plt2 isa Makie.Contour
    plt3 = nmrplot!(fap.figure, dat; poscolor=:blue)
    @test plt3 isa Makie.Contour
end

@testset "MakieExt: 2D overlay cycles colours" begin
    dat = exampledata("2D_HN")
    fap = nmrplot(dat)
    plt1_color = fap.plot.color[]
    plt2 = nmrplot!(fap, dat)
    plt2_color = plt2.color[]
    # Second spectrum should get a different Wong colour, not the same one.
    @test plt1_color != plt2_color
end

@testset "MakieExt: nmrplot! into existing axis" begin
    dat = exampledata("1D_19F")
    fig = Makie.Figure()
    ax = Makie.Axis(fig[1, 1])
    plt = nmrplot!(ax, dat)
    @test ax.xreversed[] == true
    @test plt isa Makie.Lines
end

@testset "MakieExt: grid position" begin
    dat = exampledata("1D_19F")
    fig = Makie.Figure()
    ax, plt = nmrplot(fig[1, 1], dat)
    @test ax isa Makie.Axis
    @test ax.xreversed[] == true
end

@testset "MakieExt: vector of 1D" begin
    dats = exampledata("1D_19F_titration")
    fig, ax, plt = nmrplot(dats)
    @test ax isa Makie.Axis
    @test count(p -> p isa Makie.Lines, ax.scene.plots) == length(dats)

    fig, ax, plt = nmrplot(dats; vstack=true)
    @test count(p -> p isa Makie.Lines, ax.scene.plots) == length(dats)

    fig, ax, plt = nmrplot(dats; vstack=5)
    @test count(p -> p isa Makie.Lines, ax.scene.plots) == length(dats)
end

@testset "MakieExt: 1D xlims auto-scales y to window" begin
    dat = exampledata("1D_19F")
    # No xlims: limits stay automatic.
    fig, ax, plt = nmrplot(dat)
    @test ax.limits[] === nothing || all(isnothing, ax.limits[])

    # With xlims: explicit limits applied (x window + windowed y range).
    fig, ax, plt = nmrplot(dat; xlims=(-125, -122))
    @test ax.limits[] !== nothing
    fl = ax.finallimits[]
    @test Float64(minimum(fl)[1]) ≈ -125.0 atol = 1e-6
    @test Float64(maximum(fl)[1]) ≈ -122.0 atol = 1e-6

    # Works for a series too.
    dats = exampledata("1D_19F_titration")
    fig, ax, plt = nmrplot(dats; xlims=(-125, -121))
    @test ax.limits[] !== nothing
end

@testset "MakieExt: vector of 2D" begin
    dats = exampledata("2D_HN_titration")
    fig, ax, plt = nmrplot(dats)
    @test ax isa Makie.Axis
    @test ax.xreversed[] == true
    @test ax.yreversed[] == true
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2 * length(dats)

    # Explicit colours
    fig, ax, plt = nmrplot(dats; colors=[:red, :blue])
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2 * length(dats)

    # Sequential colormap fallback for long series.
    fig, ax, plt = nmrplot(dats; colormap=:plasma)
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2 * length(dats)
end

@testset "MakieExt: Multicomplex 1D slice" begin
    datMC2D = loadnmr(artifact"2D_HN"; allcomponents=true)
    datMC = datMC2D[:, 1]
    @test parent(datMC) isa AbstractVector{<:Multicomplex}

    fig, ax, plt = nmrplot(datMC)
    @test ax.xreversed[] == true
    @test plt isa Makie.Lines
end

@testset "MakieExt: 2D projections" begin
    dat = exampledata("2D_HN")
    fig, ax, plt = nmrplot(dat; xprojection=true, yprojection=true)
    @test ax isa Makie.Axis
    fig, ax, plt = nmrplot(dat; xprojection=:sum, yprojection=:sum)
    @test ax isa Makie.Axis
    fig, ax, plt = nmrplot(dat; xprojection=true)
    @test ax isa Makie.Axis
    slice = dat[:, 1]
    fig, ax, plt = nmrplot(dat; xprojection=slice)
    @test ax isa Makie.Axis
end

@testset "MakieExt: overlay with projections" begin
    dat = exampledata("2D_HN")
    fap = nmrplot(dat; xprojection=true, yprojection=true)
    plt2 = nmrplot!(fap, dat / 2; xprojection=true, yprojection=true,
                    poscolor=:red)
    @test plt2 isa Makie.Contour
end

@testset "MakieExt: nmrplot! without axis uses current_axis" begin
    dat = exampledata("2D_HN")
    fap = nmrplot(dat)
    # Without an explicit axis — should resolve to current_axis().
    plt2 = nmrplot!(dat / 2; poscolor=:red)
    @test plt2 isa Makie.Contour
end

@testset "MakieExt: vector of pseudo-2D" begin
    dat = exampledata("pseudo2D_XSTE")
    fig, ax, plt = nmrplot([dat, dat / 2]; style=:flat)
    @test ax isa Makie.Axis
    fig, ax, plt = nmrplot([dat, dat / 2]; style=:waterfall)
    @test ax isa Makie.Axis3
    @test_throws ArgumentError nmrplot([dat, dat / 2]; style=:heatmap)
end

@testset "MakieExt: pseudo-2D overlay" begin
    dat = exampledata("pseudo2D_XSTE")
    fap = nmrplot(dat; style=:flat)
    plt2 = nmrplot!(dat / 2; style=:flat, color=:green)
    @test plt2 isa Makie.Lines

    fap = nmrplot(dat; style=:waterfall)
    plt3 = nmrplot!(dat / 2; style=:waterfall, color=:green)
    @test plt3 isa Makie.Lines
end

@testset "MakieExt: pseudo-2D heatmap (default)" begin
    dat = exampledata("pseudo2D_XSTE")
    fig, ax, plt = nmrplot(dat)
    @test ax isa Makie.Axis
    @test ax.xreversed[] == true
    @test plt isa Makie.Heatmap

    # No colorbar
    fig, ax, plt = nmrplot(dat; colorbar=false)
    @test plt isa Makie.Heatmap
end

@testset "MakieExt: pseudo-2D flat" begin
    dat = exampledata("pseudo2D_XSTE")
    fig, ax, plt = nmrplot(dat; style=:flat)
    @test ax isa Makie.Axis
    @test ax.xreversed[] == true
    @test plt isa Makie.Lines
    # One Lines per slice; zero baseline adds an HLines (not a Lines).
    @test count(p -> p isa Makie.Lines, ax.scene.plots) == length(dims(dat, 2))
    @test any(p -> p isa Makie.HLines, ax.scene.plots)
end

@testset "MakieExt: pseudo-2D waterfall" begin
    dat = exampledata("pseudo2D_XSTE")
    fig, ax, plt = nmrplot(dat; style=:waterfall)
    @test ax isa Makie.Axis3
    @test plt isa Makie.Lines
    @test count(p -> p isa Makie.Lines, ax.scene.plots) == length(dims(dat, 2))
end

@testset "MakieExt: 3D volume rendering" begin
    dat = exampledata("3D_HNCA")
    fig, ax, plt = nmrplot(dat)
    @test ax isa Makie.Axis3
    @test plt isa Makie.Volume

    fig, ax, plt = nmrplot(dat; algorithm=:absorption, absorption=4.0)
    @test plt isa Makie.Volume

    fig, ax, plt = nmrplot(dat; colormap=:viridis, threshold=10)
    @test plt isa Makie.Volume

    # Explicit colorrange override for dynamic-range control.
    fig, ax, plt = nmrplot(dat; colorrange=(1e5, 1e6))
    @test plt isa Makie.Volume
end
