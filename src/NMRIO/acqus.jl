function getacqusmetadata(format, filename, experimentfolder=nothing)
    md = Dict{Symbol,Any}()
    md[:format] = format

    # try to locate the folder containing the acqus file
    if isnothing(experimentfolder)
        if format == :nmrpipe
            # assume that acqus is in same directory as test.ft2 files, and one up from ft/test%03d.ft2 files
            experimentfolder = dirname(filename)
            if occursin("%", basename(filename))
                # move up a directory
                experimentfolder = dirname(experimentfolder)
            end
        elseif format == :pdata
            # move up two directories from X/pdata/Y to X
            if isdir(filename)
                if isdirpath(filename)
                    # filename = X/pdata/Y/
                    # dirname = X/pdata/Y
                    experimentfolder = dirname(dirname(dirname(filename)))
                else
                    # filename = X/pdata/Y
                    # dirname = X/pdata
                    experimentfolder = dirname(dirname(filename))
                end
            else
                experimentfolder = dirname(dirname(dirname(filename)))
            end
        end
    else
        # if the passed experiment folder isn't a directory, use the enclosing directory
        if !isdir(experimentfolder)
            @warn "passed experiment folder $experimentfolder is not a directory"
            if isfile(experimentfolder)
                experimentfolder = dirname(experimentfolder)
            end
        end
    end

    # add filenames to metadata
    md[:filename] = filename
    md[:experimentfolder] = experimentfolder

    # parse the acqus file
    acqusfilename = joinpath(experimentfolder, "acqus")
    if isfile(acqusfilename)
        acqusmetadata = parseacqus(acqusfilename)
        md[:acqus] = acqusmetadata
        md[:topspin] = acqusmetadata[:topspin]
        md[:ns] = acqusmetadata[:ns]
        md[:rg] = acqusmetadata[:rg]
        md[:pulseprogram] = acqusmetadata[:pulprog]
        md[:acqusfilename] = acqusfilename
    else
        @warn "cannot locate acqus file for $(filename) - some metadata will be missing"
    end

    # parse the acquXs files, if they exist, and store in :acquXs dict entries
    for i in 2:4
        acquXsfilename = joinpath(experimentfolder, "acqu$(i)s")
        if isfile(acquXsfilename)
            acquXsmetadata = parseacqus(acquXsfilename, false) # don't parse aux files
            md[Symbol("acqu$(i)s")] = acquXsmetadata
        else
            break
        end
    end

    # load the title file
    titlefilename = joinpath(experimentfolder, "pdata", "1", "title")
    if isfile(titlefilename)
        title = read(titlefilename, String)
        md[:title] = strip(title)
        # use first line of title for experiment label
        titleline1 = split(title, "\n")[1]
        md[:label] = titleline1
    else
        @warn "cannot locate title file for $(filename) - some metadata will be missing"
    end

    return md
end

function parseacqus(acqusfilename::String, auxfiles=true)
    dic = loadjdx(acqusfilename)

    if auxfiles
        # add the topspin version to the dictionary
        dic[:topspin] = topspinversion(acqusfilename)

        # lastly, check for referenced files like vclist, fq1list, and load these in place of filename
        parseacqusauxfiles!(dic, dirname(acqusfilename))
    end

    return dic
end


"""
    parsetopspinversion(acqusfilename)

Return the TopSpin version as a VersionNumber (e.g. v"4.2.0").

This is obtained from the end of the first line of the acqus file, e.g.
```
##TITLE= Parameter file, TopSpin 4.2.0
##TITLE= Parameter file, TOPSPIN		Version 2.1
##TITLE= Parameter file, TOPSPIN		Version 3.2
```
"""
function topspinversion(acqusfilename)
    isfile(acqusfilename) ||
        throw(NMRToolsError("getting TopSpin version: $(acqusfilename) is not a valid acqus file"))

    firstline = readlines(acqusfilename)[1]
    version = split(firstline)[end]

    return VersionNumber(version)
end

function parseacqusauxfiles!(dic, basedir)
    # TS 4.0.8 - pulseprogram / pulseprogram.precomp introduced
    # TS 4.1.4 - lists directory introduced
    if dic[:topspin] < v"4.1.4"
        _parseacqusauxfiles_TS3!(dic, basedir)
    else
        _parseacqusauxfiles_TS4!(dic, basedir)
    end
end


function _parseacqusauxfiles_TS3!(dic, basedir)
    # filenames aren't actually used before TS4 - e.g. vclist is always stored as vclist
    if get(dic, :vclist, "") != ""
        filename = joinpath(basedir, "vclist")
        if isfile(filename)
            dic[:vclist] = parsevclist(filename)
        end
    end
    

    if get(dic, :vdlist, "") != ""
        filename = joinpath(basedir, "vdlist")
        if isfile(filename)
            dic[:vdlist] = parsevdlist(filename)
        end
    end

    if get(dic, :vplist, "") != ""
        filename = joinpath(basedir, "vplist")
        if isfile(filename)
            dic[:vplist] = parsevplist(filename)
        end
    end

    if get(dic, :valist, "") != ""
        filename = joinpath(basedir, "valist")
        if isfile(filename)
            dic[:valist] = parsevalist(filename)
        end
    end

    for k in (:fq1list, :fq2list, :fq3list, :fq4list, :fq5list, :fq6list, :fq7list, :fq8list)
        get(dic, k, "") == "" && continue
        
        filename = joinpath(basedir, string(k))
        isfile(filename) || continue

        dic[k] = parsefqlist(filename)
    end
end

function _parseacqusauxfiles_TS4!(dic, basedir)
    vclistfile = joinpath(basedir, "lists", "vc", get(dic, :vclist, ""))
    if isfile(vclistfile)
        dic[:vclist] = parsevclist(vclistfile)
    end

    vdlistfile = joinpath(basedir, "lists", "vd", get(dic, :vdlist, ""))
    if isfile(vdlistfile)
        dic[:vdlist] = parsevdlist(vdlistfile)
    end

    vplistfile = joinpath(basedir, "lists", "vp", get(dic, :vplist, ""))
    if isfile(vplistfile)
        dic[:vplist] = parsevplist(vplistfile)
    end

    valistfile = joinpath(basedir, "lists", "va", get(dic, :valist, ""))
    if isfile(valistfile)
        dic[:valist] = parsevalist(valistfile)
    end

    for k in (:fq1list, :fq2list, :fq3list, :fq4list, :fq5list, :fq6list, :fq7list, :fq8list)
        fqlistfile = joinpath(basedir, "lists", "f1", get(dic, k, ""))
        isfile(fqlistfile) || continue
        dic[k] = parsefqlist(fqlistfile)
    end

    # lists/pp (pulseprogram)
    # lists/gp
    # lists/vc
    # lists/vd
    # lists/va
    # lists/vp
    # lists/f1 (frequencies)
    # referred to by name in the acqus file
end

function parsevclist(filename)
    x = readlines(filename)
    xint = tryparse.(Int, x)
    if any(xint .== nothing)
        @warn "Unable to parse format of vclist $filename"
        return x
    end

    return xint
end

"return vdlist contents in seconds"
function parsevdlist(filename)
    x = readlines(filename)
    # default unit for vdlist is seconds
    replace!(x, "u" => "e-6")
    replace!(x, "m" => "e-3")
    replace!(x, "s" => "")
    xf = tryparse.(Float64, x)
    if any(xf .== nothing)
        @warn "Unable to parse format of vdlist $filename"
        return x
    end
    
    return xf
end

"return vplist contents in seconds"
function parsevplist(filename)
    x = readlines(filename)
    # default unit for vplist is seconds
    x = map(x) do line
        line = replace(line, "u" => "")
        line = replace(line, "m" => "e3")
        line = replace(line, "s" => "e6")
    end
    
    xf = tryparse.(Float64, x)

    if any(xf .== nothing)
        @warn "Unable to parse format of vplist $filename"
        return x
    end
    
    return xf * 1e-6  # return vplist in seconds
end

"return valist contents in dB"
function parsevalist(filename)
    x = readlines(filename)

    # power unit must be specified on first lien
    powertoken = popfirst!(x)
    
    # parse the rest of the list
    xf = tryparse.(Float64, x)

    if any(xf .== nothing)
        @warn "Unable to parse format of valist $filename"
        return x
    end

    # convert to dB if needed
    if powertoken == "Watt"
        @info "converting valist from Watt to dB"
        xf = -10 * log10.(xf)
    end
    return xf
end

"""
    parsefqlist(filename)

Return contents of the specified fqlist.

fqlists can have several different formats:

first line   | reference   | unit
----------------------------------
             | sfo         | Hz
sfo hz       | sfo         | Hz
sfo ppm      | sfo         | ppm
bf hz        | bf          | Hz
bf ppm       | bf          | ppm
p            | sfo         | ppm
P            | bf          | ppm

"""
function parsefqlist(filename)
    x = readlines(filename)

    if isnumeric(x[1][1])
        # first character of first line is a number => no header line
        unit = :Hz
        relative = true
    else
        firstline = popfirst!(x)
        if firstline == "p"
            unit = :ppm
            relative = true
        elseif firstline == "P"
            unit = :ppm
            relative = false
        elseif lowercase(firstline) == "bf hz"
            unit = :Hz
            relative = false
        elseif lowercase(firstline) == "bf ppm"
            unit = :ppm
            relative = false
        elseif lowercase(firstline) == "sfo hz"
            unit = :Hz
            relative = true
        elseif lowercase(firstline) == "sfo ppm"
            unit = :ppm
            relative = true
        else
            @warn "Unable to parse format of fqlist $filename"
            return x
        end
    end

    # parse the rest of the list
    xf = tryparse.(Float64, x)

    if any(xf .== nothing)
        @warn "Unable to parse format of fqlist $filename"
        return x
    end

    fqlist = [FQ(v, unit, relative) for v in xf]

    return fqlist
end


