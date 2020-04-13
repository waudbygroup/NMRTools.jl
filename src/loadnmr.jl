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

    md, mdax = parsenmrpipeheader(header)
end

function parsenmrpipeheader(header::Vector{Float32})
    # declare constants for clarity in accessing nmrPipe header

    # general parameters (independent of number of dimensions)
    genpars = Dict(
        :FDMAGIC => 1,
        :FDFLTFORMAT => 2,
        :FDFLTORDER => 3,
        :FDSIZE => (Int, 100),
        :FSSPECNUM => (Int, 220),
        :FDQUADFLAG => (Int, 107),
        :FD2DPHASE => (Int, 257),
        :FDTRANSPOSED => (Int, 222),
        :FDDIMCOUNT => (Int, 10),
        :FDDIMORDER => (Int, 25:28),
        :FDFILECOUNT => (Int, 443),
    )
    # dimension-specific parameters
    dimlabels = (17:18, 19:20, 21:22, 23:24) # UInt8
    dimpars = Dict(
        :FDAPOD => (Int, (96, 429, 51, 54, )),
        :FDSW => (101, 230, 12, 30, ),
        :FDOBS => (120, 219, 11, 29, ),
        :FDOBSMID => (379, 380, 381, 382, ),
        :FDORIG => (102, 250, 13, 31, ),
        :FDUNITS => (Int, (153, 235, 59, 60, )),
        :FDQUADFLAG => (Int, (57, 56, 52, 55, )),
        :FDFTFLAG => (Int, (221, 223, 14, 32, )),
        :FDCAR => (67, 68, 69, 70, ),
        :FDCENTER => (80, 81, 82, 83, ),
        :FDOFFPPM => (481, 482, 483, 484, ),
        :FDP0 => (110, 246, 61, 63, ),
        :FDP1 => (111, 247, 62, 64, ),
        :FDAPODCODE => (Int, (414, 415, 401, 406, )),
        :FDAPODQ1 => (416, 421, 402, 407, ),
        :FDAPODQ2 => (417, 422, 403, 408, ),
        :FDAPODQ3 => (418, 423, 404, 409, ),
        :FDLB => (112, 244, 373, 374, ),
        :FDGB => (375, 276, 377, 378, ),
        :FDGOFF => (383, 384, 385, 386, ),
        :FDC1 => (419, 424, 405, 410, ),
        :FDZF => (Int, (109, 438, 439, 440, )),
        :FDX1 => (Int, (258, 260, 262, 264, )),
        :FDXN => (Int, (259, 261, 263, 265, )),
        :FDFTSIZE => (Int, (97, 99, 201, 202, )),
        :FDTDSIZE => (Int, (387, 388, 389, 390, ))
    )

    # check correct endian-ness
    if header[genpars[:FDFLTORDER]] ≉ 2.345
        header = bswap.(header)
    end

    # populate spectrum metadata
    md = Dict{Symbol,Any}()
    for k in keys(genpars)
        x = genpars[k]
        # cast to new type if needed
        if x[1] isa Type
            md[k] = x[1].(header[x[2]])
        else
            md[k] = header[x]
        end
    end

    # add some metadata in nice format
    ndim = md[:FDDIMCOUNT]
    md[:ndim] = ndim

    # populate metadata for each dimension
    axesmd = []
    for i=1:ndim
        d = Dict{Symbol,Any}()
        for k in keys(dimpars)
            x = dimpars[k]
            # cast to new type if needed
            if x[1] isa Type
                d[k] = x[1].(header[x[2][i]])
            else
                d[k] = header[x[i]]
            end
        end
        # add label, removing null characters
        tmp = reinterpret(UInt8, header[dimlabels[i]])
        d[:label] = String(tmp[tmp .≠ 0])

        # add some data in a nice format
        if d[:FDFTFLAG] == 0
            d[:pseudodim] = true
            d[:npoints] = d[:FDTDSIZE]
            d[:val] = 1:d[:npoints] # coordinates for this dimension are just 1 to N
        else # frequency domain
            d[:pseudodim] = false
            d[:td] = d[:FDTDSIZE]
            d[:tdzf] = d[:FDFTSIZE]
            d[:bf] = d[:FDOBS]
            d[:swhz] = d[:FDSW]
            d[:swppm] = d[:swhz] / d[:bf]
            d[:offsetppm] = d[:FDCAR]
            d[:offsethz] = (d[:offsetppm]*1e-6 + 1) * d[:bf]
            d[:sf] = d[:offsethz]*1e-6 + d[:bf]
            if d[:FDX1] == 0 && d[:FDXN] == 0
                d[:region] = missing
                d[:npoints] = d[:tdzf]
            else
                d[:region] = d[:FDX1] : d[:FDXN]
                d[:npoints] = length(d[:region])
            end

            edge_frq = d[:FDORIG]
            # calculate chemical shift values
            cs_at_edge = edge_frq / d[:bf]
            cs_at_other_edge = cs_at_edge + d[:swppm]
            x = range(cs_at_other_edge, cs_at_edge, length=d[:npoints]+1);
            d[:val] = x[2:end];
            # alternative calculation (without extraction)
            x = range(d[:offsetppm] + 0.5*d[:swppm], d[:offsetppm] - 0.5*d[:swppm], length=d[:npoints]+1)
            d[:val2] = x[1:end-1]

            # create a representation of the window function
            #:FDAPODCODE => "Window function used (0=none, 1=SP, 2=EM, 3=GM, 4=TM, 5=ZE, 6=TRI)",
            w = d[:FDAPODCODE]
            q1 = d[:FDAPODQ1]
            q2 = d[:FDAPODQ2]
            q3 = d[:FDAPODQ3]
            if w == 0
                window = NullWindow()
            elseif w == 1
                window = SineWindow(q1, q2, q3)
            elseif w == 2
                window = ExponentialWindow(q1)
            elseif w == 3
                window = GaussWindow(q1, q2, q3)
            else
                window = UnknownWindow()
            end
            d[:window] = window
        end

        push!(axesmd, d)
    end

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
        :FDAPOD => "Current valid time-domain size (complex points, before ZF, after extraction)",
        :FDSW => "Sweep Width Hz (after extraction)",
        :FDOBS => "Obs Freq MHz",
        :FDOBSMID => "Original Obs Freq before 0.0ppm adjust",
        :FDORIG => "Axis Origin (Last Point, After Extraction), Hz",
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
    entry in keys(refdict) || throw(NMRToolsException("symbol :$(entry) not found in reference dictionary"))
    return refdict[entry]
end
