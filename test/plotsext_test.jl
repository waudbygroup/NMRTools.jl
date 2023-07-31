using NMRTools
using Plots
using Test
using VisualRegressionTests


@testset "PlotsExt: 1D 19F" begin
    dat = loadnmr("../exampledata/1D_19F/1/pdata/1");

    pr=Plots.RecipesBase.apply_recipe(Dict{Symbol,Any}(), dat)

    @test pr[1].plotattributes[:xguide] == "19F chemical shift (ppm)"
    @test pr[1].plotattributes[:title] == "Example 19F 1D spectrum"
    @test pr[1].plotattributes[:xflip] == true
    @test pr[1].plotattributes[:xtick_direction] == :out
    @test pr[1].plotattributes[:yshowaxis] == false

    @test pr[1].args[1][1] == -124.16252020246354
    @test pr[1].args[2][1] == 1.2039054352746015
end

@testset "PlotsExt: 2D HN" begin
    dat = loadnmr("../exampledata/2D_HN/1/pdata/1")

    pr=Plots.RecipesBase.apply_recipe(Dict{Symbol,Any}(), dat)

    @test pr[1].plotattributes[:normalize] == true
    @test pr[1].args[2][1,1] == 20.85546875

    @test label(pr[1].args[2]) == "13C,15N ubiquitin"
end


@testset "PlotsExt: visual regression testing" begin
    dat1 = loadnmr("../exampledata/1D_19F/1/")
    @plottest begin
        plot(dat1)
    end "plot_1D_19F.png" false

    dat2 = loadnmr("../exampledata/2D_HN/1")
    @plottest begin
        plot(dat2)
    end "plot_2D_HN.png" false

    dat3 = loadnmr("../exampledata/pseudo2D_XSTE/1/pdata/1")
    dat3 = setgradientlist(dat3, LinRange(0.05, 0.95, 10), 0.55)
    @plottest begin
        plot(dat3[7..9,:])
    end "plot_pseudo2D_XSTE.png" false
    @plottest begin
        heatmap(dat3[7..9,:])
    end "plot_pseudo2D_XSTE_heatmap.png" false

    dat4 = [loadnmr("../exampledata/1D_19F_titration/$i") for i=1:11]
    @plottest begin
        plot(dat4, xlims=(-125,-122))
    end "plot_1D_19F_titration.png" false
    @plottest begin
        plot(dat4, xlims=(-125,-121), vstack=true)
    end "plot_1D_19F_titration_vstack.png" false

    dat5 = [loadnmr("../exampledata/2D_HN_titration/$i/test.ft2") for i=1:11]
    @plottest begin
        plot(dat5)
    end "plot_2D_HN_titration.png" false
    @plottest begin
        plot(dat5[1])
        plot!(dat5[11], c=:red)
        xlims!(7,8)
        ylims!(115,120)
    end "plot_2D_HN_overlay.png" false
end
