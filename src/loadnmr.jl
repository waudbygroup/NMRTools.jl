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
function loadnmr(filename::String)
    if occursin(r"[a-z0-9]+(\%03d)?\.ft[123]?$", filename)
        # match files ending in .ft1 or .ft2
        loadnmrpipe(filename)
    else
        # TODO bruker import
        throw(NMRToolsException("unknown file format for loadnmr\ntemplate = " * template))
    end
end

function loadnmrpipe(filename::String)
    if occursin("%", filename)
        # something like test%03d.ft2 - pseudo3D
        filename = sprintf1(filename, 1)
    end
    # parse the header
    header = loadnmrpipeheader(filename)
end

function loadnmrpipeheader(filename::String)
    # check file exists
    isfile(filename) || throw(NMRToolsException("cannot load $(filename), not a recognised file."))

    # preallocate header
    header = zeros(Float32, 512)

    # read the file
    open(filename) do f
        read!(f, header)
    end

    parsenmrpipeheader(header)
end

function parsenmrpipeheader(header::Vector{Float32})
    # declare constants for clarity in accessing nmrPipe header

    # general parameters (independent of number of dimensions)
    genpars = Dict(
        :FDMAGIC => 1,
        :FDFLTFORMAT => 2,
        :FDFLTORDER => 3,
        :FDSIZE => 100,
        :FSSPECNUM => 220,
        :FDQUADFLAG => 107,
        :FD2DPHASE => 257,
        :FDTRANSPOSED => 222,
        :FDDIMCOUNT => 10,
        :FDDIMORDER => 25:28,
        :FDFILECOUNT => 443
    )
    # dimension-specific parameters
    dimlabels = (17:18, 19:20, 21:22, 23:24) # UInt8
    dimpars = Dict(
        :FDAPOD => (96, 429, 51, 54, ),
        :FDSW => (101, 230, 12, 30, ),
        :FDOBS => (120, 219, 11, 29, ),
        :FDOBSMID => (379, 380, 381, 382, ),
        :FDORIG => (102, 250, 13, 31, ),
        :FDUNITS => (153, 235, 59, 60, ),
        :FDQUADFLAG => (57, 56, 52, 55, ),
        :FDFTFLAG => (221, 223, 14, 32, ),
        :FDCAR => (67, 68, 69, 70, ),
        :FDCENTER => (80, 81, 82, 83, ),
        :FDOFFPPM => (481, 482, 483, 484, ),
        :FDP0 => (110, 246, 61, 63, ),
        :FDP1 => (111, 247, 62, 64, ),
        :FDAPODCODE => (414, 415, 401, 406, ),
        :FDAPODQ1 => (416, 421, 402, 407, ),
        :FDAPODQ2 => (417, 422, 403, 408, ),
        :FDAPODQ3 => (418, 423, 404, 409, ),
        :FDLB => (112, 244, 373, 374, ),
        :FDGB => (375, 276, 377, 378, ),
        :FDGOFF => (383, 384, 385, 386, ),
        :FDC1 => (419, 424, 405, 410, ),
        :FDZF => (109, 438, 439, 440, ),
        :FDX1 => (258, 260, 262, 264, ),
        :FDXN => (259, 261, 263, 265, ),
        :FDFTSIZE => (97, 99, 201, 202, ),
        :FDTDSIZE => (387, 388, 389, 390, )
    )

    # check correct endian-ness
    @show header[genpars[:FDMAGIC]]
    @show header[genpars[:FDFLTORDER]]
    if header[genpars[:FDFLTORDER]] ≉ 2.345
        header = bswap.(header)
    end

    md = Dict{Symbol,Any}(k => header[genpars[k]] for k in keys(genpars))
    ndim = Int(md[:FDDIMCOUNT])

    axesmd = [Dict{Symbol,Any}(k => header[dimpars[k][i]] for k in keys(dimpars)) for i in 1:ndim]
    for i=1:ndim
        axesmd[i][:label] = reinterpret(UInt8, header[dimlabels[i]]) |> String
    end

    # add some metadata in nice format
    md[:ndim] = ndim

    return md, axesmd
end

"""
    metadatahelp(entry::Symbol)

Get a brief description of what's represented by metadata entry.

# Examples

```julia
metadatahelp(:FDQUADFLAG);
```
"""
function metadatahelp(entry::Symbol)
    refdict = Dict(
        :FDMAGIC => "Should be zero in valid NMRPipe data",
        :FDFLTFORMAT => "Constant defining floating point format",
        :FDFLTORDER => "Constant defining byte order",
        :FDSIZE => "Number of points in current dim R|I",
        :FSSPECNUM => "Number of complex 1D slices in file",
        :FDQUADFLAG => "0=quad/complex, 1=real, 2=pseudoquad, 3=se, 4=grad",
        :FD2DPHASE => "0=magnitude, 1=tppi, 2=states,3=image, 4=array",
        :FDTRANSPOSED => "1=Transposed, 0=Not Transposed",
        :FDDIMCOUNT => "Number of dimensions in complete data",
        :FDDIMORDER => "Dimension stored in X/Y/Z/A axes",
        :FDFILECOUNT => "Number of files in complete data",

        # axis parameters
        :FDAPOD => "Current valid time-domain size (complex points, before ZF)",
        :FDSW => "Sweep Width Hz",
        :FDOBS => "Obs Freq MHz",
        :FDOBSMID => "Original Obs Freq before 0.0ppm adjust",
        :FDORIG => "Axis Origin (Last Point), Hz",
        :FDUNITS => "Axis Units (1=sec, 2=Hz, 3=ppm, 4=pts)",
        #:FDQUADFLAG => defined above
        :FDFTFLAG => "1=Freq Domain 0=Time Domain",
        :FDCAR => "Carrier Position, PPM",
        :FDCENTER => "Point Location of Zero Freq",
        :FDOFFPPM => "Additional PPM offset (for alignment)",
        :FDP0 => "Zero Order Phase, Degrees",
        :FDP1 => "First  Order Phase, Degrees",
        :FDAPODCODE => "Window function used (0=none, 1=SP, 2=EM, 3=GM, 4=TM, 5=ZE, 6=TRI)",
        :FDAPODQ1 => "Window parameter 1",
        :FDAPODQ2 => "Window parameter 2",
        :FDAPODQ3 => "Window parameter 3",
        :FDLB => "Extra Exponential Broadening, Hz",
        :FDGB => "Extra Gaussian Broadening, Hz",
        :FDGOFF => "Offset for Gaussian Broadening, 0 to 1",
        :FDC1 => "Add 1.0 to get First Point Scale",
        :FDZF => "Negative of Zero Fill Size",
        :FDX1 => "Extract region origin, pts (if not zero)",
        :FDXN => "Extract region endpoint, pts (if not zero)",
        :FDFTSIZE => "Size of data when FT performed",
        :FDTDSIZE => "Original valid time-domain size"
    )
    entry in refdict || throw(NMRToolsException("symbol :$(entry) not found in reference dictionary"))
    return refdict[entry]
end
