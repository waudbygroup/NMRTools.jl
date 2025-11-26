# NMRTools.jl

NMRTools.jl is a Julia library for importing, processing, and plotting NMR spectroscopy data. It provides a flexible and intuitive interface for working with 1D, 2D, and higher-dimensional NMR datasets.

## Features

- **Multi-format support**: Read Bruker, nmrPipe, UCSF/Sparky, and JCAMP-DX formats with automatic format detection
- **Intuitive data access**: Array-like indexing with chemical shift values using `spec[8.0 .. 9.0]` syntax
- **Built-in plotting**: Publication-quality plots with sensible defaults via Plots.jl recipes
- **Metadata handling**: Access and manipulate acquisition parameters from Bruker `acqus` files
- **Window functions**: Apply apodization and processing functions for spectral optimization
- **Dimensional flexibility**: Work seamlessly with frequency, time, and gradient dimensions
- **DimensionalData.jl integration**: Leverage powerful array indexing with named dimensions

## Getting Started

Install NMRTools.jl through the Julia package manager:

```julia
using Pkg
Pkg.add("NMRTools")
```

Load and plot a spectrum:

```julia
using NMRTools, Plots
spec = loadnmr("path/to/experiment")
plot(spec)
```

See the [Getting Started](@ref) guide for more examples, or explore the tutorial pages for detailed workflows including relaxation analysis, diffusion experiments, and advanced plotting techniques.

!!! note
    This package is under active development and it may be a while before its features and syntax stabilises.

