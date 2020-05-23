using Documenter, NMRTools

makedocs(;
    modules=[NMRTools],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Examples" => "examples.md",
    ],
    repo="https://github.com/chriswaudby/NMRTools.jl/blob/{commit}{path}#L{line}",
    sitename="NMRTools.jl",
    authors="Chris Waudby",
    assets=String[],
)

deploydocs(;
    repo="github.com/chriswaudby/NMRTools.jl",
)
