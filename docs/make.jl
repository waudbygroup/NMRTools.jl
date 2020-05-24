using Documenter, NMRTools, Plots
ENV["GKSwstype"] = "100" # https://github.com/jheinen/GR.jl/issues/278

makedocs(;
    modules=[NMRTools],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Examples" => "examples.md",
        "Metadata" => "metadata.md",
    ],
    repo="https://github.com/chriswaudby/NMRTools.jl/blob/{commit}{path}#L{line}",
    sitename="NMRTools.jl",
    authors="Chris Waudby",
    assets=String[],
)

deploydocs(;
    repo="github.com/chriswaudby/NMRTools.jl",
)
