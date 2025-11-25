"""
    NMR Pulse Programme Annotation Parser for NMRTools.jl
    
    Parses semantic annotations from NMR pulse programme strings into structured dictionaries.
    Supports schema ≥ v0.0.2.
"""

function annotate!(spec::NMRData)
    pp = pulseprogram(spec)
    if isnothing(pp) || ismissing(pp) || length(pp) == 0
        return nothing
    end
    annotations = parse_annotations(pp)

    # Check schema version
    schema_version = get(annotations, "schema_version", nothing)
    if isnothing(schema_version)
        return nothing
    elseif schema_version != "0.0.2"
        @warn "Pulse programme uses unsupported schema version $schema_version. Only v0.0.2 is currently supported. Annotations may not parse correctly."
        return nothing
    end

    # Resolve parameter references to actual values
    resolve_parameter_references!(annotations, spec)

    # Reverse dimensions to match data order
    if haskey(annotations, "dimensions")
        annotations["dimensions"] = reverse(annotations["dimensions"])
    end

    return spec[:annotations] = annotations
end

"""
    parse_annotations(content::String) -> Dict{String, Any}

Parse pulse programme annotations from content string. Annotations are embedded 
within pulse programme comments marked with `;@ ` at the start of lines.

The function:
1. Filters out lines starting with `;@ `
2. Strips the `;@ ` prefix from each line
3. Parses the resulting YAML document into a dictionary
"""
function parse_annotations(content::String)::Dict{String,Any}
    # Filter lines starting with ";@ " and strip the prefix
    annotation_lines = String[]

    for line in split(content, '\n')
        if startswith(line, ";@ ")
            # Strip the ";@ " prefix (4 characters)
            stripped_line = line[4:end]
            push!(annotation_lines, stripped_line)
        end
    end

    # If no annotation lines found, return empty dictionary
    if isempty(annotation_lines)
        return Dict{String,Any}()
    end

    # Join lines back into YAML content
    yaml_content = join(annotation_lines, '\n')

    # Parse YAML content
    try
        return YAML.load(yaml_content)
    catch e
        @warn "Failed to parse pulse programme annotations as YAML: $e"
        return Dict{String,Any}()
    end
end

"""
    resolve_parameter_references!(annotations::Dict{String, Any}, spec::NMRData)

Recursively traverse the annotations dictionary and resolve parameter references.
References are bare parameter names like p1, pl1, d20, VALIST, etc.

Parameters are resolved using the acqus() function to get values from the acqus file.

# Arguments
- `annotations::Dict{String, Any}`: Annotations dictionary to modify in-place
- `spec::NMRData`: NMRData object containing acqus metadata

# Examples
```julia
# Before resolution: {"pulse": "p1", "power": "pl1", "duration": "VDLIST"}
# After resolution: {"pulse": 9.2, "power": Power(...), "duration": [0.01, 0.02, ...]}
```
"""
function resolve_parameter_references!(annotations::Dict, spec::NMRData)
    _resolve_recursive!(annotations, spec)
    return annotations
end

function _resolve_recursive!(obj::Dict, spec::NMRData)
    for (key, value) in obj
        obj[key] = _resolve_recursive!(value, spec)
    end
    return obj
end

function _resolve_recursive!(obj::Vector, spec::NMRData)
    for i in eachindex(obj)
        obj[i] = _resolve_recursive!(obj[i], spec)
    end
    return obj
end

function _resolve_recursive!(obj::String, spec::NMRData)
    # Check if this string matches a parameter pattern
    resolved_value = _resolve_parameter(obj, spec)
    return isnothing(resolved_value) ? obj : resolved_value
end

function _resolve_recursive!(obj, spec::NMRData)
    # For any other type (numbers, booleans, etc.), return as-is
    return obj
end

"""
    _resolve_parameter(param_str::String, spec::NMRData) -> Union{Nothing, Any}

Attempt to resolve a parameter string using the acqus data.
Returns the resolved value or nothing if not a recognized parameter.

Handles parameter patterns (case-insensitive):
- Indexed parameters: p1, pl1, d20, cnst8, gpz6, etc.
- Nucleus assignments: f1, f2, f3, f4
- Any other parameter names that exist in acqus (including lists)
"""
function _resolve_parameter(param_str::String, spec::NMRData)
    param = strip(param_str)

    # Nucleus assignments: f1 => nuc1, f2 => nuc2, etc.
    m = match(r"^f(\d+)$", param)
    if !isnothing(m)
        index = parse(Int, m.captures[1])
        nuc = acqus(spec, Symbol("nuc$index"))
        # return nucleus(nuc) # causes bugs when trying to replace a string with a Nucleus type
        return nuc
    end

    # Define indexed parameter types (strings map to symbols in acqus)
    indexed_params = ["p", "pl", "sp", "spnam", "d", "cnst", "gpnam", "gpx", "gpy", "gpz"]

    # Try to match indexed parameters
    for prefix in indexed_params
        m = match(Regex("^$(prefix)(\\d+)\$"), param)
        isnothing(m) && continue

        index = parse(Int, m.captures[1])
        symbol = Symbol(prefix)
        return acqus(spec, symbol, index)
    end

    # Check if this parameter exists directly in acqus (handles lists and other parameters)
    # Convert to symbol for acqus lookup
    param_symbol = Symbol(param)
    direct_value = acqus(spec, param_symbol)

    if !isnothing(direct_value) && !ismissing(direct_value)
        return direct_value
    end

    # No match found - return nothing to keep original string
    return nothing
end