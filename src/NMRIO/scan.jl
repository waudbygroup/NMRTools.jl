"""
    scanexperiments(dir; recursive=true, pdatadir=1, warn=true) -> Vector{NMRExperiment}

Scan `dir` for Bruker NMR experiment folders and return a vector of lightweight
[`NMRExperiment`](@ref) descriptors sorted by experiment date (oldest first).

A folder is identified as a Bruker experiment if it contains an `acqus` file.
Once identified, the scanner does not recurse into it, so `pdata/` subdirectories
are never misidentified as experiments.

# Arguments
- `dir`: Root directory to scan.
- `recursive`: If `true` (default), search subdirectories. If `false`, only
  check immediate children of `dir`.
- `pdatadir`: Only include experiments that have a `pdata/<pdatadir>/` subdirectory,
  i.e. where `loadnmr` would succeed. Pass `nothing` to include all experiments
  regardless of whether processed data exists.
- `warn`: If `true` (default), warn about folders that cannot be parsed.

# Examples
```julia
expts = scanexperiments("/nmr/projects/lysozyme/")

# Filter with standard Julia
hsqc = filter(e -> e[:pulseprogram] == "hsqcetfpf3gpsi2", expts)
cest = filter(e -> "cest" in get(annotations(e), "experiment_type", []), expts)

# Load one
spec = loadnmr(expts[1])
```

See also: [`NMRExperiment`](@ref), [`scansamples`](@ref NMRTools.NMRIO.scansamples), [`findexperiments`](@ref NMRTools.NMRIO.findexperiments).
"""
function scanexperiments(dir::AbstractString;
                         recursive::Bool=true,
                         pdatadir::Union{Int,Nothing}=1,
                         warn::Bool=true)::Vector{NMRExperiment}
    dir = abspath(dir)
    isdir(dir) || throw(NMRToolsError("not a directory: $dir"))

    folders = String[]
    _scan_experiment_dirs!(folders, dir, recursive)

    expts = NMRExperiment[]
    for folder in folders
        if !isnothing(pdatadir)
            isdir(joinpath(folder, "pdata", string(pdatadir))) || continue
        end
        try
            push!(expts, NMRExperiment(folder))
        catch e
            warn && @warn "Skipping $folder" exception=e
        end
    end

    sort!(expts, by = e -> something(e[:date], typemax(DateTime)))
    return expts
end

function _scan_experiment_dirs!(results::Vector{String}, dir::String, recursive::Bool)
    if isfile(joinpath(dir, "acqus"))
        push!(results, dir)
        return  # don't recurse inside experiment folders
    end
    if recursive
        for entry in readdir(dir; join=true)
            isdir(entry) && _scan_experiment_dirs!(results, entry, recursive)
        end
    else
        for entry in readdir(dir; join=true)
            if isdir(entry) && isfile(joinpath(entry, "acqus"))
                push!(results, entry)
            end
        end
    end
end

"""
    findexperiments(sample::NMRSample, dir::String; kw...) -> Vector{NMRExperiment}
    findexperiments(sample::NMRSample, candidates::Vector{NMRExperiment}) -> Vector{NMRExperiment}

Find all experiments matching `sample` based on the experiment date falling within
the sample's creation–ejection timestamp window.

- With a directory path, calls `scanexperiments(dir; kw...)` then filters.
- With a pre-scanned `Vector{NMRExperiment}`, filters without any disk I/O.

See also: [`scanexperiments`](@ref NMRTools.NMRIO.scanexperiments), [`findsample`](@ref NMRTools.NMRIO.findsample).
"""
function findexperiments(sample::NMRSample; kw...)::Vector{NMRExperiment}
    findexperiments(sample, dirname(samplefile(sample)); kw...)
end

function findexperiments(sample::NMRSample, dir::AbstractString; kw...)::Vector{NMRExperiment}
    findexperiments(sample, scanexperiments(dir; kw...))
end

function findexperiments(sample::NMRSample,
                         candidates::Vector{NMRExperiment})::Vector{NMRExperiment}
    tcreation, tejection = _sample_timestamps(sample)
    isnothing(tcreation) && return NMRExperiment[]
    return filter(candidates) do e
        d = e[:date]
        !isnothing(d) && tcreation <= d <= tejection
    end
end
