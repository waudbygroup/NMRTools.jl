# UCSF format:
# - https://www.cgl.ucsf.edu/home/sparky/manual/files.html
# - https://github.com/jjhelmus/nmrglue/blob/master/nmrglue/fileio/sparky.py

function loaducsf(filename)
    # parse the header
    md, mdax = loaducsfheader(filename)

    ndim = md[:ndim]
    if ndim == 2
        loaducsf2d(filename, md, mdax)
    elseif ndim == 3
        loaducsf3d(filename, md, mdax)
    else
        throw(NMRToolsError("can't load data $(filename), unsupported number of dimensions ($ndim)."))
    end
end

function loaducsfheader(filename)
    # check file exists
    isfile(filename) ||
        throw(NMRToolsError("cannot load $(filename), not a recognised file."))

    md = parseucsfheader(filename)
    ndim = md[:ndim]

    # load the dimension headers
    # 128 bytes per axis, after the initial 180
    axisheaders = zeros(UInt8, 128 * ndim)
    open(filename) do f
        read(f, 180)
        return read!(f, axisheaders)
    end
    # axisheaders = ntoh.(axisheaders)
    axisheaders = reshape(axisheaders, :, ndim)

    # parse the header, returning md and mdax
    mdax = [parseucsfaxisheader(axisheaders[:, i]) for i in 1:ndim]

    return md, mdax
end

"parse ucsf file header into a dictionary"
function parseucsfheader(filename)
    # preallocate header
    header = zeros(UInt8, 180)

    # read the file
    open(filename) do f
        return read!(f, header)
    end
    header = ntoh.(header) # convert from big-endian to native

    ucsfstring = String(header[1:10])
    ucsfstring[1:8] == "UCSF NMR" ||
        throw(NMRToolsError("can't load data $(filename), invalid header (ucsfstring)."))

    version = Int(header[14])
    version == 2 ||
        throw(NMRToolsError("can't load data $(filename), unsupported file version (version=$version)."))

    ncomp = Int(header[12])
    ncomp == 1 ||
        throw(NMRToolsError("can't load data $(filename), unsupported number of components (ncomp=$ncomp)."))

    md = Dict{Symbol,Any}()

    md[:ndim] = Int(header[11])

    return md
end

"parse ucsf axis header into a dictionary"
function parseucsfaxisheader(header)
    # (NB 1-based positions)
    # position	bytes	contents
    # 1	        6	    nucleus name (1H, 13C, 15N, 31P, ...) null terminated ASCII
    # 7         2       UInt16 spectral shift
    # 9	        4	    integer, number of data points along this axis
    # 13        4	    integer, axis size (?)
    # 17	    4	    integer, tile size along this axis
    # 21	    4	    float spectrometer frequency for this nucleus (MHz)
    # 25	    4	    float spectral width (Hz)
    # 29	    4	    float center of data (ppm)
    # 33	    4	    float, zero order (phase?)
    # 37	    4	    float, first order (phase?)
    # 41	    4	    float, first point scaling

    # nucleus name
    nucleus = ntoh.(header[1:6])
    nucleus = String(nucleus[nucleus .≠ 0])

    spectralshift = Int(ntoh(reinterpret(UInt16, header[7:8])[1]))
    npoints = Int(ntoh(reinterpret(Int32, header[9:12])[1]))
    axissize = Int(ntoh(reinterpret(Int32, header[13:16])[1]))
    tilesize = Int(ntoh(reinterpret(Int32, header[17:20])[1]))
    bf = Float64(ntoh(reinterpret(Float32, header[21:24])[1]))
    swhz = Float64(ntoh(reinterpret(Float32, header[25:28])[1]))
    offsetppm = Float64(ntoh(reinterpret(Float32, header[29:32])[1]))
    zeroorder = Float64(ntoh(reinterpret(Float32, header[33:36])[1]))
    firstorder = Float64(ntoh(reinterpret(Float32, header[37:40])[1]))
    firstpointscaling = Float64(ntoh(reinterpret(Float32, header[41:44])[1]))

    md = Dict{Symbol,Any}()
    md[:label] = nucleus
    md[:spectralshift] = spectralshift
    md[:npoints] = npoints
    md[:ucsfaxissize] = axissize
    md[:ucsftilesize] = tilesize
    md[:bf] = bf
    md[:swhz] = swhz
    md[:offsetppm] = offsetppm
    md[:zeroorder] = zeroorder
    md[:firstorder] = firstorder
    md[:firstpointscaling] = firstpointscaling

    swppm = swhz / bf
    md[:offsethz] = offsetppm * bf
    md[:sf] = (1 + offsetppm / 1e6) * bf
    md[:swppm] = swppm
    md[:window] = UnknownWindow()
    md[:pseudodim] = false

    x = LinRange(offsetppm + 0.5swppm, offsetppm - 0.5swppm, npoints + 1)
    md[:val] = x[1:(end - 1)]

    return md
end

function loaducsf2d(filename, md, mdax)
    nx = mdax[2][:npoints]
    ny = mdax[1][:npoints]
    tx = mdax[2][:ucsftilesize]
    ty = mdax[1][:ucsftilesize]

    # preallocate data
    dat = zeros(Float32, nx, ny)

    # read the file
    open(filename) do f
        read(f, 180) # header
        read(f, 128) # axis header 1
        read(f, 128) # axis header 2
        return read!(f, dat)
    end
    dat = Float64.(ntoh.(dat))

    # untile the data
    dat = untileucsf2d(dat, tx, ty, nx, ny)

    # set up dimensions
    valx = mdax[2][:val]
    delete!(mdax[2], :val) # remove values from metadata to prevent confusion when slicing up
    valy = mdax[1][:val]
    delete!(mdax[1], :val) # remove values from metadata to prevent confusion when slicing up
    xaxis = F1Dim(valx; metadata=mdax[2])
    yaxis = F2Dim(valy; metadata=mdax[1])

    return NMRData(dat, (xaxis, yaxis); metadata=md)
end

function loaducsf3d(filename, md, mdax)
    nx = mdax[3][:npoints]
    ny = mdax[2][:npoints]
    nz = mdax[1][:npoints]
    tx = mdax[3][:ucsftilesize]
    ty = mdax[2][:ucsftilesize]
    tz = mdax[1][:ucsftilesize]

    # preallocate data
    dat = zeros(Float32, nx, ny, nz)

    # read the file
    open(filename) do f
        read(f, 180) # header
        read(f, 128) # axis header 1
        read(f, 128) # axis header 2
        read(f, 128) # axis header 3
        return read!(f, dat)
    end
    dat = Float64.(ntoh.(dat))

    # untile the data
    dat = untileucsf3d(dat, tx, ty, tz, nx, ny, nz)

    # set up dimensions
    valx = mdax[3][:val]
    delete!(mdax[3], :val) # remove values from metadata to prevent confusion when slicing up
    valy = mdax[2][:val]
    delete!(mdax[2], :val) # remove values from metadata to prevent confusion when slicing up
    valz = mdax[1][:val]
    delete!(mdax[1], :val) # remove values from metadata to prevent confusion when slicing up

    xaxis = F1Dim(valx; metadata=mdax[3])
    yaxis = F2Dim(valy; metadata=mdax[2])
    zaxis = F3Dim(valz; metadata=mdax[1])

    return NMRData(dat, (xaxis, yaxis, zaxis); metadata=md)
end

function untileucsf2d(dat, tx, ty, nx, ny)
    # determine the number of tiles in data 
    ntx = ceil(Int, nx / tx) # number of tiles in x dim
    nty = ceil(Int, ny / ty) # number of tiles in y dim

    tsize = tx * ty # number of points in one tile

    # create an empty array to store file data
    out = zeros(eltype(dat), ntx * tx, nty * ty)

    for iy in 1:nty
        for ix in 1:ntx
            minx = (ix - 1) * tx + 1
            maxx = ix * tx
            miny = (iy - 1) * ty + 1
            maxy = iy * ty
            ntile = (iy - 1) * ntx + ix
            mint = (ntile - 1) * tsize + 1
            maxt = ntile * tsize

            # fill in the tile data
            out[minx:maxx, miny:maxy] .= reshape(dat[mint:maxt], tx, ty)
        end
    end

    return out[1:nx, 1:ny]
end

function untileucsf3d(dat, tx, ty, tz, nx, ny, nz)
    # determine the number of tiles in data 
    ntx = ceil(Int, nx / tx) # number of tiles in x dim
    nty = ceil(Int, ny / ty) # number of tiles in y dim
    ntz = ceil(Int, nz / tz) # number of tiles in z dim

    tsize = tx * ty * tz # number of points in one tile

    # create an empty array to store file data
    out = zeros(eltype(dat), ntx * tx, nty * ty, ntz * tz)

    for iz in 1:ntz
        for iy in 1:nty
            for ix in 1:ntx
                minx = (ix - 1) * tx + 1
                maxx = ix * tx
                miny = (iy - 1) * ty + 1
                maxy = iy * ty
                minz = (iz - 1) * tz + 1
                maxz = iz * tz
                ntile = (iz - 1) * ntx * nty + (iy - 1) * ntx + ix
                mint = (ntile - 1) * tsize + 1
                maxt = ntile * tsize

                # fill in the tile data
                out[minx:maxx, miny:maxy, minz:maxz] .= reshape(dat[mint:maxt], tx, ty, tz)
            end
        end
    end

    return out[1:nx, 1:ny, 1:nz]
end