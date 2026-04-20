# Times and frequencies

For maximum consistency, in NMRTools **all time and frequency data are stored as seconds and Hz**. This includes:

- pulse lengths
- delays
- vdlists and vplists
- spectrometer frequencies (bf, sf)

## Examples

```@example 1
using NMRTools # hide
spec = exampledata("2D_HN") # hide
@info "Pulse length p1, in s" acqus(spec, :p, 1)
```

```@example 1
@info "Delay d1, in s" acqus(spec, :d, 1)
```

```@example 1
@info "Base frequency for channel 1, in Hz" spec[1, :bf]
```