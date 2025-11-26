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
    spec2 = shiftdim(spec, 1, 0.5)
    @test data(spec2, 1)[1] - data(spec, 1)[1] == 0.5
    spec2 = shiftdim(spec2, F1Dim, 0.5)
    @test data(spec2, 1)[1] - data(spec, 1)[1] == 1

    # Test ppm() and hz() functions for FrequencyDimension
    ax = dims(spec, 1)

    # Test ppm(axis) - should return same as data(axis)
    @test ppm(ax) == data(ax)
    @test ppm(ax)[1] isa Float64

    # Test hz(axis) - should convert ppm to Hz offsets
    hz_offsets = hz(ax)
    bf = ax[:bf]
    offsetppm = ax[:offsetppm]
    @test hz_offsets[1] ≈ bf * (data(ax)[1] - offsetppm) * 1e-6
    @test hz_offsets[end] ≈ bf * (data(ax)[end] - offsetppm) * 1e-6

    # Test hz(δ, axis) - should convert single ppm value to Hz
    test_ppm = 7.5
    hz_single = hz(test_ppm, ax)
    @test hz_single ≈ bf * (test_ppm - offsetppm) * 1e-6

    # Test hz(δ, axis) with array of values
    test_ppms = [7.0, 7.5, 8.0]
    hz_array = hz(test_ppms, ax)
    @test length(hz_array) == 3
    @test hz_array[1] ≈ bf * (7.0 - offsetppm) * 1e-6
    @test hz_array[2] ≈ bf * (7.5 - offsetppm) * 1e-6
    @test hz_array[3] ≈ bf * (8.0 - offsetppm) * 1e-6
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

@testset "NMRBase: annotations" begin
    # Test with 19F CEST data
    cest_data = loadnmr(joinpath("test-data", "19f-cest-ts3"))

    # Test basic annotation access - returns entire annotations dictionary
    all_annot = annotations(cest_data)
    @test all_annot isa Dict{String,Any}
    @test haskey(all_annot, "title")

    # Test single key access with string
    @test annotations(cest_data, "title") == "19F CEST"

    # Test single key access with symbol
    @test annotations(cest_data, :title) == "19F CEST"

    # Test array access
    exp_type = annotations(cest_data, "experiment_type")
    @test exp_type isa Vector
    @test "cest" in exp_type

    # Test dimensions array
    dims_array = annotations(cest_data, "dimensions")
    @test dims_array[2] == "cest.offset"
    @test annotations(cest_data, "dimensions", 2) == "cest.offset"

    # Test nested dictionary access
    spinlock = annotations(cest_data, "cest")
    @test spinlock isa Dict
    @test annotations(cest_data, "cest", "channel") == "19F"
    @test annotations(cest_data, "cest", "duration") == 1
    @test annotations(cest_data, "cest.offset") isa FQList

    # Test FQList conversion functions
    fqlist = annotations(cest_data, "cest.offset")
    dim = dims(cest_data, F1Dim)

    # Test hz() for FQList (Hz, relative) - should return values as-is since they're already Hz relative
    hz_values = hz(fqlist, dim)
    @test hz_values[1] ≈ -2500.0  # First value
    @test hz_values[51] ≈ 0.0     # Middle value (on-resonance)
    @test hz_values[end] ≈ 2500.0 # Last value

    # Test ppm() for FQList - should convert to absolute ppm
    ppm_values = ppm(fqlist, dim)
    bf = dim[:bf]
    offsetppm = dim[:offsetppm]
    # Expected: offsetppm + Hz/bf*1e6
    @test ppm_values[1] ≈ offsetppm + (-2500.0 / bf * 1e6)
    @test ppm_values[51] ≈ offsetppm  # On-resonance point
    @test ppm_values[end] ≈ offsetppm + (2500.0 / bf * 1e6)

    # Test array of dictionaries (reference_pulse)
    refs = annotations(cest_data, "reference_pulse")
    @test refs isa Vector
    @test length(refs) == 1
    @test refs[1] isa Dict
    @test refs[1]["duration"] ≈ 13.29e-6
    @test annotations(cest_data, :reference_pulse, 1)["duration"] ≈ 13.29e-6
    p, pl = referencepulse(cest_data, "19F")
    @test p ≈ 13.29e-6
    @test watts(pl) ≈ 8.0
end

@testset "NMRBase: FQList conversions" begin
    # Create a test axis with known parameters
    spec = exampledata("1D_1H")
    ax = dims(spec, 1)
    bf = ax[:bf]
    offsetppm = ax[:offsetppm]

    # Test 1: Hz, relative (most common case)
    fq_hz_rel = FQList([-100.0, 0.0, 100.0], :Hz, true)
    @test hz(fq_hz_rel, ax) ≈ [-100.0, 0.0, 100.0]
    @test ppm(fq_hz_rel, ax) ≈ [offsetppm - 100.0 / bf * 1e6,
                                offsetppm,
                                offsetppm + 100.0 / bf * 1e6]

    # Test 2: Hz, absolute
    test_hz_abs = [bf * 7.0 * 1e-6,
                   bf * 7.5 * 1e-6,
                   bf * 8.0 * 1e-6]
    fq_hz_abs = FQList(test_hz_abs, :Hz, false)
    @test ppm(fq_hz_abs, ax) ≈ [7.0, 7.5, 8.0]
    @test hz(fq_hz_abs, ax) ≈ test_hz_abs .- ax[:offsethz]

    # Test 3: ppm, relative
    fq_ppm_rel = FQList([0.1, 0.0, -0.1], :ppm, true)
    @test ppm(fq_ppm_rel, ax) ≈ [offsetppm + 0.1, offsetppm, offsetppm - 0.1]
    @test hz(fq_ppm_rel, ax) ≈ [0.1 * bf * 1e-6, 0.0, -0.1 * bf * 1e-6]

    # Test 4: ppm, absolute (chemical shifts)
    fq_ppm_abs = FQList([7.0, 7.5, 8.0], :ppm, false)
    @test ppm(fq_ppm_abs, ax) ≈ [7.0, 7.5, 8.0]
    @test hz(fq_ppm_abs, ax) ≈ [(7.0 - offsetppm) * bf * 1e-6,
                                (7.5 - offsetppm) * bf * 1e-6,
                                (8.0 - offsetppm) * bf * 1e-6]
end

@testset "NMRBase: nuclei and coherences" begin
    @testset "parse nucleus tests" begin
        @testset "Mass number followed by element symbol" begin
            @test nucleus("1H") == H1
            @test nucleus("2H") == H2
            @test nucleus("12C") == C12
            @test nucleus("13C") == C13
            @test nucleus("14N") == N14
            @test nucleus("15N") == N15
            @test nucleus("19F") == F19
            @test nucleus("31P") == P31
        end

        @testset "Element symbol followed by mass number" begin
            @test nucleus("H1") == H1
            @test nucleus("H2") == H2
            @test nucleus("C12") == C12
            @test nucleus("C13") == C13
            @test nucleus("N14") == N14
            @test nucleus("N15") == N15
            @test nucleus("F19") == F19
            @test nucleus("P31") == P31
        end

        @testset "Case insensitive parsing" begin
            @test nucleus("19f") == F19
            @test nucleus("1h") == H1
            @test nucleus("13c") == C13
            @test nucleus("h1") == H1
            @test nucleus("c13") == C13
            @test nucleus("f19") == F19
        end

        @testset "Whitespace handling" begin
            @test nucleus(" 19F ") == F19
            @test nucleus("  1H  ") == H1
            @test nucleus("\t13C\n") == C13
        end

        @testset "Invalid nucleus strings" begin
            @test_throws ArgumentError nucleus("16O")  # Not defined in enum
            @test_throws ArgumentError nucleus("23Na") # Not defined in enum
            @test_throws ArgumentError nucleus("O16")  # Not defined in enum
            @test_throws ArgumentError nucleus("Na23") # Not defined in enum
        end

        @testset "Invalid format strings" begin
            @test_throws ArgumentError nucleus("H")     # Missing mass number
            @test_throws ArgumentError nucleus("13")    # Missing element
            @test_throws ArgumentError nucleus("ABC13") # Invalid element
            @test_throws ArgumentError nucleus("13XYZ") # Invalid element
            @test_throws ArgumentError nucleus("")      # Empty string
            @test_throws ArgumentError nucleus("H1C")   # Invalid format
            @test_throws ArgumentError nucleus("1H2")   # Invalid format
        end

        @testset "Edge cases" begin
            @test_throws ArgumentError nucleus("0H")    # Zero mass number
            @test_throws ArgumentError nucleus("H0")    # Zero mass number
            @test_throws ArgumentError nucleus("1000H") # Very large mass number
        end
    end # nucleus tests

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

    @test lineshape(dims(dat, 1), 8.0, 5)[1] ≈ 1.1210822807171034e-8
    @test lineshape(dims(dat, 1), 8.0, 5)[682] ≈ -0.00011946940995147479
    @test lineshape(dims(dat, 1), 8.0, 5)[686] ≈ 0.02244850216794408
    @test lineshape(dims(dat, 1), 8.0, 5, ComplexLineshape())[1] ≈
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
    specs = [loadnmr(joinpath(artifact"1D_19F_titration", "1")),
             loadnmr(joinpath(artifact"1D_19F_titration", "2")),
             loadnmr(joinpath(artifact"1D_19F_titration", "3"))]
    stacked = stack(specs)
    @test size(stacked) == (32768, 3)

    specs2 = [loadnmr(joinpath(artifact"1D_19F_titration", "1")),
              exampledata("2D_HN")]
    @test_throws DimensionMismatch stack(specs2)

    specs3 = [loadnmr(joinpath(artifact"2D_HN_titration", "1/test.ft2")),
              loadnmr(joinpath(artifact"2D_HN_titration", "2/test.ft2")),
              loadnmr(joinpath(artifact"2D_HN_titration", "3/test.ft2")),
              loadnmr(joinpath(artifact"2D_HN_titration", "4/test.ft2"))]
    # expect warning that experiments do not have same rg
    @test (@test_logs (:warn,) size(stack(specs3))) == (768, 512, 4)
end

@testset "NMRBase: Power" begin
    # Test construction from dB
    p1 = Power(30.0, :dB)
    @test db(p1) == 30.0
    @test watts(p1) ≈ 0.001

    # Test construction from Watts
    p2 = Power(1.0, :W)
    @test watts(p2) == 1.0
    @test db(p2) == 0.0

    # Test with integer input
    p3 = Power(10, :W)
    @test watts(p3) == 10.0
    @test db(p3) ≈ -10.0

    # Test zero Watts handling
    p4 = Power(0.0, :W)
    @test db(p4) == 120.0
    @test watts(p4) ≈ 1e-12

    # Test error for missing unit
    @test_throws ArgumentError Power(10)

    # Test error for invalid unit
    @test_throws ArgumentError Power(10, :V)

    # Test roundtrip conversions
    original_watts = 0.5
    p5 = Power(original_watts, :W)
    @test watts(p5) ≈ original_watts

    original_db = -6.0
    p6 = Power(original_db, :dB)
    @test db(p6) == original_db

    # Test pretty printing contains both units
    p7 = Power(20.0, :dB)
    output = string(p7)
    @test occursin("dB", output)
    @test occursin("W", output)
end