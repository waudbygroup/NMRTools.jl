using NMRTools
using Artifacts
using LazyArtifacts
using Test

@testset "NMRBase: NMRData" begin
    dat1a = exampledata("pseudo2D_XSTE")
    dat1b = exampledata("pseudo2D_XSTE")
    dat2 = exampledata("1D_19F")
    dat2b = NMRData(dat2) # create NMRData from another NMRData object
    @test dat1a == dat1b # test equality
    @test dat1a ≠ dat2
    @test dat2b == dat2

    @test Array(dat1a) isa Matrix{Float64}
    @test Array(dat1a)[1, 1] == 167.84442138671875

    @test collect(dat1a) isa Matrix{Float64}
    @test collect(dat1a)[1, 1] == 167.84442138671875

    dat3 = dat1a[:, 3]  # slicing
    @test ndims(dat3) == 1
    @test dat3 isa NMRData{Float64,1}
    @test size(dat3) == (2048,)

    dat3b = dat1a[100, :]  # slicing
    @test ndims(dat3b) == 1
    @test size(dat3b) == (10,)

    @test data(dat2)[1] == 4671.5184326171875
    @test data(dat2, 1)[1] == -119.5922

    @test hasnonfrequencydimension(dat1a) == true
    @test hasnonfrequencydimension(dat2) == false
end

@testset "NMRBase: dimensions" begin
    axH = F1Dim(8:0.1:9)
    dat = NMRData(0.0:1:10, (axH,))

    @test dims(dat, 1) isa FrequencyDimension
    @test dat[1] == 0
    @test dat[1:3] == [0.0, 1.0, 2.0]
    @test dat[end] == 10
    @test length(dat) == 11
    @test size(dat) == (11,)
    @test (2dat .+ 1)[[1, end]] == [1.0, 21.0]

    @test dat[At(8.5)] == 5
    @test dat[Near(8.5)] == 5
    @test dat[Near(8.49)] == 5
    @test dat[Near(8.54)] == 5
    @test dat[8.4 .. 8.6] == [4, 5, 6]
    @test dat[8.41 .. 8.6] == [5, 6]

    @test_throws DimensionMismatch NMRData(0.0:1:9, (axH,))  # size of axis and data don't match

    # 2D data
    x = 8:0.1:9
    y = 100:120
    z = x .+ y'  # 11 x 21
    axH = F1Dim(x)
    axN = F2Dim(y)
    dat = NMRData(z, (axH, axN))

    @test size(dat) == (11, 21)
    @test length(dat) == 11 * 21
    @test dat[1, :] == y .+ 8
    @test dat[:, 1] == x .+ 100
    @test dat[8.2 .. 8.4, 101 .. 102.5] == [109.2 110.2; 109.3 110.3; 109.4 110.4]

    # pseudo-2D data
    axP = X2Dim(y)
    dat = NMRData(z, (axH, axP))
    datK = setkinetictimes(dat, LinRange(0, 2, 21), "min")
    @test units(datK, 2) == "min"
    datR = setrelaxtimes(dat, LinRange(0, 2, 21))
    @test units(datR, 2) == ""
    @test_logs (:warn,
                "a maximum gradient strength of 0.55 T m⁻¹ is being assumed - this is roughly correct for modern Bruker systems but calibration is recommended") setgradientlist(dat,
                                                                                                                                                                                 LinRange(0.05,
                                                                                                                                                                                          0.95,
                                                                                                                                                                                          21))
    datG = setgradientlist(dat, LinRange(0.05, 0.95, 21), 0.55)
    @test data(datG, 2)[end] == 0.5225
    @test units(datG, 2) == "T m⁻¹"

    # offsets
    spec = exampledata("1D_1H")
    spec2 = add_offset(spec, 1, 0.5)
    @test data(spec2,1)[1] - data(spec,1)[1] == 0.5
    spec2 = add_offset(spec2, F1Dim, 0.5)
    @test data(spec2,1)[1] - data(spec,1)[1] == 1

    # reference function - basic functionality
    spec = exampledata("1D_1H")
    # Move peak from 4.7 to 0.0 (offset = -4.7)
    spec_ref = reference(spec, 1, 4.7 => 0.0)
    @test data(spec_ref,1)[1] - data(spec,1)[1] ≈ -4.7
    
    # Test with F1Dim object
    spec_ref2 = reference(spec, F1Dim, 8.5 => 8.0)
    @test data(spec_ref2,1)[1] - data(spec,1)[1] ≈ -0.5
    
    # Test multiple axes referencing with 2D data
    spec2d = exampledata("2D_HN")
    spec2d_ref = reference(spec2d, [1, 2], [4.7, 120.0] => [0.0, 118.0])
    @test data(spec2d_ref,1)[1] - data(spec2d,1)[1] ≈ -4.7
    @test data(spec2d_ref,2)[1] - data(spec2d,2)[1] ≈ -2.0
    
    # Test error handling for mismatched array lengths
    @test_throws NMRToolsError reference(spec2d, [1, 2], [4.7] => [0.0, 118.0])
    @test_throws NMRToolsError reference(spec2d, [1], [4.7, 120.0] => [0.0, 118.0])
    
    # Test XI ratios
    @test xi_ratio(H1) == 1.0
    @test xi_ratio(C13) ≈ 0.251449530
    @test xi_ratio(N15) ≈ 0.101329118
    @test xi_ratio(F19) ≈ 0.940062227
    @test xi_ratio(P31) ≈ 0.404808636
    
    # Test XI ratios for different standards  
    @test xi_ratio(C13, reference_standard=:TMS) == xi_ratio(C13, reference_standard=:DSS)
    @test_throws NMRToolsError xi_ratio(C13, reference_standard=:INVALID)
    
    # Test water chemical shift calculation
    @test water_chemical_shift(25) ≈ 7.572002063983488
    @test water_chemical_shift(0) ≈ 7.83
    @test water_chemical_shift(30) ≈ 7.520515463917526
    
    # Test nucleus detection
    axH_labeled = F1Dim(8:0.1:9, metadata=Dict(:label => "1H"))
    dat_labeled = NMRData(0.0:1:10, (axH_labeled,))
    @test detect_nucleus(dat_labeled, 1) == H1
    
    axC_labeled = F1Dim(0:1:200, metadata=Dict(:label => "13C"))
    dat_c_labeled = NMRData(0.0:1:200, (axC_labeled,))
    @test detect_nucleus(dat_c_labeled, 1) == C13
    
    # Test nucleus detection from chemical shift range
    axH_range = F1Dim(0:0.1:12)  # 1H range
    dat_h_range = NMRData(0.0:1:120, (axH_range,))
    @test detect_nucleus(dat_h_range, 1) == H1
    
    axC_range = F1Dim(0:1:200)  # 13C range  
    dat_c_range = NMRData(0.0:1:200, (axC_range,))
    @test detect_nucleus(dat_c_range, 1) == C13
    
    # Test heteronuclear referencing with synthetic data
    axH = F1Dim(0:0.1:12, metadata=Dict(:label => "1H"))
    axC = F2Dim(0:1:200, metadata=Dict(:label => "13C"))
    dat_2d = NMRData(ones(121, 201), (axH, axC))
    
    # Test basic heteronuclear referencing
    dat_hetero = reference_heteronuclear(dat_2d, 1, 0.0, h1_old_shift=4.7, verbose=false)
    @test data(dat_hetero,1)[1] - data(dat_2d,1)[1] ≈ -4.7  # 1H offset
    # 13C offset should be 1H offset / XI ratio: -4.7 / 0.251449530 ≈ -18.692
    @test abs(data(dat_hetero,2)[1] - data(dat_2d,2)[1] - (-4.7 / xi_ratio(C13))) < 0.01
    
    # Test with temperature correction
    dat_temp = reference_heteronuclear(dat_2d, 1, 0.0, temperature=25, verbose=false)
    expected_h1_offset = 0.0 - water_chemical_shift(25)
    @test abs(data(dat_temp,1)[1] - data(dat_2d,1)[1] - expected_h1_offset) < 0.01
    
    # Test with explicit reference standard
    dat_tms = reference_heteronuclear(dat_2d, 1, 0.0, h1_old_shift=4.7, 
                                     reference_standard=:TMS, verbose=false)
    @test data(dat_tms,1)[1] - data(dat_2d,1)[1] ≈ -4.7
end

@testset "NMRBase: metadata" begin
    # create some test data
    axH = F1Dim(8:0.1:9)
    dat = NMRData(0.0:1:10, (axH,))

    # NMRData metadata
    @test metadata(dat) isa Metadata{NMRData}
    @test metadata(dat) == defaultmetadata(NMRData)
    @test metadata(dat)[:title] == ""
    label!(dat, "my spectrum")
    @test label(dat) == "my spectrum"
    @test isnothing(units(dat))

    # dimension metadata
    axH = F1Dim(8:0.1:9)
    dat = NMRData(0.0:1:10, (axH,))
    @test metadata(dat, 1) isa Metadata{FrequencyDimension}
    @test metadata(dat, 1) == defaultmetadata(FrequencyDimension)
    @test isnothing(metadata(dat, 1)[:window])
    @test label(dims(dat, 1)) == ""
    @test isnothing(units(dims(dat, 1)))

    axH = F1Dim(8:0.1:9; metadata=NoMetadata())
    dat = NMRData(0.0:1:10, (axH,))
    @test metadata(dat, 1) isa Metadata{FrequencyDimension}
    @test metadata(dat, 1) == defaultmetadata(FrequencyDimension)
    @test isnothing(metadata(dat, 1)[:window])
    label!(dat, 1, "my label")
    @test label(dims(dat, 1)) == "my label"
    @test isnothing(units(dims(dat, 1)))

    axH = F1Dim(8:0.1:9; metadata=Dict{Symbol,Any}(:test => 123))
    dat = NMRData(0.0:1:10, (axH,))
    @test metadata(dat, 1) isa Metadata{FrequencyDimension}
    @test issubset(defaultmetadata(FrequencyDimension), metadata(dat, 1))
    @test isnothing(metadata(dat, 1)[:window])
    @test label(dims(dat, 1)) == ""
    @test isnothing(units(dims(dat, 1)))
    @test metadata(dat, 1)[:test] == 123
    @test metadata(dims(dat, 1), :test) == 123

    @test metadatahelp(:window) == "Window function"
end

@testset "NMRBase: nuclei and coherences" begin
    @test spin(H1) == 1 // 2
    @test spin(H2) == 1
    @test spin(C12) == 0
    @test gyromagneticratio(H1) == 2.6752218744e8

    @test coherenceorder(SQ(H1)) == 1
    @test coherenceorder(MQ(((H1, 1), (C13, 1)))) == 2
    @test coherenceorder(MQ(((H1, 1), (C13, -1)))) == 0
    @test coherenceorder(MQ(((H1, 3), (C13, 1)))) == 4
    @test coherenceorder(MQ(((H1, 0),))) == 0

    @test gyromagneticratio(SQ(H1)) == 2.6752218744e8
    @test gyromagneticratio(MQ(((H1, 1), (C13, 1)))) == 3.3480498744e8
    @test gyromagneticratio(MQ(((H1, 1), (C13, -1)))) == 2.0023938744e8
    @test gyromagneticratio(MQ(((H1, 3), (C13, 1)))) == 8.698493623199999e8
    @test gyromagneticratio(MQ(((H1, 0),))) == 0
end

@testset "NMRBase: window functions" begin
    dat = exampledata("pseudo2D_XSTE")
    @test dat[1, :window] isa Cos²Window
    @test dat[1, :window].tmax == 0.0512
    @test length(apod(dat, 1)) == 2048
    @test apod(dat, 1)[10] == 0.9992377902866475

    @test lineshape(dims(dat, 1), 8.0, 5)[1] == 1.1210822807171034e-8
    @test lineshape(dims(dat, 1), 8.0, 5)[682] == -0.00011946940995147479
    @test lineshape(dims(dat, 1), 8.0, 5)[686] == 0.02244850216794408
    @test lineshape(dims(dat, 1), 8.0, 5, ComplexLineshape())[1] ==
          1.1210822807171034e-8 + 4.754164488338695e-5im
end

@testset "NMRBase: decimate" begin
    # generic function (not NMR data)
    @test decimate(1:10, 2) == [1.5, 3.5, 5.5, 7.5, 9.5]

    # NMR data
    dat = exampledata("pseudo2D_XSTE")
    @test size(decimate(dat, 10, 1)) == (204, 10)
    @test decimate(dat, 10, 1)[2, 2] == 43.59735595703125
    @test size(decimate(dat, 3, 2)) == (2048, 3)
    @test decimate(dat, 3, 2)[2, 2] == -31.345370822482636
end

@testset "NMRBase: stack" begin
    specs = [loadnmr(joinpath(artifact"1D_19F_titration","1")),
            loadnmr(joinpath(artifact"1D_19F_titration","2")),
            loadnmr(joinpath(artifact"1D_19F_titration","3"))]
    stacked = stack(specs)
    @test size(stacked) == (32768, 3)

    specs2 = [loadnmr(joinpath(artifact"1D_19F_titration","1")),
              exampledata("2D_HN")]
    @test_throws DimensionMismatch stack(specs2)

    specs3 = [loadnmr(joinpath(artifact"2D_HN_titration","1/test.ft2")),
            loadnmr(joinpath(artifact"2D_HN_titration","2/test.ft2")),
            loadnmr(joinpath(artifact"2D_HN_titration","3/test.ft2")),
            loadnmr(joinpath(artifact"2D_HN_titration","4/test.ft2"))]
    # expect warning that experiments do not have same rg
    @test (@test_logs (:warn,) size(stack(specs3))) == (768, 512, 4)
end