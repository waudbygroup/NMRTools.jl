"""
    loadnmr(filename, experimentfolder=nothing)

Main function for loading NMR data. `experimentfolder` contains the path to an experiment directory,
for identification of metadata, if the filename is not directly within an experiment.

Returns an `NMRData` structure, or throws an `NMRToolsException` is there is a problem.

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
loadnmr("exampledata/1D_19F/pdata/1/");
```
"""
function loadnmr(filename, experimentfolder=nothing)
    format = getformat(filename)

    # 1. load data
    if format==:nmrpipe
        spectrum = loadnmrpipe(filename)
        spectrum[:format] = :nmrpipe
    elseif format==:bruker
        # TODO bruker import
        throw(NMRToolsException("bruker import not yet implemented\nfilename = " * filename))
    else
        # unknown format
        throw(NMRToolsException("unknown file format for loadnmr\nfilename = " * filename))
    end

    # 2. add filename to metadata
    spectrum[:filename] = filename

    # 3. load acquisition metadata
    addexptmetadata!(spectrum, filename, experimentfolder)

    # 4. estimate the spectrum noise level
    # TODO
    # estimatenoise!(spectrum)

    return spectrum
end


"""
    getformat(filename)

Take an input filename and return either :nmrpipe, :bruker, or :unknown after checking
whether the filename matches any known format.
"""
function getformat(filename)
    # NMRPipe: match XXX.ft, test.ft1, test.ft2, test.ft3, test.ft4, test001.ft1, test0001.ft3, ...
    ispipe = occursin(r"[a-zA-Z0-9]+(\%0[34]d)?\.ft[1234]?$", filename)
    ispipe && return :nmrpipe

    # Bruker: match pdata/1, 123/pdata/101, 1/pdata/23/, etc...
    # NB. This relies on identifying the pdata folder, so would fail if the working directory is already the pdata
    isbruker = occursin(r"pdata/[0-9]+/?$", filename)
    isbruker && return :bruker

    return :unknown
end