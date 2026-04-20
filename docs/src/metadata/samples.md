# Sample metadata

Sample metadata can be automatically loaded when present, following the schema defined at [nmr-sample-schema](https://github.com/waudbygroup/nmr-sample-schema). This provides structured information about the physical sample, buffer composition, NMR tube characteristics, and personnel involved in the experiment.

Sample metadata is stored as JSON files in the experiment directory and is automatically associated with spectra based on timestamps:

```julia
# Load spectrum - sample metadata loaded automatically if present
spec = loadnmr("path/to/experiment")

# Check if sample metadata is available
hassample(spec)
```

The [`hassample`](@ref) function returns `true` if sample metadata has been successfully loaded and is non-empty.

## Accessing sample metadata

Use the [`sample`](@ref) function to access sample metadata:

```julia
# Get all sample metadata
sample(spec)
```

This returns a dictionary with the complete sample metadata structure, for example:

```julia
Dict{String, Any} with 6 entries:
  "nmr_tube" => Dict{String, Any}("diameter"=>"5 mm", "type"=>"regular", "sample_volume_uL"=>600)
  "buffer"   => Dict{String, Any}("solvent"=>"10% D2O", "reference_unit"=>"%w/v", "chemical_shift_reference"=>"none")
  "notes"    => "here's a note!"
  "metadata" => Dict{String, Any}("created_timestamp"=>"2023-10-10T11:35:00.000Z", "modified_timestamp"=>"2025-11-03T09:13:19.030Z", "schema_version"=>"0.0.3", "ejected_timestamp"=>"2023-10-11T09:30:00.000Z")
  "sample"   => Dict{String, Any}("label"=>"lysozyme (1mM Gd)", "components"=>Any[Dict{String, Any}("name"=>"HEWL", "isotopic_labelling"=>"unlabelled", "unit"=>"mM", "concentration"=>10), Dict{String, Any}("name"=>"gadodiamide", "isotopic_labelling"=>"unlabelled", "unit"=>"mM", "concentration"=>1)])
  "people"   => Dict{String, Any}("groups"=>Any["Waudby"], "users"=>Any["Chris"])
```

## Navigating nested metadata

The [`sample`](@ref) function accepts additional keys to navigate nested dictionaries. Keys can be provided as strings or symbols and are case-insensitive:

```julia
# Get sample label
sample(spec, :sample, :label)

# Get user names
sample(spec, "people", "users")

# Get buffer solvent
sample(spec, :buffer, :solvent)

# Get component concentrations
sample(spec, "sample", "components")
```

If a requested key is not found at any level, the function returns `nothing`.

## Schema structure

The sample metadata follows a hierarchical structure with the following main sections:

- **sample**: Sample identification and component list
  - `label`: Descriptive label for the sample
  - `components`: Array of sample components
    - `name`, `isotopic_labelling`, `concentration`, `unit`
- **buffer**: Buffer composition
  - `solvent`: Solvent description (e.g., "10% D2O")
  - `chemical_shift_reference`: Reference compound used
  - `components`: Array of buffer components
    - `name`, `concentration`, `unit`
- **nmr_tube**: NMR tube specifications
  - `type`: Tube type (e.g., "regular", "Shigemi")
  - `diameter`: Tube diameter (e.g., "5 mm")
  - `sample_volume_uL`: Sample volume in microliters
- **people**: Personnel information
  - `users`: Array of user names
  - `groups`: Array of group names
- **metadata**: Schema and timestamp information
  - `schema_version`: Version of the schema used
  - `created_timestamp`: When the sample was created
  - `ejected_timestamp`: When the sample was removed from the spectrometer
  - `modified_timestamp`: When the sample metadata was last modified
- **notes**: Free-text notes about the sample

For the complete schema specification, see the [nmr-sample-schema repository](https://github.com/waudbygroup/nmr-sample-schema).

## Timestamp matching

Sample metadata files are matched to experiments based on timestamps:

1. The experiment acquisition date is read from the `acqus` file
2. Sample JSON files in the parent directory are scanned
3. A sample is matched if the acquisition date falls between the sample's `created_timestamp` and `ejected_timestamp`
4. If no `ejected_timestamp` is present, the sample is assumed to still be in the spectrometer

This automatic matching ensures that the correct sample information is associated with each experiment without manual intervention.