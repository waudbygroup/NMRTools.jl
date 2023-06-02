using NMRTools, Plots
using Test


@testset "PlotsExt: 1D 19F" begin
    dat = loadnmr("../exampledata/1D_19F/1/test.ft1");

    pr=Plots.RecipesBase.apply_recipe(Dict{Symbol,Any}(), dat)

    @test pr[1].plotattributes[:xguide] == "19F chemical shift (ppm)"
    @test pr[1].plotattributes[:title] == "Example 19F 1D spectrum"
    @test pr[1].plotattributes[:xflip] == true
    @test pr[1].plotattributes[:xtick_direction] == :out
    @test pr[1].plotattributes[:yshowaxis] == false

    @test pr[1].args[1][1] == -124.16252020246354
    @test r[1].args[2][1] == 1.2039054352746015
end

@testset "PlotsExt: 2D HN" begin
    dat = loadnmr("../exampledata/2D_HN/1/pdata/1")

    pr=Plots.RecipesBase.apply_recipe(Dict{Symbol,Any}(), dat)

    @test pr[1].plotattributes[:normalize] == true
    @test pr[1].args[2][1,1] == 20.85546875

    @test label(pr[1].args[2]) == "13C,15N ubiquitin"
end
