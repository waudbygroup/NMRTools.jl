"""
    NMRExperiment(experimentfolder::String) -> NMRExperiment

Construct a metadata-only descriptor from a Bruker NMR experiment folder.
Reads acqus, title, and pulse programme (text files only) — no binary data loaded.
Annotations are parsed from the pulse programme YAML but parameter references are
not resolved (full resolution happens in `loadnmr`).

See also: [`scanexperiments`](@ref), [`loadnmr`](@ref).
"""
function NMRExperiment(experimentfolder::AbstractString)
    path = abspath(experimentfolder)
    isdir(path) || throw(NMRToolsError("not a directory: $path"))
    isfile(joinpath(path, "acqus")) ||
        throw(NMRToolsError("not a Bruker experiment folder (no acqus file): $path"))

    md = loadmetadata(path)
    _annotate_metadata!(md)
    _addsampleinfo_metadata!(md)

    return NMRExperiment(path, md)
end
