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
    # Default max projection on both edges.
    fig, ax, plt = nmrplot(dat; xprojection=true, yprojection=true)
    @test ax isa Makie.Axis
    # Sum projection.
    fig, ax, plt = nmrplot(dat; xprojection=:sum, yprojection=:sum)
    @test ax isa Makie.Axis
    # Only one side.
    fig, ax, plt = nmrplot(dat; xprojection=true)
    @test ax isa Makie.Axis
    # User-supplied 1D spectrum on the x edge.
    slice = dat[:, 1]
    fig, ax, plt = nmrplot(dat; xprojection=slice)
    @test ax isa Makie.Axis
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

@testset "MakieExt: pseudo-2D stack" begin
    dat = exampledata("pseudo2D_XSTE")
    fig, ax, plt = nmrplot(dat; style=:stack)
    @test ax isa Makie.Axis
    @test ax.xreversed[] == true
    @test plt isa Makie.Lines
    @test count(p -> p isa Makie.Lines, ax.scene.plots) == length(dims(dat, 2))
end

@testset "MakieExt: pseudo-2D waterfall" begin
    dat = exampledata("pseudo2D_XSTE")
    fig, ax, plt = nmrplot(dat; style=:waterfall)
    @test ax isa Makie.Axis3
    @test plt isa Makie.Lines
    @test count(p -> p isa Makie.Lines, ax.scene.plots) == length(dims(dat, 2))
end

@testset "MakieExt: 3D iso-surface contours" begin
    dat = exampledata("3D_HNCA")
    fig, ax, plt = nmrplot(dat)
    @test ax isa Makie.Axis3
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2  # pos + neg

    fig, ax, plt = nmrplot(dat; negcontours=false)
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 1

    fig, ax, plt = nmrplot(dat; poscolor=:blue, nlevels=2)
    @test count(p -> p isa Makie.Contour, ax.scene.plots) == 2
end
