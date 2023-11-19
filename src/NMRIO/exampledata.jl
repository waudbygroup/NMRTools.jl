function exampledata()
    println("Available example data:")
    println("- 1D_1H")
    println("- 1H_19F")
    println("- 1H_19F_titration")
    println("- 2D_HN")
    println("- 2D_HN_titration")
end

function exampledata(name)
    if name == "1D_1H"
        loadnmr(joinpath(artifact"1D_1H", "1"))
    elseif name == "1D_19F"
        loadnmr(joinpath(artifact"1D_19F", "1"))
    elseif name == "1D_19F_titration"
        filenames = [joinpath(artifact"1D_19F_titration", "$i") for i=1:11]
        map(loadnmr, filenames)
    elseif name == "2D_HN"
        loadnmr(joinpath(artifact"2D_HN", "1"))
    elseif name == "2D_HN_titration"
        filenames = [joinpath(artifact"2D_HN_titration", "$i/test.ft2") for i=1:11]
        map(loadnmr, filenames)
    end
end