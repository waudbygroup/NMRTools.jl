function loadnmrpipe(filename)
    if occursin(r"%0[34]d", filename)
        # something like test%03d.ft2
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



expandpipetemplate(template, n) = replace(template, "%03d"=>lpad(n,3,"0"), "%04d"=>lpad(n,4,"0"))



function loadnmrpipeheader(filename)
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
The nmrPipe header format is defined in `fdatap.h`.

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
        :FDPIPEFLAG => (Int, 58),  #Dimension code of data stream
        :FDCUBEFLAG => (Int, 448),
        :FDSIZE => (Int, 100),
        :FDSPECNUM => (Int, 220),
        :FDQUADFLAG => (Int, 107),
        :FD2DPHASE => (Int, 257),
        :FDTRANSPOSED => (Int, 222),
        :FDDIMCOUNT => (Int, 10),
        :FDDIMORDER => (Int, 25:28),
        :FDFILECOUNT => (Int, 443),
        :FDSIZE => (Int, (100, 220, 16, 33)),
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
    md = Dict{Symbol,Any}()  # main dictionary for metadata
    pipemd = Dict{Symbol,Any}()  # dictionary to hold all the complete pipe header information
    for k in keys(genpars)
        x = genpars[k]
        # cast to new type if needed
        if x[1] isa Type
            if length(x[2]) == 1
                pipemd[k] = x[1].(header[x[2]])
            else
                # array parameter
                pipemd[k] = [x[1].(header[i]) for i in x[2]]
            end
        else
            pipemd[k] = Float64(header[x])
        end
    end

    # add some metadata in nice format
    ndim = pipemd[:FDDIMCOUNT]
    md[:ndim] = ndim

    # store full NMRPipe header in main dictionary
    md[:pipe] = pipemd

    # populate metadata for each dimension
    axesmd = []
    for i=1:ndim
        dic = Dict{Symbol,Any}()
        pipedic = Dict{Symbol,Any}()
        for k in keys(dimpars)
            x = dimpars[k]
            # cast to new type if needed
            if x[1] isa Type
                pipedic[k] = x[1].(header[x[2][i]])
            else
                pipedic[k] = Float64(header[x[i]])
            end
        end
        # add label, removing null characters
        tmp = reinterpret(UInt8, header[dimlabels[i]])
        dic[:label] = String(tmp[tmp .≠ 0])

        # add some data in a nice format
        if pipedic[:FDFTFLAG] == 0
            dic[:pseudodim] = true
            dic[:npoints] = pipedic[:FDTDSIZE]
            dic[:val] = 1:dic[:npoints] # coordinates for this dimension are just 1 to N
        else # frequency domain
            dic[:pseudodim] = false
            dic[:td] = pipedic[:FDTDSIZE]
            dic[:tdzf] = pipedic[:FDFTSIZE]
            dic[:bf] = pipedic[:FDOBS]
            dic[:swhz] = pipedic[:FDSW]
            dic[:swppm] = dic[:swhz] / dic[:bf]
            dic[:offsetppm] = pipedic[:FDCAR]
            dic[:offsethz] = (dic[:offsetppm]*1e-6 + 1) * dic[:bf]
            dic[:sf] = dic[:offsethz]*1e-6 + dic[:bf]
            if pipedic[:FDX1] == 0 && pipedic[:FDXN] == 0
                dic[:region] = missing
                dic[:npoints] = dic[:tdzf]
            else
                dic[:region] = pipedic[:FDX1] : pipedic[:FDXN]
                dic[:npoints] = length(dic[:region])
            end

            edge_frq = pipedic[:FDORIG]
            # calculate chemical shift values
            cs_at_edge = edge_frq / dic[:bf]
            cs_at_other_edge = cs_at_edge + dic[:swppm]
            x = range(cs_at_other_edge, cs_at_edge, length=dic[:npoints]+1);
            dic[:val] = x[2:end];
            # # alternative calculation (without extraction) - this agrees OK
            # x = range(dic[:offsetppm] + 0.5*dic[:swppm], dic[:offsetppm] - 0.5*dic[:swppm], length=dic[:npoints]+1)
            # dic[:val2] = x[1:end-1]

            # create a representation of the window function
            # calculate acquisition time = td / sw
            taq = dic[:td] / dic[:swhz]
            #:FDAPODCODE => "Window function used (0=none, 1=SP, 2=EM, 3=GM, 4=TM, 5=ZE, 6=TRI)",
            w = pipedic[:FDAPODCODE]
            q1 = pipedic[:FDAPODQ1]
            q2 = pipedic[:FDAPODQ2]
            q3 = pipedic[:FDAPODQ3]
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
            dic[:window] = window
        end

        dic[:pipe] = pipedic # store pipe header info in main axis dictionary
        push!(axesmd, dic)
    end

    return md, axesmd
end



"""
    loadnmrpipe1d(filename, md, mdax)

Return an NMRData array containing spectrum and associated metadata.
"""
function loadnmrpipe1d(filename, md, mdax)
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
    xaxis = FrequencyDim(valx, metadata=mdax[1])

    return NMRData(y, (xaxis, ), metadata=md)
end




"""
    loadnmrpipe2d(filename, md, mdax)

Return NMRData containing spectrum and associated metadata.
"""
function loadnmrpipe2d(filename::String, md, mdax)
    npoints1 = mdax[1][:npoints]
    npoints2 = mdax[2][:npoints]
    transposeflag = md[:pipe][:FDTRANSPOSED] > 0

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
    ax2 = mdax[2][:pseudodim] ? UnknownDim : FrequencyDim
    xaxis = FrequencyDim(valx, metadata=mdax[1])
    yaxis = ax2(valy, metadata=mdax[2])

    NMRData(y, (xaxis, yaxis), metadata=md)
end



"""
    loadnmrpipe3d(filename, md, mdax)

Return NMRData containing spectrum and associated metadata.
"""
function loadnmrpipe3d(filename::String, md, mdax)
    datasize = md[:pipe][:FDSIZE][1:3]

    # load data
    header = zeros(Float32, 512)
    y = zeros(Float32, datasize...)
    if md[:pipe][:FDPIPEFLAG] == 0
        # series of 2D files
        y2d = zeros(Float32, datasize[1], datasize[2])
        for i = 1:datasize[3]
            filename1 = expandpipetemplate(filename, i)
            open(filename1) do f
                read!(f, header)
                read!(f, y2d)
            end
            y[:,:,i] = y2d
        end
    else
        # single stream
        open(filename) do f
            read!(f, header)
            read!(f, y)
        end
    end
    y = Float64.(y)

    # get axis values
    val1 = mdax[1][:val]
    val2 = mdax[2][:val]
    val3 = mdax[3][:val]
    delete!(mdax[1],:val) # remove values from metadata to prevent confusion when slicing up
    delete!(mdax[2],:val)
    delete!(mdax[3],:val)

    # y is currently in order of FDSIZE - we need to rearrange
    dimorder = md[:pipe][:FDDIMORDER][1:3]
    tr = md[:pipe][:FDTRANSPOSED]

    # figure out current ordering of data matrix
    # e.g. order = [2 1 3] indicates the data matrix is axis2 x axis1 x axis3
    if tr == 0
        order = [findfirst(x->x.==i, dimorder) for i=[2,1,3]]
    else # transpose flag
        # swap first two entries of dimorder round
        dimorder2 = [dimorder[2], dimorder[1], dimorder[3]]
        order = [findfirst(x->x.==i, dimorder2) for i=[1,2,3]]
    end
    # calculate the permutation required to bring the data matrix into the order axis1 x axis2 x axis3
    unorder = [findfirst(x->x.==i, order) for i=[1,2,3]]
    y = permutedims(y, unorder)

    # finally rearrange data into a useful order - always place pseudo-dimension last - and generate axes
    # 1 is always direct, and should be placed first (i.e. 1 x x)
    # is there is a pseudodimension, put that last (i.e. 1 y p)
    # otherwise, return data in the order 1 2 3 = order of fid.com, inner -> outer loop
    pdim = [mdax[i][:pseudodim] for i in 1:3]
    if pdim[2]
        # dimensions are x p y => we want ordering 1 3 2
        xaxis = FrequencyDim(val1, metadata=mdax[1])
        yaxis = FrequencyDim(val3, metadata=mdax[3])
        zaxis = UnknownDim(val2, metadata=mdax[2])
        y = permutedims(y, [1, 3, 2])
    elseif pdim[3]
        # dimensions are x y p => we want ordering 1 2 3
        xaxis = FrequencyDim(val1, metadata=mdax[1])
        yaxis = FrequencyDim(val2, metadata=mdax[2])
        zaxis = UnknownDim(val3, metadata=mdax[3])
    else
        # no pseudodimension, use Z axis not Ti
        # dimensions are x y z => we want ordering 1 2 3
        xaxis = FrequencyDim(val1, metadata=mdax[1])
        yaxis = FrequencyDim(val2, metadata=mdax[2])
        zaxis = FrequencyDim(val3, metadata=mdax[3])
    end

    NMRData(y, (xaxis, yaxis, zaxis), metadata=md)
end