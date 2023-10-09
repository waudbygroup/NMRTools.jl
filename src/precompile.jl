@compile_workload begin
    # 1D data
    axH = F1Dim(8:0.1:9; metadata=Dict{Symbol,Any}(:test => 123))
    dat = NMRData(0.0:1:10, (axH,))

    foo = dat[At(8.5)]
    foo = dat[Near(8.5)]
    foo = dat[8.4 .. 8.6]
    foo = dat[8.41 .. 8.6]
    foo = isnothing(metadata(dat, 1)[:window])
    foo = label(dims(dat, 1))
    foo = isnothing(units(dims(dat, 1)))
    foo = metadata(dat, 1)[:test]

    # 2D data
    x = 8:0.1:9
    y = 100:120
    z = x .+ y'  # 11 x 21

    axH = F1Dim(x)
    axN = F2Dim(y)
    dat = NMRData(z, (axH, axN))

    newax = TkinDim(110:130)
    dat = replacedimension(dat, 2, newax)

    # # data import
    # dat = loadnmr("../exampledata/1D_19F/1/test.ft1")
    # dat = loadnmr("../exampledata/1D_19F/1/pdata/1")
    # foo = acqus(dat, :pulprog)
    # foo = dat[1,:window]
    # dat = loadnmr("../exampledata/2D_HN/1/test.ft2")
    # dat = loadnmr("../exampledata/pseudo2D_XSTE/1/test.ft1")
end