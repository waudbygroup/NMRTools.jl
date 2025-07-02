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

@testset "NMRBase: metadata deep-copy behavior" begin
    # Test that metadata is properly deep-copied during slicing and copying operations
    axH = F1Dim(8:0.1:9)
    original = NMRData(0.0:1:10, (axH,))
    
    # Set some metadata
    original[:title] = "Original Data"
    original[:label] = "Test Spectrum"
    original[:custom_field] = "test_value"
    
    # Test slicing creates deep copies of metadata
    slice1 = original[1:5]
    slice2 = original[6:10]
    
    # Verify initial values are copied
    @test slice1[:title] == "Original Data"
    @test slice2[:title] == "Original Data"
    @test slice1[:label] == "Test Spectrum"
    @test slice2[:label] == "Test Spectrum"
    @test slice1[:custom_field] == "test_value"
    @test slice2[:custom_field] == "test_value"
    
    # Modify metadata in slice1
    slice1[:title] = "Modified by slice1"
    slice1[:label] = "Changed label"
    slice1[:custom_field] = "changed_value"
    
    # Verify metadata objects are separate (deep-copied)
    @test original[:title] == "Original Data"  # Should remain unchanged
    @test original[:label] == "Test Spectrum"  # Should remain unchanged
    @test original[:custom_field] == "test_value"  # Should remain unchanged
    
    @test slice2[:title] == "Original Data"  # Should remain unchanged
    @test slice2[:label] == "Test Spectrum"  # Should remain unchanged
    @test slice2[:custom_field] == "test_value"  # Should remain unchanged
    
    @test slice1[:title] == "Modified by slice1"
    @test slice1[:label] == "Changed label"
    @test slice1[:custom_field] == "changed_value"
    
    # Test that metadata objects are not identical (not sharing references)
    @test original.metadata !== slice1.metadata
    @test original.metadata !== slice2.metadata
    @test slice1.metadata !== slice2.metadata
    
    # Test copying NMRData from another NMRData also deep-copies metadata
    copy1 = NMRData(original)
    copy1[:title] = "Copy modified"
    @test original[:title] == "Original Data"  # Should remain unchanged
    @test copy1[:title] == "Copy modified"
    @test original.metadata !== copy1.metadata
    
    # Test arithmetic operations preserve metadata independence
    sum_data = slice1 + slice2  # This should work now with deep-copied metadata
    @test sum_data[:title] == slice1[:title]  # Takes metadata from first operand
    sum_data[:title] = "Sum modified"
    @test slice1[:title] == "Modified by slice1"  # Should remain unchanged
    @test slice2[:title] == "Original Data"  # Should remain unchanged
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