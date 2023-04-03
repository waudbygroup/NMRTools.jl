using NMRTools
using Test


@testset "NMRBase: dimensions" begin
    axH = FrequencyDim(8:.1:9)
    dat = NMRData(0.:1:10, (axH,))

    @test dims(dat,1) isa FrequencyDim
    @test dat[1] == 0
    @test dat[1:3] == [0., 1., 2.]
    @test dat[end] == 10
    @test length(dat) == 11
    @test size(dat) == (11,)
    @test (2dat .+ 1)[[1,end]] == [1., 21.]
    
    @test dat[At(8.5)] == 5
    @test dat[Near(8.5)] == 5
    @test dat[Near(8.49)] == 5
    @test dat[Near(8.54)] == 5
    @test dat[8.4..8.6] == [4, 5, 6]
    @test dat[8.41..8.6] == [5, 6]

    @test_throws DimensionMismatch NMRData(0.:1:9, (axH,))  # size of axis and data don't match
end

@testset "NMRBase: metadata" begin
    # create some test data
    axH = FrequencyDim(8:.1:9)
    dat = NMRData(0.:1:10, (axH,))

    # NMRData metadata
    @test metadata(dat) isa Metadata{NMRData}
    @test metadata(dat) == defaultmetadata(NMRData)
    @test metadata(dat)[:title] == ""
    @test label(dat) == ""
    @test isnothing(units(dat))

    # dimension metadata
    axH = FrequencyDim(8:.1:9)
    dat = NMRData(0.:1:10, (axH,))
    @test metadata(dat, 1) isa Metadata{FrequencyDim}
    @test metadata(dat, 1) == defaultmetadata(FrequencyDim)
    @test isnothing(metadata(dat, 1)[:window])
    @test label(dims(dat, 1)) == ""
    @test isnothing(units(dims(dat, 1)))

    axH = FrequencyDim(8:.1:9, metadata=NoMetadata())
    dat = NMRData(0.:1:10, (axH,))
    @test metadata(dat, 1) isa Metadata{FrequencyDim}
    @test metadata(dat, 1) == defaultmetadata(FrequencyDim)
    @test isnothing(metadata(dat, 1)[:window])
    @test label(dims(dat, 1)) == ""
    @test isnothing(units(dims(dat, 1)))

    axH = FrequencyDim(8:.1:9, metadata=Metadata{FrequencyDim}(:test=>123))
    dat = NMRData(0.:1:10, (axH,))
    @test metadata(dat, 1) isa Metadata{FrequencyDim}
    @test issubset(defaultmetadata(FrequencyDim), metadata(dat, 1))
    @test isnothing(metadata(dat, 1)[:window])
    @test label(dims(dat, 1)) == ""
    @test isnothing(units(dims(dat, 1)))
    @test metadata(dat, 1)[:test] == 123
end

