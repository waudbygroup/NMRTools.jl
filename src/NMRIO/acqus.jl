function addexptmetadata!(spectrum, filename, experimentfolder)
    # TODO - this assumes we're dealing with Bruker data…

    # try to locate the folder containing the acqus file
    if isnothing(experimentfolder)
        experimentfolder = dirname(filename)
        # assume that acqus is in same directory as test.ft2 files, and one up from ft/test%03d.ft2 files
        if spectrum[:format] == :nmrpipe && occursin("%", basename(filename))
            experimentfolder = dirname(experimentfolder) # this moves up one directory
        end
    else
        # if the passed experiment folder isn't a directory, use the enclosing directory
        if isfile(experimentfolder)
            experimentfolder = dirname(experimentfolder)
        end
    end
    spectrum[:experimentfolder] = experimentfolder

    
    # parse the acqus file
    acqusfilename = joinpath(experimentfolder, "acqus")
    if isfile(acqusfilename)
        acqusmetadata = parseacqus(acqusfilename)
        spectrum[:acqus] = acqusmetadata
        spectrum[:ns] = acqusmetadata["NS"]
        spectrum[:rg] = acqusmetadata["RG"]
        spectrum[:pulseprogram] = acqusmetadata["PULPROG"]
        spectrum[:acqusfilename] = acqusfilename
    else
        @warn "cannot locate acqus file for $(filename) - some metadata will be missing"
    end

    # load the title file
    titlefilename = joinpath(experimentfolder, "pdata", "1", "title")
    if isfile(titlefilename)
        title = read(titlefilename, String)
        spectrum[:title] = strip(title)
        # use first line of title for experiment label
        titleline1 = split(title, "\n")[1]
        spectrum[:label] = titleline1
    else
        @warn "cannot locate title file for $(filename) - some metadata will be missing"
    end
end



function parseacqus(acqusfilename::String)
    dic = loadjdx(acqusfilename)

    # lastly, check for referenced files like vclist, fq1list, and load these in place of filename
    parseacqusauxfiles!(dic, dirname(acqusfilename))

    return dic
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
