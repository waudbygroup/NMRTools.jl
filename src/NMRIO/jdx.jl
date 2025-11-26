function loadjdx(filename::String)
    isfile(filename) ||
        throw(NMRToolsError("loading JCAMP-DX data: $(filename) is not a valid file"))

    dat = open(filename) do f
        txt = read(f, String)
        return replace(txt, "\r\n" => "\n") # replace Windows line endings with Unix
    end

    fields = [strip(strip(x), '$') for x in split(dat, "##")]
    dic = Dict{Symbol,Any}()
    for field in fields
        field == "" && continue # skip empty lines
        x = split(field, "= ")
        if length(x) > 1
            # store keys as uppercase - there's only a couple of annoying exceptions like NusAMOUNT
            # and forcing uppercase makes it easier to access, e.g. as :vclist not :VCLIST
            dic[Symbol(lowercase(x[1]))] = parsejdxentry(x[2])
        end
    end

    replacepowers!(dic)
    replacedurations!(dic)
    replacefrequencies!(dic)

    return dic
end

function parsejdxentry(dat)
    if dat[1] == '('
        # array data - split into fields
        # handle potential Windows line endings in array data
        fields = split(split(replace(dat, "\r\n" => "\n"), ")\n")[2])
        parsed = map(parsejdxfield, fields)
        if parsed isa Vector{Real}
            parsed = float.(parsed)
        end
        # create a dictionary, 0 => p0, 1 => p1, etc.
        parsed = Dict(zip(0:(length(parsed) - 1), parsed))
    else
        parsed = parsejdxfield(dat)
    end
    return parsed
end

function parsejdxfield(dat)
    if dat[1] == '<' # <string>
        dat = dat[2:(end - 1)]
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
