# NMRTools.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://waudbygroup.github.io/NMRTools.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://waudbygroup.github.io/NMRTools.jl/dev)
[![CI](https://github.com/waudbygroup/NMRTools.jl/actions/workflows/Runtests.yml/badge.svg)](https://github.com/waudbygroup/NMRTools.jl/actions/workflows/Runtests.yml)
[![Codecov](https://codecov.io/gh/waudbygroup/NMRTools.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/waudbygroup/NMRTools.jl)
[![DOI](https://zenodo.org/badge/251587402.svg)](https://zenodo.org/badge/latestdoi/251587402)

![NMRTools logo](logo.png)

A Julia library for importing, processing, and plotting NMR spectroscopy data.

## Features

- **Multi-format I/O**: Read Bruker, nmrPipe, UCSF/Sparky, and JCAMP-DX formats with automatic format detection
- **Intuitive interface**: Index spectra by chemical shift values: `spec[8.0 .. 9.0]`
- **Built-in plotting**: Publication-quality plots with Plots.jl recipes
- **Metadata support**: Access and manipulate Bruker `acqus` parameters
- **Processing tools**: Window functions, apodization, and spectral manipulation
- **Flexible dimensions**: Support for frequency, time, and gradient dimensions
- **DimensionalData.jl**: Powerful array operations with named dimensions

## Quick Start

Install via the Julia package manager:

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

Comprehensive documentation with tutorials and examples is available at:
- [**Stable docs**](https://waudbygroup.github.io/NMRTools.jl/stable) - Latest release
- [**Dev docs**](https://waudbygroup.github.io/NMRTools.jl/dev) - Development version

Topics covered include:
- Getting started guide with 1D and 2D examples
- Relaxation and diffusion analysis workflows
- Advanced plotting and customization
- Metadata manipulation and window functions


## Development Status

> **NOTE**: This package is under active development and it may be a while before its features and syntax stabilise. Please refer to the [documentation](https://waudbygroup.github.io/NMRTools.jl/stable) for current usage examples.

## Citation

If you use NMRTools.jl in your research, please cite:
[![DOI](https://zenodo.org/badge/251587402.svg)](https://zenodo.org/badge/latestdoi/251587402)
