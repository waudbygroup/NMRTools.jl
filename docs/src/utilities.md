# Utilities

## Combining NMR experiments

`sumexpts(OUTPUT, INPUTFILES...)` is a utility function provided by NMRTools that allows you to combine multiple Bruker NMR experiments with optional weighting factors.
The function accepts the following parameters:

* `OUTPUT`: The experiment number or path where the combined data will be stored
* `INPUTFILES...`: One or more experiment numbers or paths to be combined

The function works with both 1D experiments (using `fid` files) and multidimensional experiments (using `ser` files).

### Basic usage

The most common way to use `sumexpts` is with experiment numbers, which is the standard Bruker convention.

```julia
julia> using NMRTools

julia> cd("myexperiment")

julia> sumexpts(999, 11, 12)
=== NMR Experiment Summation ===
Output: 999
Inputs: 11, 12
Weights: 1.0, 1.0
Created output experiment from 11
Data format: Float64 (little-endian)
Detected nD experiment, using ser files
Cleaning processed data files in pdata/1...
  Removed: 3rrr
Removed pdata/101 directory
Removed pdata/999 directory
Loading 11/ser
Loading 12/ser
Applied weight 1.0 to experiment 11
Applied weight 1.0 to experiment 12
Writing output to 999/ser
Scans from 11: 8 × 1.0 = 8.0
Scans from 12: 16 × 1.0 = 16.0
Updated number of scans to 24
Updated title file with experiment summary
=== Operation completed successfully ===
```

This creates a new experiment directory by copying experiment 11 as a template, then adding the raw data from all input experiments together. The result is stored in experiment 999.

You can also use full paths if your experiments are in different directories:

```julia
# Combine experiments from a specific path
julia> sumexpts("myexperiment/999", "myexperiment/11", "myexperiment/12")
# Output similar to above example
```

### Adding multiple experiments

To combine more than two experiments, simply provide all experiment numbers:

```julia
# Add three experiments together
julia> cd("myexperiment")

julia> sumexpts(999, 11, 12, 13)
# Output shows all three experiments being combined
```

By default, all experiments are weighted equally. The result will be the sum of all input data.

### Creating difference spectra

To create a difference spectrum, use the `weights` parameter:

```julia
# Create a difference spectrum (experiment 12 subtracted from experiment 11)
julia> cd("myexperiment")

julia> sumexpts(999, 11, 12, weights=[1.0, -1.0])
=== NMR Experiment Summation ===
Output: 999
Inputs: 11, 12
Weights: 1.0, -1.0
Created output experiment from 11
Data format: Float64 (little-endian)
Detected nD experiment, using ser files
Cleaning processed data files in pdata/1...
  Removed: 2rr
Loading 11/ser
Loading 12/ser
Applied weight 1.0 to experiment 11
Applied weight -1.0 to experiment 12
Writing output to 999/ser
Scans from 11: 16 × 1.0 = 16.0
Scans from 12: 16 × 1.0 = 16.0
Updated number of scans to 32
Updated title file with experiment summary
=== Operation completed successfully ===
```

This is particularly useful for applications like:
- Reaction monitoring
- Comparing before/after spectra
- Highlighting changes between samples
- Removing background signals

### Weighted combinations

You can apply different weights to each experiment to create weighted averages or to emphasize certain spectra:

```julia
# Weighted combination of three experiments
julia> cd("myexperiment")

julia> sumexpts(999, 11, 12, 13, weights=[0.5, 1.0, 2.0])
=== NMR Experiment Summation ===
Output: 999
Inputs: 11, 12, 13
Weights: 0.5, 1.0, 2.0
Created output experiment from 11
Data format: Float64 (little-endian)
Detected nD experiment, using ser files
Cleaning processed data files in pdata/1...
Loading 11/ser
Loading 12/ser
Loading 13/ser
Applied weight 0.5 to experiment 11
Applied weight 1.0 to experiment 12
Applied weight 2.0 to experiment 13
Writing output to 999/ser
Scans from 11: 8 × 0.5 = 4.0
Scans from 12: 16 × 1.0 = 16.0
Scans from 13: 32 × 2.0 = 64.0
Updated number of scans to 84
Updated title file with experiment summary
=== Operation completed successfully ===
```

The weights vector must have the same length as the number of input experiments.

### Experimental details

The function handles several important details automatically:

- The number of scans (`NS` parameter) in the output is updated to the weighted sum of input scan counts
- The title file is updated to indicate which experiments were combined and their weights
- Processed data files in `pdata/1` are removed to prevent inconsistencies
- If experiments have different data sizes, they are truncated to match the smallest dataset

### Command-line usage

The function can also be called from the command line:

```bash
cd myexperiment
julia -e 'using NMRTools; sumexpts(999, 11, 12)'
```

Or for creating a difference spectrum:

```bash
cd myexperiment
julia -e 'using NMRTools; sumexpts(999, 11, 12, weights=[1.0, -1.0])'
```

This allows for easy integration with processing workflows and shell scripts.