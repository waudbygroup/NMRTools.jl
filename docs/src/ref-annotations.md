# NMR Pulse Programme Semantic Annotation System

!!! warning "Alpha Development Status"
    This annotation system is in early alpha development. The schema, syntax, and functionality are subject to significant changes. Use with caution in production environments.

## Motivation

Modern NMR pulse programmes are cryptic text files that encode complex experimental procedures, but they lack semantic information about what they actually measure. Analysis software must guess at the meaning of parameters like `VALIST` or `VPLIST`, leading to errors and requiring manual interpretation.

This annotation system embeds structured semantic metadata directly within pulse programme files as comments, enabling:

- **Automated Analysis**: Software can automatically understand experimental structure
- **Reproducible Research**: Clear provenance and citation information
- **Knowledge Preservation**: Experimental design captured alongside implementation
- **Cross-Platform Compatibility**: Vendor-agnostic semantic layer
- **Collaborative Development**: Track contributors and development status

!!! note "Current Implementation"
    Basic annotation parsing is implemented in NMRTools.jl. The system is under active development with ongoing refinement of the schema and parsing capabilities.

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

## Using Annotations in NMRTools.jl

The complete annotation schema is defined at https://waudbylab.org/pulseprograms/schema/fields/. In NMRTools.jl, parsed annotation data is accessible via the `:annotations` metadata field.

### Accessing annotation data

```julia
# Load a spectrum with annotations
spec = loadnmr("path/to/annotated/experiment")

# Access all annotations
annotations = spec[:annotations]

# Access specific annotation fields
experiment_type = annotations["experiment_type"]
```

### Example: 19F R1ρ on-resonance experiment

This example experiment is annotated as follows:

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

Using the test data `19F-r1rho-onres`, we can parse these annotations:

```julia
using NMRTools

# Load the annotated experiment
spec = loadnmr("test/test-data/19F-r1rho-onres")

# View all available annotations
spec[:annotations]

# Access experiment metadata
spec[:annotations]["title"]           # "19F on-resonance R1rho relaxation dispersion"
spec[:annotations]["experiment_type"] # ["r1rho", "1d"]
spec[:annotations]["features"]        # ["relaxation dispersion", "on-resonance", "temperature compensation"]

# Access spinlock parameters with parsed variable lists
spinlock = spec[:annotations]["spinlock"]
spinlock["power"]     # list of powers, [Power(36.82 dB, 0.0002079696687103696 W), ...]
spinlock["duration"]  # list of duratinos, [0.00001, 0.005, 0.01, ...]
spinlock["channel"]   # "19F"
spinlock["offset"]    # 0 (on-resonance)
```
