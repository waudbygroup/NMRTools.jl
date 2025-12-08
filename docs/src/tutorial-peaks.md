# Peak Detection

NMRTools provides automated peak detection for 1D NMR spectra, allowing you to identify and analyze resonances in your data. The peak detection algorithm uses signal-to-noise ratio (SNR) filtering to distinguish true peaks from background noise.

## Quick Example

```@example peaks
using NMRTools, Plots # hide
spec = exampledata("1D_19F")
pks = detectpeaks(spec)
```

The `detectpeaks` function returns a vector of `SimplePeak` objects with information about each detected peak:

To visualize the detected peaks, simply plot them alongside the spectrum:

```@example peaks
plot(spec)
plot!(pks)
savefig("peak-detection-example.svg"); nothing # hide
```

![](peak-detection-example.svg)

Detected peaks are shown as a red vertical line overlaid on the spectrum.

## Basic Usage

The `detectpeaks` function analyzes a 1D NMR spectrum and returns a vector of `SimplePeak` objects:

```julia
peaks = detectpeaks(spec)
```

Each `SimplePeak` object contains three key properties:

- **`intensity`**: The peak height (amplitude) in the spectrum
- **`δ`**: The chemical shift position in ppm
- **`δfwhm`**: The full width at half maximum (FWHM) in ppm

## Adjusting Peak Detection Sensitivity

The `snr_threshold` parameter controls the sensitivity of peak detection by setting the minimum signal-to-noise ratio required for a peak to be detected:

```julia
# Detect only very strong peaks (SNR > 20)
peaks_strong = detectpeaks(spec; snr_threshold=20)

# More sensitive detection (SNR > 5)
peaks_sensitive = detectpeaks(spec; snr_threshold=5)
```

## Accessing Individual Peak Properties

You can access properties of individual peaks:

```julia
julia> peak = peaks[1]
SimplePeak{1} with intensity=23737.674377441406, δ=-123.69808278240923, δfwhm=0.0626986378531874

julia> peak.δ
-123.69808278240923

julia> peak.intensity
23737.674377441406

julia> peak.δfwhm
0.0626986378531874
```


## Sorting Peaks

You can sort peaks by various properties:

```julia
# Sort by intensity (strongest first)
sorted_by_intensity = sort(peaks; by=p -> p.intensity, rev=true)

# Sort by chemical shift (left to right)
sorted_by_shift = sort(peaks; by=p -> p.δ, rev=true)
```

## See Also

- [Plotting Tutorial](tutorial-plotrecipes.md): Learn more about visualizing NMR data
- [Working with NMR Data](tutorial-data.md): Data processing and manipulation
- [Utilities](utilities.md): Additional analysis tools
