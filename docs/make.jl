using Documenter, NMRTools, Plots

ENV["GKSwstype"] = "100"

DocMeta.setdocmeta!(NMRTools, :DocTestSetup, :(using NMRTools); recursive=true)

makedocs(;
         modules=[NMRTools],
         format=Documenter.HTML(; prettyurls=(get(ENV, "CI", nothing) == "true")),
         pages=["Home" => "index.md",
                "Getting started" => "quickstart.md",
                "Tutorials" => ["Working with NMR data" => "tutorial-data.md",
                                # "Non-frequency dimensions" => "tutorial-nonfreqdims.md",
                                "Plotting" => "tutorial-plotrecipes.md",
                                "Metadata" => "tutorial-metadata.md",
                                "Animating spectra" => "tutorial-animation.md",
                                "1D relaxation analysis" => "tutorial-relaxation.md",
                                "Diffusion analysis" => "tutorial-diffusion.md"
                                # "2D phosphorylation kinetics" => "tutorial-phosphorylation.md",
                                ],
                "Utilities" => "utilities.md",
                "Reference guide" => ["Annotations" => "ref-annotations.md",
                                      #     "Data" => "ref-data.md",
                                      #     "Dimensions" => "ref-dimensions.md",
                                      #     "File I/O" => "ref-io.md",
                                      "Metadata" => "ref-metadata.md",
                                      #     "Window functions" => "ref-windows.md",
                                      "Coherences and isotope data" => "ref-coherences.md"
                                      #     "Exceptions" => "ref-exceptions.md",
                                      #     "Plotting with JuliaPlots" => "ref-plots.md",
                                      ],
                "API" => "api.md",
                "Index" => "indexes.md"],
         # repo=GitHub("waudbygroup", "NMRTools.jl"),
         sitename="NMRTools.jl",
         authors="Chris Waudby",
         warnonly=[:missing_docs],)

deploydocs(;
           repo="github.com/waudbygroup/NMRTools.jl.git",
           versions=["stable" => "v^", "v#.#", "dev" => "master"],)
