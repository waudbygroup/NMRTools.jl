"""
    loadnmr(template::String)

Main function for loading nmrPipe or bruker format NMR data.

Returns an NMRData object, or throws an NMRToolsException is there is a problem.

# Examples

nmrPipe import:

```julia
loadnmr("exampledata/1D_1H/test.ft1");
loadnmr("exampledata/1D_19F/test.ft1");
loadnmr("exampledata/2D_HN/test.ft2");
loadnmr("exampledata/pseudo2D_XSTE/test.ft1");
loadnmr("exampledata/pseudo3D_HN_R2/ft/test%03d.ft2");
```

bruker import:

```julia
loadnmr("exampledata/1D_19F/pdata/1/1r");
```
"""
function loadnmr(template::String)
    if occursin(r"[a-z0-9]+\.ft[12]$", template)
        loadnmrpipe(template)
    else
        # TODO bruker import
        throw(NMRToolsException("unknown file format for loadnmr\ntemplate = " * template))
    end
end

function loadnmrpipe(template::String)
    # TODO
    print("loading nmrpipe...")
end
