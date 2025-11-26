# NMRTools.jl

NMRTools.jl is a Julia library for working with NMR spectroscopy data. It provides a simple interface for importing and handling 1D, 2D, and higher-dimensional datasets.

## Features

- **Multi-format support**: Read Bruker, nmrPipe and UCSF/Sparky formatted data
- **Intuitive data access**: Array-like indexing with chemical shift values using `spec[8.0 .. 9.0]` syntax
- **Built-in plotting**: Publication-quality plots with sensible defaults via Plots.jl recipes
- **Metadata handling**: Easily access acquisition parameters from Bruker `acqus` files
- **Window functions**: Access and analyse apodization functions used for acquisition
- **DimensionalData.jl integration**: Leverage powerful array indexing with named dimensions to work seamlessly with frequency, time, and gradient dimensions

## Quick Start

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

See the [Getting started](@ref) guide for more examples, or explore the tutorial pages for detailed workflows including relaxation analysis, diffusion experiments, and advanced plotting techniques.

!!! note
    This package is under active development and it may be a while before its features and syntax stabilises.

