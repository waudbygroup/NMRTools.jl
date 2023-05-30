"""
    loadpdata(filename, allcomponents=false)

Filename will be a reference to a pdata folder.
"""
function loadpdata(filename, allcomponents=false)
    # 1. get reference to pdata/X directory
    if isdir(filename)
        pdir = filename
    else
        pdir = dirname(filename)
    end
    isdir(pdir) || throw(NMRToolsException("can't load bruker data, pdata directory $pdir does not exist"))

    # 2. get a list of pdata input files (which depends on the dimension of the spectrum)
    ndim = 0
    datafiles = []
    if isfile(joinpath(pdir, "1r"))
        ndim = 1
        datafiles = ["1r", "1i"]
    elseif isfile(joinpath(pdir, "2rr"))
        ndim = 2
        datafiles = ["2rr", "2ri", "2ir", "2ii"]
    elseif isfile(joinpath(pdir, "3rrr"))
        ndim = 3
        datafiles = ["3rrr", "3rri", "3rir", "3rii", "3irr", "3iri", "3iir", "3iii"]
    end
    ndim > 0 || throw(NMRToolsException("can't load bruker data, pdata directory $pdir does not contain binary data files (1r/2rr/3rrr etc.)"))

    # 2b. only include the realest component unless requested
    if !allcomponents
        datafiles = [first(datafiles)]
    end

    # 2c. check these files actually exist
    datafiles = map(x->joinpath(pdir, x), datafiles)
    filter!(isfile, datafiles)

    # 3. read procs files (containing axis metadata)
    procsfiles = ["procs", "proc2s", "proc3s", "proc4s"]
    procsdics = [loadjdx(joinpath(pdir, procsfiles[i])) for i=1:ndim]

    # 4. TODO parse procs into main axis metadata
    md = Dict{Symbol,Any}()  # main dictionary for metadata
    md[:ndim] = ndim
    # populate metadata for each dimension
    axesmd = []
    for i=1:ndim
        dic = Dict{Symbol,Any}()
        procdic = procsdics[i]
        
        # add some data in a nice format
        if procdic[:ft_mod] == 0
            dic[:pseudodim] = true
            dic[:label] = ""
            dic[:npoints] = procdic[:si]
            dic[:val] = 1:dic[:npoints] # coordinates for this dimension are just 1 to N
        else # frequency domain
            dic[:pseudodim] = false
            dic[:label] = procdic[:axnuc]
            dic[:bf] = procdic[:sf]
            dic[:swhz] = procdic[:sw_p]
            dic[:swppm] = dic[:swhz] / dic[:bf]
            dic[:offsethz] = procdic[:offset]*dic[:bf] - dic[:swhz]/2
            dic[:offsetppm] = dic[:offsethz] / dic[:bf]
            dic[:sf] = dic[:offsethz]*1e-6 + dic[:bf]

            if procdic[:lpbin] == 0
                dic[:td] = procdic[:tdeff]
            else
                dic[:td] = procdic[:lpbin]
            end
            dic[:tdzf] = procdic[:si]

            # get any extracted regions and number of points
            if procdic[:stsr] == 0
                dic[:region] = missing
                dic[:npoints] = dic[:tdzf]
            else
                dic[:region] = procdic[:stsr] : (procdic[:stsr] + procdic[:stsi] - 1)
                dic[:npoints] = length(dic[:region])
            end

            # chemical shift values
            δ = LinRange(procdic[:offset], procdic[:offset]-dic[:swppm], dic[:npoints]+ 1)
            dic[:val] = δ[1:end-1]

            # create a representation of the window function
            # calculate acquisition time = td / 2*sw
            taq = 0.5 * dic[:td] / dic[:swhz]
            w = procdic[:wdw]
            if w == 0
                window = NullWindow(taq)
            elseif w == 1
                window = ExponentialWindow(procdic[:lb], taq)
            elseif w == 2
                warn("Gaussian window not yet implemented")
                window = UnknownWindow(taq)
            elseif w == 3
                ssb = procdic[:ssb]
                if ssb < 1
                    ssb = 1
                end
                window = SineWindow(1 - 1.0/ssb, 1, 1, taq) # offset, endpoint, power
            elseif w == 4
                ssb = procdic[:ssb]
                if ssb < 1
                    ssb = 1
                end
                window = SineWindow(1 - 1.0/ssb, 1, 2, taq) # offset, endpoint, power
            else
                window = UnknownWindow(taq)
            end
            dic[:window] = window
        end

        dic[:procs] = procsdics[i] # store procs file in main axis dictionary
        push!(axesmd, dic)
    end

    # 5. determine shape and submatrix size
    shape = [procs[:si] for procs ∈ procsdics]
    submatrix = [procs[:xdim] for procs ∈ procsdics]

    # 6. check data format (default to Int32)
    dtype = get(procsdics[1], :dtypp, 1) == 2 ? Float64 : Int32

    # 7. check endianness (default to little)
    endian = get(procsdics[1], :bytordp, 0) == 1 ? "b" : "l"

    # 8. read the data files
    dat = map(datafile -> readpdatabinary(datafile, shape, submatrix, dtype, endian), datafiles)

    # 9. combine into real/complex/multicomplex output
    if !allcomponents
        y = first(dat)
    elseif ndim == 1
        if length(dat) == 1
            warn("unable to find imaginary data for import of $filename - returning real values only")
            y = dat
        else
            y = dat[1] + 1im .* dat[2]
        end
    else
        # TODO
        warn("import of multicomplex data not yet implemented - returning real values only")
        y = dat
    end

    # 10. scale
    scalepdata!(y, procsdics[1])

    # 11. form NMRData and return
    if ndim == 1
        valx = axesmd[1][:val]
        delete!(axesmd[1],:val) # remove values from metadata to prevent confusion when slicing up

        xaxis = F1Dim(valx, metadata=axesmd[1])

        NMRData(y, (xaxis, ), metadata=md)
    elseif ndim == 2
        valx = axesmd[1][:val]
        valy = axesmd[2][:val]
        delete!(axesmd[1],:val) # remove values from metadata to prevent confusion when slicing up
        delete!(axesmd[2],:val)
        
        xaxis = F1Dim(valx, metadata=axesmd[1])
        ax2 = axesmd[2][:pseudodim] ? X2Dim : F2Dim
        yaxis = ax2(valy, metadata=axesmd[2])
        @show size(xaxis)
        @show size(yaxis)
        @show size(y)
    
        NMRData(y, (xaxis, yaxis), metadata=md)
    else
        throw(NMRToolsException("can't load bruker 3D data yet"))
    end
end


function scalepdata!(y, procs, reverse=false)
    if reverse
        y *= 2.0^(-get(procs,:nc_proc,1))
    else
        y *= 2.0^(get(procs,:nc_proc,1))
    end
end


function readpdatabinary(filename, shape, submatrix, dtype, endian)
    # preallocate header
    np = foldl(*, shape)
    y = zeros(dtype, np)
    
    # read the file
    open(filename) do f
        read!(f, y)
    end
    convertor = endian=="b" ? ntoh : ltoh # get convertor function for big/little-to-host
    y = convertor(y)

    reordersubmatrix(y, shape, submatrix)
end


function reordersubmatrix(yin, shape, submatrix, reverse=false)
    ndim = length(shape)
    if ndim == 1
        # do nothing to 1D data
        return yin
    end
    
    nsub = @. Int(ceil(shape / submatrix))
    nsubs = foldl(*, nsub)
    N = length(yin)
    sublength = foldl(*, submatrix)

    subshape = vcat(nsubs, submatrix)
    if reverse
        yout = zeros(eltype(yin), N)
    else
        yout = zeros(eltype(yin), shape...)
    end

    ci = CartesianIndices(ones(nsub...))
    for n = 1:nsubs
        idx = ci[n]
        slices = [(1+(idx[i]-1)*submatrix[i]):idx[i]*submatrix[i] for i=1:ndim]
        vecslice = 1+(n-1)*sublength:n*sublength
        if reverse
            yout[vecslice] = yin[slices...]
        else
            yout[slices...] = yin[vecslice]
        end
    end
    
    return yout
end