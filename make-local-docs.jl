using Pkg
Pkg.instantiate()
Pkg.develop(path=pwd())
include("docs/make.jl")