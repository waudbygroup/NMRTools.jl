function getacqusmetadata(format, filename, experimentfolder=nothing)
    # TODO - this assumes we're dealing with Bruker data…

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
        md[:ns] = acqusmetadata[:ns]
        md[:rg] = acqusmetadata[:rg]
        md[:pulseprogram] = acqusmetadata[:pulprog]
        md[:acqusfilename] = acqusfilename
    else
        @warn "cannot locate acqus file for $(filename) - some metadata will be missing"
    end

    # parse the acquXs files, if they exist
    for i in 2:4
        acquXsfilename = joinpath(experimentfolder, "acqu$(i)s")
        if isfile(acquXsfilename)
            acquXsmetadata = parseacqus(acquXsfilename)
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

function parseacqus(acqusfilename::String)
    dic = loadjdx(acqusfilename)

    # lastly, check for referenced files like vclist, fq1list, and load these in place of filename
    parseacqusauxfiles!(dic, dirname(acqusfilename))

    return dic
end

function parseacqusauxfiles!(dic, basedir)
    for k in (:vclist,) # integer lists
        get(dic, k, "") == "" && continue
        # note that filenames aren't actually used - vclist is always stored as vclist
        filename = joinpath(basedir, string(k))
        ispath(filename) || continue
        x = readlines(filename)
        xi = tryparse.(Int, x)
        if any(xi .== nothing)
            @warn "Unable to parse format of list $(k) when opening $(filename)"
            dic[k] = x
        else
            dic[k] = xi
        end
    end

    for k in
        (:fq1list, :fq2list, :fq3list, :fq4list, :fq5list, :fq6list, :fq7list, :fq8list,
         :valist, :vdlist, :vplist, :vtlist) # float lists
        get(dic, k, "") == "" && continue
        # note that filenames aren't actually used - vclist is always stored as vclist
        filename = joinpath(basedir, string(k))
        ispath(filename) || continue
        x = readlines(filename)
        xp = [replace(replace(xs, "u" => "e-6"), "m" => "e-3") for xs in x]
        xf = tryparse.(Float64, xp)
        if any(xf .== nothing)
            @warn "Unable to parse format of list $(k) when opening $(filename)"
            dic[k] = x
        else
            dic[k] = xf
        end
    end
end
