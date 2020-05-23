"""
    loadnmr(template::String)

Main function for loading nmrPipe or bruker format NMR data.

Returns an NMRData array, or throws an NMRToolsException is there is a problem.

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
function loadnmr(filename::String, acqusfilename::Union{String,Nothing}=nothing)
    # load the data
    ispipe = occursin(r"[a-z0-9]+(\%03d)?\.ft[123]?$", filename)
    if ispipe
        # match files ending in .ft, .ft1, .ft2 or .ft3 => NMRPipe
        spectrum = loadnmrpipe(filename)
        metadata(spectrum)[:format] = :NMRPipe
    else
        # TODO bruker import
        throw(NMRToolsException("unknown file format for loadnmr\ntemplate = " * template))
    end

    # locate the acqus file
    if isnothing(acqusfilename)
        base = basename(filename)
        dir = dirname(filename)
        if ispipe
            # assume that acqus is in same directory as test.ft2 files, and one up from ft/test%03d.ft2 files
            if occursin("%", filename)
                dir = dirname(dir) # this moves up one directory
            end
            acqusfilename = joinpath(dir, "acqus")
        end
    end

    # parse the acqus file
    acqusmetadata = parseacqus(acqusfilename)
    metadata(spectrum)[:acqus] = acqusmetadata
    metadata(spectrum)[:ns] = acqusmetadata["NS"]
    metadata(spectrum)[:rg] = acqusmetadata["RG"]
    metadata(spectrum)[:pulseprogram] = acqusmetadata["PULPROG"]
    metadata(spectrum)[:filename] = filename
    metadata(spectrum)[:acqusfilename] = acqusfilename
    metadata(spectrum)[:NMRTools] = true

    # load the title file
    titlefilename = joinpath(dirname(acqusfilename), "pdata", "1", "title")
    title = read(titlefilename, String)
    metadata(spectrum)[:title] = strip(title)
    titleline1 = split(title, "\n")[1]
    label!(spectrum, titleline1)

    # populate the spectrum noise level
    estimatenoise!(spectrum)

    return spectrum
end



expandpipetemplate(template, n) = replace(template, "%03d"=>lpad(n,3,"0"))



function loadnmrpipe(filename::String)
    if occursin("%", filename)
        # something like test%03d.ft2 - pseudo3D
        filename1 = expandpipetemplate(filename, 1)
    else
        filename1 = filename
    end
    # parse the header
    md, mdax = loadnmrpipeheader(filename1)

    ndim = md[:ndim]
    if ndim == 1
        loadnmrpipe1d(filename, md, mdax)
    elseif ndim == 2
        loadnmrpipe2d(filename, md, mdax)
    elseif ndim == 3
        loadnmrpipe3d(filename, md, mdax)
    else
        throw(NMRToolsException("can't load data $(filename), unsupported number of dimensions."))
    end
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

    # parse the header, returning md and mdax
    parsenmrpipeheader(header)
end



"""
    parsenmrpipeheader(header)

Pass a 512 x 4 byte array containing an nmrPipe header file, and returns dictionaries of metadata.

# Return values
- `md`: dictionary of spectrum metadata
- `mdax`: array of dictionaries containing axis metadata

# Examples
```julia
md, mdax = parsenmrpipeheader(header)
```
"""
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
            md[k] = Float64(header[x])
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
                d[k] = Float64(header[x[i]])
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
            # # alternative calculation (without extraction) - this agrees OK
            # x = range(d[:offsetppm] + 0.5*d[:swppm], d[:offsetppm] - 0.5*d[:swppm], length=d[:npoints]+1)
            # d[:val2] = x[1:end-1]

            # create a representation of the window function
            # calculate acquisition time = td / sw
            taq = d[:td] / d[:swhz]
            #:FDAPODCODE => "Window function used (0=none, 1=SP, 2=EM, 3=GM, 4=TM, 5=ZE, 6=TRI)",
            w = d[:FDAPODCODE]
            q1 = d[:FDAPODQ1]
            q2 = d[:FDAPODQ2]
            q3 = d[:FDAPODQ3]
            if w == 0
                window = NullWindow(taq)
            elseif w == 1
                window = SineWindow(q1, q2, q3, taq)
            elseif w == 2
                window = ExponentialWindow(q1, taq)
            elseif w == 3
                window = GaussWindow(q1, q2, q3, taq)
            else
                window = UnknownWindow(taq)
            end
            d[:window] = window
        end

        push!(axesmd, d)
    end

    return md, axesmd
end



"""
    loadnmrpipe1d(filename, md, mdax)

Return an NMRData array containing spectrum and associated metadata.
"""
function loadnmrpipe1d(filename::String, md, mdax)
    npoints = mdax[1][:npoints]
    # preallocate data (and dummy header)
    header = zeros(Float32, 512)
    y = zeros(Float32, npoints)

    # read the file
    open(filename) do f
        read!(f, header)
        read!(f, y)
    end
    y = Float64.(y)

    valx = mdax[1][:val]
    delete!(mdax[1],:val) # remove values from metadata to prevent confusion when slicing up
    xaxis = X(valx, metadata=mdax[1])

    NMRData(y, (xaxis, ), metadata=md)
end



"""
    loadnmrpipe2d(filename, md, mdax)

Return NMRData containing spectrum and associated metadata.
"""
function loadnmrpipe2d(filename::String, md, mdax)
    npoints1 = mdax[1][:npoints]
    npoints2 = mdax[2][:npoints]
    transposeflag = md[:FDTRANSPOSED] > 0
    dimorder = md[:FDDIMORDER]

    # preallocate data (and dummy header)
    header = zeros(Float32, 512)
    if transposeflag
        y = zeros(Float32, npoints2, npoints1)
    else
        y = zeros(Float32, npoints1, npoints2)
    end

    # read the file
    open(filename) do f
        read!(f, header)
        read!(f, y)
    end
    if transposeflag
        y = transpose(y)
    end
    y = Float64.(y)

    valx = mdax[1][:val]
    delete!(mdax[1],:val) # remove values from metadata to prevent confusion when slicing up
    valy = mdax[2][:val]
    delete!(mdax[2],:val) # remove values from metadata to prevent confusion when slicing up
    ax2 = mdax[2][:pseudodim] ? Ti : Y
    xaxis = X(valx, metadata=mdax[1])
    yaxis = ax2(valy, metadata=mdax[2])

    NMRData(y, (xaxis, yaxis), metadata=md)
end



"""
    loadnmrpipe3d(filename, md, mdax)

Return NMRData containing spectrum and associated metadata.
"""
function loadnmrpipe3d(filename::String, md, mdax)
    npoints = [mdax[i][:npoints] for i in 1:3]
    pdim = [mdax[i][:pseudodim] for i in 1:3]
    dimorder = md[:FDDIMORDER][1:3]
    if md[:FDTRANSPOSED] == 0
        permute!(dimorder,[1,3,2])
    end

    # load data
    header = zeros(Float32, 512)
    y = zeros(Float32, npoints[dimorder]...)
    y2d = zeros(Float32, npoints[dimorder][2:3]...)
    for i = 1:npoints[dimorder[1]]
        filename1 = expandpipetemplate(filename, i)
        open(filename1) do f
            read!(f, header)
            read!(f, y2d)
        end
        y[i,:,:] = y2d
    end
    y = Float64.(y)

    # y is currently in order DIMORDER - we want to rearrange:
    # 1 is always direct, and should be placed first (i.e. 1 x x)
    # is there is a pseudodimension, put that last (i.e. 1 y p)
    # otherwise, return data in the order 1 2 3 = order of fid.com, inner -> outer loop
    val1 = mdax[1][:val]
    val2 = mdax[2][:val]
    val3 = mdax[3][:val]
    delete!(mdax[1],:val) # remove values from metadata to prevent confusion when slicing up
    delete!(mdax[2],:val)
    delete!(mdax[3],:val)
    if pdim[2]
        # dimensions are x p y => we want ordering 1 3 2
        xaxis = X(val1, metadata=mdax[1])
        yaxis = Y(val3, metadata=mdax[3])
        zaxis = Ti(val2, metadata=mdax[2])
        unorder = [findfirst(x->x.==i,dimorder) for i=[1,3,2]]
    elseif pdim[3]
        # dimensions are x y p => we want ordering 1 2 3
        xaxis = X(val1, metadata=mdax[1])
        yaxis = Y(val2, metadata=mdax[2])
        zaxis = Ti(val3, metadata=mdax[3])
        unorder = [findfirst(x->x.==i,dimorder) for i=[1,2,3]]
    else
        # no pseudodimension, use Z axis not Ti
        # dimensions are x y z => we want ordering 1 2 3
        xaxis = X(val1, metadata=mdax[1])
        yaxis = Y(val2, metadata=mdax[2])
        zaxis = Z(val3, metadata=mdax[3])
        unorder = [findfirst(x->x.==i,dimorder) for i=[1,2,3]]
    end
    y = permutedims(y, unorder)

    NMRData(y, (xaxis, yaxis, zaxis), metadata=md)
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
        # spectrum parameters
        :ndim => "Number of dimensions",
        :format => "Original file format, :NMRPipe or :bruker",
        :acqus => "Dictionary containing parsed acqus file",
        :ns => "Number of scans (NS) from acqus file",
        :rg => "Receiver gain (RG) from acqus file",
        :pulseprogram => "Pulse program (PULPROG) from acqus file",
        :filename => "Original filename or template",
        :acqusfilename => "Path to imported acqus file",
        :noise => "rms noise level",

        # dimension parameters
        :pseudodim => "Flag indicating non-frequency domain data",
        :npoints => "Number of (real) data points in dimension",
        :td => "Number of complex points acquired",
        :tdzf => "Number of complex points when FT executed, including linear prediction and zero filling",
        :bf => "Base frequency, in MHz",
        :swhz => "Spectrum width, in Hz",
        :swppm => "Spectrum width, in ppm",
        :offsetppm => "Carrier offset from bf, in ppm",
        :offsethz => "Carrier offset from bf, in Hz",
        :sf => "Carrier frequency, in MHz",
        :region => "Extracted region, expressed as a range in points, otherwise missing",
        :window => "WindowFunction structure indicating applied apodization",

        # NMRPipe spectrum parameters
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



function parseacqus(acqusfilename::String)
    ispath(acqusfilename) || throw(NMRToolsException("loading acqus data: $(acqusfilename) is not a valid file"))

    dat = open(acqusfilename) do f
        read(f, String)
    end

    fields = [strip(strip(x),'$') for x in split(dat, "##")]
    dic = Dict{String,Any}()
    for field in fields
        field == "" && continue # skip empty lines
        x = split(field, "= ")
        if length(x) > 1
            # store keys as uppercase - there's only a couple of annoying exceptions like NusAMOUNT
            # and forcing uppercase makes it easier to access, e.g. as :vclist not :VCLIST
            dic[uppercase(x[1])] = parseacqusentry(x[2])
        end
    end

    # lastly, check for referenced files like vclist, fq1list, and load these in place of filename
    parseacqusauxfiles!(dic, dirname(acqusfilename))

    return dic
end



function parseacqusentry(dat)
    if dat[1] == '('
        # array data - split into fields
        fields = split(split(dat, ")\n")[2])
        parsed = map(x -> parseacqusfield(x), fields)
        if parsed isa Vector{Real}
            parsed = float.(parsed)
        end
        # convert to a zero-based array to match expected bruker notation
        parsed = OffsetArray(parsed, 0:length(parsed)-1)
    else
        parsed = parseacqusfield(dat)
    end
    return parsed
end



function parseacqusfield(dat)
    if dat[1] == '<' # <string>
        dat = dat[2:end-1]
    else
        x = tryparse(Int64, dat)
        if isnothing(x)
            dat = tryparse(Float64, dat)
        else
            dat = x
        end
    end
    return dat
end



function parseacqusauxfiles!(dic, basedir)
    for k in ("VCLIST",) # integer lists
        dic[k] == "" && continue
        # note that filenames aren't actually used - vclist is always stored as vclist
        filename = joinpath(basedir, lowercase(k))
        ispath(filename) || continue
        x = readlines(filename)
        xi = tryparse.(Int,x)
        if any(xi.==nothing)
            @warn "Unable to parse format of list $(k) when opening $(filename)"
            dic[k] = x
        else
            dic[k] = xi
        end
    end

    for k in ("FQ1LIST", "FQ2LIST", "FQ3LIST", "FQ4LIST", "FQ5LIST", "FQ6LIST", "FQ7LIST", "FQ8LIST",
                "VALIST", "VDLIST", "VPLIST", "VTLIST") # float lists
        dic[k] == "" && continue
        # note that filenames aren't actually used - vclist is always stored as vclist
        filename = joinpath(basedir, lowercase(k))
        ispath(filename) || continue
        x = readlines(filename)
        xp = [replace(replace(xs, "u"=>"e-6"),"m"=>"e-3") for xs in x]
        xf = tryparse.(Float64,xp)
        if any(xf.==nothing)
            @warn "Unable to parse format of list $(k) when opening $(filename)"
            dic[k] = x
        else
            dic[k] = xf
        end
    end
end
