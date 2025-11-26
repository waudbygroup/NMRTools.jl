function exampledata()
    return println("""
       Usage: exampledata("1D_19F_titration")

       Available example data:
       - 1D_1H
       - 1H_19F
       - 1H_19F_titration
       - 2D_HN
       - 2D_HN_titration
       - pseudo2D_T2
       - pseudo2D_XSTE
       - pseudo3D_HN_R2
       - pseudo3D_kinetics
       - 3D_HNCA
       """)
end

"""
    exampledata(name::String)

Load example NMR data provided with NMRTools.jl

# Arguments
- name::String : Name of example data set to load. Call exampledata() to list available data.

# Returns
- NMR data object(s) corresponding to the requested example data set.

# Example
```julia
data = exampledata("1D_19F_titration")
```
"""
function exampledata(name)
    if name == "1D_1H"
        loadnmr(artifact"1D_1H")
    elseif name == "1D_19F"
        loadnmr(artifact"1D_19F")
    elseif name == "1D_19F_titration"
        filenames = [joinpath(artifact"1D_19F_titration", "$i") for i in 1:11]
        map(loadnmr, filenames)
    elseif name == "2D_HN"
        loadnmr(artifact"2D_HN")
    elseif name == "2D_HN_titration"
        filenames = [joinpath(artifact"2D_HN_titration", "$i/test.ft2") for i in 1:11]
        map(loadnmr, filenames)
    elseif name == "pseudo2D_T2"
        loadnmr(artifact"pseudo2D_T2")
    elseif name == "pseudo2D_XSTE"
        loadnmr(artifact"pseudo2D_XSTE")
    elseif name == "pseudo3D_HN_R2"
        loadnmr(artifact"pseudo3D_HN_R2")
    elseif name == "pseudo3D_kinetics"
        loadnmr(artifact"pseudo3D_kinetics")
    elseif name == "3D_HNCA"
        loadnmr(artifact"3D_HNCA")
    else
        throw(NMRToolsError("example data $name not found. Call exampledata() to list available data"))
    end
end