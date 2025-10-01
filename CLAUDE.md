# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

**Testing:**
- `julia -e 'using Pkg; Pkg.test()'` - Run all tests using SafeTestsets
- Test files: `test/nmrbase_test.jl`, `test/nmrio_test.jl`, `test/plotsext_test.jl`

**Documentation:**
- `julia make-local-docs.jl` - Build documentation locally (installs package in dev mode and runs docs/make.jl)
- `julia docs/make.jl` - Build documentation directly
- Documentation uses Documenter.jl with visual regression tests for plots

**Package Management:**
- Standard Julia package - use `] dev .` to develop locally
- Extensions system: PlotsExt.jl provides plotting functionality when Plots.jl is loaded

## Architecture Overview

NMRTools.jl is organized into two main modules that handle different aspects of NMR data processing:

### Core Structure
- **NMRTools.jl** (main module): Re-exports NMRBase and NMRIO modules
- **NMRBase/**: Core data structures and NMR-specific operations
- **NMRIO/**: File I/O for various NMR formats (Bruker, nmrPipe, UCSF, JDX)
- **ext/PlotsExt.jl**: Plotting recipes loaded when Plots.jl is available

### Key Data Architecture
- **AbstractNMRData**: Base type extending DimensionalData.AbstractDimArray
- **NMRData**: Main data container wrapping arrays with metadata and dimensions
- **NMR Dimensions**: Custom dimension types (FrequencyDimension, TimeDimension, GradientDimension, etc.)
- Built on DimensionalData.jl for array indexing with named dimensions

### File Format Support
- **Bruker**: Native Bruker format with acqus parameter parsing
- **nmrPipe**: NMRPipe format support
- **UCSF/Sparky**: UCSF format for 2D/3D data
- **JCAMP-DX**: JDX format support
- **loadnmr()**: Universal loader that auto-detects format

### Plotting Integration
- Recipe-based plotting using Plots.jl extension system
- Automatic axis labeling with chemical shift units
- Support for 1D, 2D, pseudo-2D, and 3D NMR data visualization
- Contour plots for 2D data with customizable levels

### Testing Patterns
- Uses SafeTestsets for isolated test environments  
- Visual regression tests for plotting functionality using reference PNG files
- Test data includes real NMR datasets for format validation

### Key Conventions
- Dimensions follow NMR naming: F1Dim, F2Dim (frequency), T1Dim, T2Dim (time), G1Dim (gradients)
- Metadata stored using custom Metadata types with acqus parameter integration
- Chemical shift axes default to ppm units with reversed (right-to-left) orientation
- Window functions and apodization follow standard NMR processing conventions