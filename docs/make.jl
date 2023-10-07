using Documenter, NMRTools, Plots

makedocs(;
    modules=[NMRTools],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Examples" => "examples.md",
        "Metadata" => "metadata.md",
    ],
    repo=GitHub("waudbygroup", "NMRTools.jl"),
    sitename="NMRTools.jl",
    authors="Chris Waudby",
    assets=String[],
)

deploydocs(;
    repo="github.com/waudbygroup/NMRTools.jl.git",
    versions = ["stable" => "v^", "v#.#", "dev" => "master"],
)
