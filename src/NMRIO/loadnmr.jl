"""
    loadnmr(filename, experimentfolder=nothing)

Main function for loading NMR data. `experimentfolder` contains the path to an experiment directory,
for identification of metadata, if the filename is not directly within an experiment.

Returns an `NMRData` structure, or throws an `NMRToolsError` is there is a problem.

# Examples

nmrPipe import:

```julia
loadnmr("exampledata/1D_1H/1/test.ft1");
loadnmr("exampledata/1D_19F/1/test.ft1");
loadnmr("exampledata/2D_HN/1/test.ft2");
loadnmr("exampledata/pseudo2D_XSTE/1/test.ft1");
loadnmr("exampledata/pseudo3D_HN_R2/1/ft/test%03d.ft2");
```

bruker pdata import:

```julia
loadnmr("exampledata/1D_19F/1");
loadnmr("exampledata/1D_19F/1/");
loadnmr("exampledata/1D_19F/1/pdata/1");
loadnmr("exampledata/1D_19F/1/pdata/1/");
```
"""
function loadnmr(filename; experimentfolder=nothing, allcomponents=false)
    # 1. get format
    format, filename = getformat(filename)

    # 2. get acqus metadata
    aqdic = getacqusmetadata(format, filename, experimentfolder)

    # 3. load data
    if format == :nmrpipe
        spectrum = loadnmrpipe(filename)
    elseif format == :pdata
        # TODO bruker pdata import
        spectrum = loadpdata(filename, allcomponents)
    else
        # unknown format
        throw(NMRToolsError("unknown file format for loadnmr\nfilename = " * filename))
    end

    # 4. merge in acqus metadata
    merge!(metadata(spectrum), aqdic)

    # 5. estimate the spectrum noise level
    estimatenoise!(spectrum)

    return spectrum
end

"""
    getformat(filename)

Take an input filename and return either :nmrpipe, :pdata (bruker processed), or :unknown after checking
whether the filename matches any known format.
"""
function getformat(filename)
    # NMRPipe: match XXX.ft, test.ft1, test.ft2, test.ft3, test.ft4, test001.ft1, test0001.ft3, ...
    ispipe = occursin(r"[a-zA-Z0-9]+(\%0[34]d)?\.ft[1234]?$", filename)
    ispipe && return :nmrpipe, filename

    # Bruker: match pdata/1, 123/pdata/101, 1/pdata/23/, etc...
    # NB. This relies on identifying the pdata folder, so would fail if the working directory is already the pdata
    isbruker = occursin(r"pdata/[0-9]+/?$", filename)
    isbruker && return :pdata, filename

    # No pdata directory specified? Test if filename/pdata/1 exists
    # If it does, return the updated path filename/pdata/1
    if isdir(filename)
        testpath = joinpath(filename, "pdata", "1")
        isdir(testpath) && return :pdata, testpath
    end

    return :unknown, filename
end