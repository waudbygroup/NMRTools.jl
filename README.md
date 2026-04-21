# NMRTools.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://waudbylab.github.io/NMRTools.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://waudbylab.github.io/NMRTools.jl/dev)
[![CI](https://github.com/waudbylab/NMRTools.jl/actions/workflows/Runtests.yml/badge.svg)](https://github.com/waudbylab/NMRTools.jl/actions/workflows/Runtests.yml)
[![Codecov](https://codecov.io/gh/waudbylab/NMRTools.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/waudbylab/NMRTools.jl)
[![DOI](https://zenodo.org/badge/251587402.svg)](https://zenodo.org/badge/latestdoi/251587402)

![NMRTools logo](logo.png)

NMRTools.jl is a Julia library for NMR spectroscopy data. It reads 1D, 2D, and higher-dimensional datasets and exposes them as named-dimension arrays with full metadata support.

## Features

- **Multi-format support**: Read Bruker, nmrPipe, and UCSF/Sparky formatted data
- **Chemical shift indexing**: Array-like indexing with chemical shift values using `spec[8.0 .. 9.0]` syntax
- **Plotting**: Publication-ready plots via Plots.jl recipes, with contour level and colour control
- **Metadata**: Access acquisition parameters from Bruker `acqus` files; window functions, power levels, and frequency lists represented as typed objects
- **DimensionalData.jl integration**: Named dimension arrays with selectors for frequency, time, and gradient dimensions

## Quick Start

Install NMRTools.jl through the Julia package manager:

```julia
using Pkg
Pkg.add("NMRTools")
```

Load and plot a spectrum:

```julia
using NMRTools, Plots

# Load data (auto-detects format)
spec = loadnmr("path/to/experiment")

# Plot the full spectrum
plot(spec)

# Zoom to a chemical shift range
plot(spec[8.0 .. 9.0])

# Access data and metadata
data(spec)
metadata(spec)
```

## Documentation

Documentation with tutorials and examples is available at:
- [**Stable docs**](https://waudbylab.org/NMRTools.jl/stable) — Latest release
- [**Dev docs**](https://waudbylab.org/NMRTools.jl/dev) — Development version

## Development Status

> **NOTE**: This package is under active development and the API may change between releases. Please refer to the [documentation](https://waudbylab.github.io/NMRTools.jl/stable) for current usage examples.

## Citation

If you use NMRTools.jl in your research, please cite:
[![DOI](https://zenodo.org/badge/251587402.svg)](https://zenodo.org/badge/latestdoi/251587402)
