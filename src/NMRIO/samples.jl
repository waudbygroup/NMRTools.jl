"""
    addsampleinfo(expt::NMRData) -> NMRData

Search for and load sample metadata from JSON files in the experiment folder.
Returns the NMRData object with sample information added to metadata.

Sample files are JSON files following the schema at https://github.com/waudbygroup/nmr-sample-schema.
The function matches samples based on creation/ejection timestamps against the experiment date.

# Examples
```julia
spec = loadnmr("experiment/1/pdata/1")
spec = addsampleinfo(spec)  # Load matching sample metadata
sample(spec, "notes")  # Access sample information
```

See also [`sample`](@ref), [`hassample`](@ref).
"""
function addsampleinfo(expt::NMRData)
    samplelist = findsamples(expt[:experimentfolder])
    length(samplelist) == 0 && return expt # no samples found

    sampledate = expt[:date]
    isnothing(sampledate) && return expt # no date in spectrum metadata

    # search sample list for sampledate between creation and ejection times, and get the filename if found
    for (samplefile, tcreation, tejection) in samplelist
        if tcreation <= sampledate <= tejection
            # found matching sample
            expt[:samplefile] = samplefile
            break
        end
    end
    isnothing(expt[:samplefile]) && return expt # no matching sample found

    # load sample metadata from json file
    expt[:sample] = JSON.parsefile(expt[:samplefile]; dicttype=Dict{String,Any})
    return expt
end

function findsamples(experimentfolder)
    # return a list of samples in the parent directory: (samplefilename, createdtime, ejectedtime)
    parentdir = dirname(experimentfolder)
    # samples are json files in the parent directory
    samplefiles = filter(f -> endswith(f, ".json"), readdir(parentdir; join=true))
    samples = []
    for samplefile in samplefiles
        # read json
        try
            j = JSON.parsefile(samplefile)
            m = j["metadata"]
            v = VersionNumber(m["schema_version"])
            v >= v"0.0.3" || continue # minimum supported schema version
            creation = get(m, "created_timestamp", nothing)
            isnothing(creation) && continue
            tcreation = DateTime(creation, dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")

            ejection = get(m, "ejected_timestamp", nothing)
            if isnothing(ejection)
                # not ejected - put in far future
                tejection = DateTime("3000-01-01T00:00:00.000Z",
                                     dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")
            else
                tejection = DateTime(ejection, dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")
            end
            push!(samples, (samplefile, tcreation, tejection))
        catch e
            continue
        end
    end
    return samples
end