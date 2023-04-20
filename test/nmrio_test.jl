using NMRTools
using Test


@testset "NMRIO: 1D 19F (nmrPipe)" begin
    dat = loadnmr("../exampledata/1D_19F/test.ft1");

    @test size(dat) == (8751,)
    @test length(dat) == 8751

    @test parent(dat) isa Vector{Float64}

    @test dat[1] == -3741.875
    @test dat[end] == 5973.625
    @test maximum(dat) == 1.274037375e6

    @test label(dat) == "Example 19F 1D spectrum"
    @test dat[:title] == """Example 19F 1D spectrum
    Sample details in second line
    and third line"""
    @test dat[:ns] == 64
    @test dat[:rg] == 76.02
    @test dat[:format] == :nmrpipe
    @test dat[:ndim] == 1

    @test scale(dat) == 4865.28

    @test acqus(dat, :pulprog) == "zg"
    @test acqus(dat, :p, 1) == 13.25
    @test acqus(dat, "P", 2) == 22
    @test acqus(dat, :D, 1) == 4
    @test acqus(dat)["TE"] == 318.1509

    @test dims(dat,1) isa FrequencyDim
    @test length(dims(dat,1)) == 8751
    @test dims(dat,1)[1] == -119.99959383646768
    @test dims(dat,1)[2] == -120.00050820180846
    @test dims(dat,1)[end] == -128.00029056823928

    @test metadata(dat,1,:sf) == 470.5224736346634
    @test dat[1,:bf] == 470.5220031738281
    @test label(dat,1) == "19F"
    @test dat[1,:td] == 14097
    @test dat[1,:tdzf] == 32768
    @test dat[1,:region] == 5448:14198
    @test dat[1,:offsetppm] == -130
    @test dat[1,:window] == ExponentialWindow(5.0, 3.744288662922463)
    @test dat[1,:swhz] == 3764.93408203125
    @test dat[1,:swppm] == 8.00161109711238
    @test dat[1,:pseudodim] == false
end


@testset "NMRIO: 2D HN (nmrPipe)" begin
    dat = loadnmr("../exampledata/2D_HN/test.ft2");

    @test size(dat) == (568, 256)
    @test length(dat) == 145408

    @test parent(dat) isa Matrix{Float64}

    @test dat[1,100] == 59228.95703125
    @test dat[20,100] == 27169.9140625
    @test dat[1] == -48482.26171875
    @test dat[1,end] == 36429.125
    @test dat[end,end] == -23958.6171875
    @test dat[end] == -23958.6171875
    @test maximum(dat) == 7.984743e6

    @test dat[Near(8.3), Near(120)] == 81722.171875
    @test dat[Between(8.3,8.35), Near(120)] == [
        86881.734375
        115982.59375
        115535.171875
        84537.9296875
        51392.3046875
        81722.171875
    ]
    @test dat[Near(8.4), Between(110,111)] == [
        -22987.546875
        18746.140625
        35149.3359375
        21203.44140625
        -2393.46875
        -22528.533203125
        -27708.4296875
        -3501.19873046875
        39905.0
        63979.9765625
        51346.94140625
        33063.59375
    ]
    @test dat[Between(8.6,8.62), Between(108,108.4)] == [
        57461.02734375 25821.890625 -20170.22265625 -16362.2734375
        27847.72265625 9394.47265625 -34206.65625 -59513.51171875
        -34801.6171875 -85781.984375 -96177.78125 -83699.1171875
    ]

    @test label(dat) == "13C,15N ubiquitin"
    @test dat[:title] == """13C,15N ubiquitin
    500 uM in 10% D2O, 20 mM Pi pH 6.5, 277 K, SOFAST-HMQC"""
    @test dat[:ns] == 2
    @test dat[:rg] == 203
    @test dat[:format] == :nmrpipe
    @test dat[:ndim] == 2

    @test scale(dat) == 406

    @test acqus(dat, :pulprog) == "sfhmqcf3gpph.cw"
    @test acqus(dat, :p, 1) == 9.2
    @test acqus(dat, "P", 2) == 18.4
    @test acqus(dat, :D, 1) == 0.1
    @test acqus(dat)["TE"] == 276.9988

    @test dims(dat,1) isa FrequencyDim
    @test length(dims(dat,1)) == 568
    @test dims(dat,1)[1] == 10.996211600312328
    @test dims(dat,1)[2] == 10.987407197534884
    @test dims(dat,1)[end] == 6.004115225500486

    @test metadata(dat,1,:sf) == 600.2036031356758
    @test dat[1,:bf] == 600.2030029296875
    @test label(dat,1) == "HN"
    @test dat[1,:td] == 1024
    @test dat[1,:tdzf] == 2048
    @test dat[1,:region] == 341:908
    @test dat[1,:offsetppm] == 4.973999977111816
    @test dat[1,:window] == CosWindow(0.3411564250699426)
    @test dat[1,:swhz] == 3001.5556640625
    @test dat[1,:swppm] == 5.000900777589288
    @test dat[1,:pseudodim] == false

    metadata(dat,2,:sf) == 60.825061595134905
    dat[2,:bf] == 60.82500076293945
    label(dat,2) == "15N"
    dat[2,:td] == 128
    dat[2,:tdzf] == 256
    ismissing(dat[2,:region])
    dat[2,:offsetppm] == 118.28500366210938
    dat[2,:window] == CosWindow(0.09566717062018215)
    dat[2,:swhz] == 1337.9720458984375
    dat[2,:swppm] == 21.997074050406937
    dat[2,:pseudodim] == false
end



@testset "NMRIO: pseudo-2D XSTE (nmrPipe)" begin
    dat = loadnmr("../exampledata/pseudo2D_XSTE/test.ft1");

    @test size(dat) == (206, 10)
    @test length(dat) == 2060

    @test parent(dat) isa Matrix{Float64}

    @test dat[100,5] == 193505.375
    @test dat[1,end] == 413.376953125
    @test dat[1] == 8857.43359375
    @test dat[end] == -5065.54248046875
    @test maximum(dat) == 1.277118e6

    @test dat[Near(8.3), 1] == 635359.375
    @test dat[Between(8.3,8.35), 9] == [
        241633.140625
        219759.296875
    ]
    @test dat[Near(8.4), :] == [
        1.277118e6
        1.247608625e6
        1.1866e6
        1.094307375e6
        996278.0625
        887989.875
        775422.0
        641461.4375
        520499.28125
        399827.28125
    ]
    @test dat[Between(7.8,7.86), 3:5] == [
        27620.0078125 14238.609375 15452.2421875
        15589.8359375 -10553.5 -1367.3984375
        14052.1484375 -4170.84375 -2667.4921875
    ]

    @test label(dat) == "15N aSyn, 283 K - XSTE"
    @test dat[:title] == """15N aSyn, 283 K - XSTE
    DELTA = 100ms, delta = 4ms, G = 5-95%"""
    @test dat[:ns] == 16
    @test dat[:rg] == 128
    @test dat[:format] == :nmrpipe
    @test dat[:ndim] == 2

    @test scale(dat) == 2048

    @test acqus(dat, :pulprog) == "stebpgp1s19xn.jk"
    @test acqus(dat, :p, 1) == 9.25
    @test acqus(dat, "P", 2) == 18.5
    @test acqus(dat, :D, 1) == 1
    @test acqus(dat)["TE"] == 283.0556

    @test dims(dat,1) isa FrequencyDim
    @test length(dims(dat,1)) == 206
    @test dims(dat,1)[1] == 9.995628344572216
    @test dims(dat,1)[2] == 9.976091311209679
    @test dims(dat,1)[end] == 5.990536505252104

    @test metadata(dat,1,:sf) == 499.85248960054076
    @test dat[1,:bf] == 499.85198974609375
    @test label(dat,1) == "1H"
    @test dat[1,:td] == 512
    @test dat[1,:tdzf] == 1024
    @test dat[1,:region] == 253:458
    @test dat[1,:offsetppm] == 4.915999889373779
    @test dat[1,:window] == CosWindow(0.2545087378640777)
    @test dat[1,:swhz] == 2011.71875
    @test dat[1,:swppm] == 4.024628872682649
    @test dat[1,:pseudodim] == false

    metadata(dat,2,:sf) === nothing
    dat[2,:bf] === nothing
    label(dat,2) == "TAU"
    dat[2,:npoints] == 10
    dat[2,:td] === nothing
    dat[2,:tdzf] === nothing
    dat[2,:region] === nothing
    dat[2,:pseudodim] == true
end
