# NMRTools.jl

NMRTools.jl is a Julia library for NMR spectroscopy data. It reads 1D, 2D, and higher-dimensional datasets and exposes them as named-dimension arrays with full metadata support.

- **Multi-format support**: Read Bruker, nmrPipe, and UCSF/Sparky formatted data
- **Chemical shift indexing**: Array-like indexing with chemical shift values using `spec[8.0 .. 9.0]` syntax
- **Plotting**: Publication-ready plots via Plots.jl recipes, with contour level and colour control
- **Metadata**: Access acquisition parameters from Bruker `acqus` files; window functions, power levels, and frequency lists represented as typed objects
- **DimensionalData.jl integration**: Named dimension arrays with selectors for frequency, time, and gradient dimensions

## Installation

Install NMRTools.jl through the Julia package manager:

```julia
using Pkg
Pkg.add("NMRTools")
```

Load and plot a spectrum:

```julia
using NMRTools, Plots
spec = loadnmr("path/to/experiment/1")
plot(spec)
```

See the [Getting started](@ref) guide for more examples, or explore the tutorial pages for detailed workflows including relaxation analysis, diffusion experiments, and advanced plotting techniques.

## Related packages

| Package | Description |
|---------|-------------|
| [MulticomplexNumbers.jl](https://github.com/waudbylab/MulticomplexNumbers.jl) | Multicomplex number types with FFTW extension, providing the algebraic foundation for NMR quadrature detection |
| [NMRAnalysis.jl](https://github.com/waudbylab/NMRAnalysis.jl) | Quantitative NMR data analysis: relaxation, diffusion, titrations, and lineshape fitting |
| [NMRScreen.jl](https://github.com/waudbylab/NMRScreen.jl) | Automated NMR screening workflows |
