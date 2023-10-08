using Documenter, NMRTools, Plots

DocMeta.setdocmeta!(NMRTools, :DocTestSetup, :(using NMRTools); recursive=true)

makedocs(;
    modules=[NMRTools],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        # "Examples" => "examples.md",
        # "Metadata" => "metadata.md",
    ],
    # repo=GitHub("waudbygroup", "NMRTools.jl"),
    sitename="NMRTools.jl",
    authors="Chris Waudby",
)

deploydocs(;
    repo="github.com/waudbygroup/NMRTools.jl.git",
    versions = ["stable" => "v^", "v#.#", "dev" => "master"],
)
