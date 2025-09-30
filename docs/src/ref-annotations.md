# NMR Pulse Programme Semantic Annotation System

!!! warning
    AI generated draft document

## Motivation

Modern NMR pulse programmes are cryptic text files that encode complex experimental procedures, but they lack semantic information about what they actually measure. Analysis software must guess at the meaning of parameters like `VALIST` or `VPLIST`, leading to errors and requiring manual interpretation.

This annotation system embeds structured semantic metadata directly within pulse programme files as comments, enabling:

- **Automated Analysis**: Software can automatically understand experimental structure
- **Reproducible Research**: Clear provenance and citation information  
- **Knowledge Preservation**: Experimental design captured alongside implementation
- **Cross-Platform Compatibility**: Vendor-agnostic semantic layer
- **Collaborative Development**: Track contributors and development status

## Design Principles

### Human and Machine Readable
Annotations use simple comment syntax that NMR spectroscopists can read naturally whilst being structured enough for automated parsing.

### Embedded and Immutable
Metadata travels with the pulse programme file and cannot drift out of sync with the code.

### Modular and Extensible
Experiments are described as combinations of core types and features, allowing new variations without redefining the entire taxonomy.

### Version Controlled
Both individual pulse programmes and the annotation system itself are versioned for reproducibility and compatibility.

## Annotation Syntax

### Basic Format

Annotations are extensions of Bruker comment lines, and are marked `;@ `.
Within these lines, annotations are written in YAML format. The initial `;@ ` will be
stripped when parsing, permitting multi-line entries.

```
;@ parameter: text value
;@ parameter1: 0.123
;@ parameter2: [list, of, items]
;@ parameter3: {associative: array, key:value}
;@ parameter4: |
;@   This is
;@   a multi-line
;@   entry.
```

**Angle brackets `<>`** within an entry should be interpreted as a reference
to auxiliary files (following TopSpin conventions).

## Core Annotation Dictionary

A draft annotation schema is detailed at https://waudbylab.org/pulseprograms/schema/current/.

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `schema_version` | string | Schema version | `"0.0.1"` |
| `sequence_version` | string | Sequence version (semantic) | `"1.2.0"` |
| `title` | string | Descriptive sequence name | `SOFAST-HMQC` |
| `authors` | array | List of contributors | `[Name <optional email>]` |
| `created` | string | Creation date (YYYY-MM-DD) | `"2024-01-15"` |
| `last_modified` | string | Last modification date | `"2024-08-17"` |
| `repository` | string | Repository identifier | `github.com/user/repo` |
| `status` | string | Development status | `experimental / beta / stable / deprecated` |

### Optional Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `experiment_type` | array | Experiment keywords | `[hsqc, 2d]` |
| `description` | string | Detailed description | `1H,15N SOFAST-HMQC...` |
| `features` | array | Technical features | `["trosy", "sofast"]` |
| `nuclei_hint` | array | Suggested mapping of nuclei to channels | `[1H, 15N]` |
| `citation` | array | Literature references | `[Author et al., Journal (Year)]` |
| `doi` | array | DOI identifiers | `[10.1021/ja051306e]` |


### Experiment types

**`experiment_type`** - Core experimental method(s)
```
;@ experiment_type: [r1rho, 1d]             # 1D R1rho
;@ experiment_type: [cest, 1d]              # 1D CEST  
;@ experiment_type: [hsqc, 2d]              # 2D HSQC
;@ experiment_type: [r1rho, hsqc, 2d]       # 2D R1rho-HSQC
```

**`features`** - Modular experimental enhancements
```
;@ features: [relaxation_dispersion, temperature_compensation]
;@ features: [gradient_purge, water_suppression]
;@ features: [presaturation]
```

### Nuclear Context

** `nuclei_hint`** - Suggested mapping of nuclei to spectrometer channels
```
;@ nuclei_hint: [19F, 1H]
;@ nuclei_hint: [1H, 13C, 15N]
```

**`observe_channel`** - Primary observed channel
```
;@ observe_channel: f1
```

!!! note
    Channels are linked to nuclei via the NUC1, NUC2 … NUC8 parameters in the acqus file
    e.g. `acqus(spec, :nuc1)` returns `"1H"`
    and `nucleus(acqus(spec, :nuc1))` gives the enumeration value `:H1`

### Dimensional Structure

**`dimensions`** - Physical meaning of each experiment dimension
```
;@ dimensions: [spinlock_strength, spinlock_time, f1]
;@ dimensions: [saturation_frequency, f1]
;@ dimensions: [f3, f1]                     # HSQC: 15N, 1H
```

**`acquisition_order`** - Order in which dimensions are acquired
```
;@ acquisition_order: [3, 1, 2]            # dim3 first, then dim1, then dim2
```

### Pulses and other parameters

**`hard_pulse`** - List of hard pulse parameters
```
;@ hard_pulse:
;@ - {channel: f1, length: p1, power: pl1}
;@ - {channel: f2, length: p3, power: pl2}
```

**`decoupling`** - What is decoupled during each dimension
```
;@ decoupling: [nothing, nothing, f2]       # Only during direct detection
;@ decoupling: [nothing, f3]                # During 2D evolution and detection
;@ decoupling: [[f1, f2], f3]               # Multiple channels during first dimension
```

**`decoupling_pulse`** - Array of pulses for decoupling
```
;@ decoupling_pulse:
;@ - {channel: f2, length: p4, power: pl12, program: cpdprg2}
```

**`spinlock`** - dictionary of spinlock parameters
```
;@ spinlock: {channel: f1, power: pl8, duration: d18, offset: <FQ1LIST>}
;@ spinlock: {channel: f1, power: <VALIST>, duration: <VPLIST>, offset: 0, alignment: hard_pulse}
```

## Complete Examples

### R1rho On-Resonance Relaxation Dispersion
```
;@ schema_version: "0.0.1"
;@ sequence_version: "0.1.0"
;@ title: 19F on-resonance R1rho relaxation dispersion
;@ authors:
;@   - Chris Waudby <c.waudby@ucl.ac.uk>
;@   - Jan Overbeck
;@ created: 2020-01-01
;@ last_modified: 2025-08-01
;@ repository: github.com/waudbygroup/pulseprograms
;@ status: beta
;@ experiment_type: [r1rho, 1d]
;@ features: [relaxation dispersion, on-resonance, temperature compensation]
;@ nuclei_hint: [19F, 1H]
;@ citation:
;@   - Overbeck (2020)
;@ dimensions: [spinlock_duration, spinlock_power, f1]
;@ acquisition_order: [3, 1, 2]
;@ decoupling: [nothing, nothing, f2]
;@ hard_pulse:
;@ - {channel: f1, length: p1, power: pl1}
;@ - {channel: f2, length: p3, power: pl2}
;@ decoupling_pulse:
;@ - {channel: f2, length: p4, power: pl12, program: cpdprg2}
;@ spinlock: {channel: f1, power: <VALIST>, duration: <VPLIST>, offset: 0, alignment: hard_pulse}
```

### 19F CEST Saturation Transfer
```
;@ schema_version: "0.0.1"
;@ sequence_version: "1.0.0"
;@ title: 19F CEST
;@ description: |
;@   1D 19F CEST measurement
;@
;@   - Saturation applied for duration d18 during recycle delay
;@   - Additional relaxation delay of d1 applied without saturation
;@ authors:
;@   - Chris Waudby <c.waudby@ucl.ac.uk>
;@ created: 2025-08-01
;@ last_modified: 2025-08-01
;@ repository: github.com/waudbygroup/pulseprograms
;@ status: beta
;@ experiment_type: [cest, 1d]
;@ nuclei_hint: [19F]
;@ dimensions: [spinlock_frequency, f1]
;@ acquisition_order: [2, 1]
;@ decoupling: [nothing, nothing]
;@ hard_pulse:
;@ - {channel: f1, length: p1, power: pl1}
;@ spinlock: {channel: f1, power: pl8, duration: d18, offset: <FQ1LIST>}
```

### SOFAST HMQC
```
;@ schema_version: "0.0.1"
;@ sequence_version: "1.0.0"
;@ title: SOFAST-HMQC
;@ description: 1H,15N SOFAST-HMQC for rapid or sensitive measurements
;@ authors:
;@   - Chris Waudby <c.waudby@ucl.ac.uk>
;@   - P. Schanda
;@ created: 2024-01-15
;@ last_modified: 2025-08-15
;@ repository: github.com/waudbygroup/pulseprograms
;@ status: stable
;@ experiment_type: [hmqc, 2d]
;@ features: [sofast, sensitivity enhancement, selective excitation, presaturation]
;@ citation:
;@   - Schanda & Brutscher, J. Am. Chem. Soc. (2005) 127, 8014
;@ doi:
;@   - 10.1021/ja051306e
;@ nuclei_hint: [1H, 13C, 15N]
;@ observe_channel: f1
;@ dimensions: [f3, f1]
;@ acquisition_order: [2, 1]
;@ decoupling: [[f1,f2], f3]
;@ hard_pulse:
;@ - {channel: f1, length: p1, power: pl1}
;@ - {channel: f2, length: p3, power: pl2}
;@ - {channel: f3, length: p21, power: pl3}
;@ decoupling_pulse: [{channel: f3, length: p62, power: pl26, program: cpdprg3}]
;@ recovery_time: d1

