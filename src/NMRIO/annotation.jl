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

    # Resolve programmatic list patterns
    resolve_programmatic_lists!(annotations, spec)

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

"""
    resolve_programmatic_lists!(annotations::Dict{String, Any}, spec::NMRData)

Resolve programmatic list patterns in annotations to actual vectors.

Programmatic lists are specified as dictionaries with one of two patterns:

**Pattern 1: Type-based (linear/log)**
- `type`: "linear" or "log" (logarithmic)
- `start`: starting value
- `step`: step size (for linear with start/step)
- `end`: ending value (for linear or log with start/end)

**Pattern 2: Counter-based**
- `counter`: array of values (typically integers from a loop counter)
- `scale`: scale factor to multiply each counter element by

For type-based patterns, the function:
1. Identifies fields containing programmatic list patterns ({type, start, step/end})
2. Finds the dimension number for that field from the dimensions annotation
3. Gets the number of points in that dimension
4. Replaces the pattern with a correctly sized vector

For counter-based patterns, the function:
1. Multiplies each element of the counter array by the scale value
2. Returns the resulting vector

# Examples
```julia
# Linear spacing with start/step
# {type: linear, start: p9, step: p9} with 10 points → [p9, 2*p9, 3*p9, ...]

# Linear spacing with start/end
# {type: linear, start: 0.001, end: 0.1} with 10 points → [0.001, 0.012, ..., 0.1]

# Logarithmic spacing with start/end
# {type: log, start: 0.001, end: 0.1} with 10 points → [0.001, 0.0016, ..., 0.1]

# Counter-based pattern
# {counter: [0, 1, 2, 3], scale: 0.01} → [0.0, 0.01, 0.02, 0.03]
```
"""
function resolve_programmatic_lists!(annotations::Dict, spec::NMRData)
    # Get dimensions array to map field names to dimension numbers
    dimensions = get(annotations, "dimensions", nothing)
    if isnothing(dimensions)
        return annotations
    end

    # Find all programmatic list patterns and resolve them
    _resolve_programmatic_recursive!(annotations, annotations, spec, dimensions)
    return annotations
end

"""
    _resolve_programmatic_recursive!(obj, root_annotations, spec, dimensions)

Recursively traverse annotations to find and resolve programmatic list patterns.
"""
function _resolve_programmatic_recursive!(obj::Dict, root_annotations::Dict, spec::NMRData, dimensions::Vector)
    for (key, value) in obj
        if _is_programmatic_pattern(value)
            # This is a programmatic list pattern - resolve it
            resolved = _resolve_programmatic_pattern(key, value, root_annotations, spec, dimensions)
            if !isnothing(resolved)
                obj[key] = resolved
            end
        else
            # Recursively process nested structures
            _resolve_programmatic_recursive!(value, root_annotations, spec, dimensions)
        end
    end
    return obj
end

function _resolve_programmatic_recursive!(obj::Vector, root_annotations::Dict, spec::NMRData, dimensions::Vector)
    # Don't process vectors themselves, only their elements if they're dicts
    for i in eachindex(obj)
        if obj[i] isa Dict
            _resolve_programmatic_recursive!(obj[i], root_annotations, spec, dimensions)
        end
    end
    return obj
end

function _resolve_programmatic_recursive!(obj, root_annotations::Dict, spec::NMRData, dimensions::Vector)
    # For any other type, return as-is
    return obj
end

"""
    _is_programmatic_pattern(value) -> Bool

Check if a value is a programmatic list pattern.
Must be a Dict with either:
- "type" key and either "step" or "end" key (linear/log patterns)
- "counter" and "scale" keys (counter-based pattern)
"""
function _is_programmatic_pattern(value)
    if !(value isa Dict)
        return false
    end

    # Pattern 1: type-based (linear/log) - must have "type" and either "step" or "end"
    has_type = haskey(value, "type")
    has_step_or_end = haskey(value, "step") || haskey(value, "end")
    is_type_pattern = has_type && has_step_or_end

    # Pattern 2: counter-based - must have both "counter" and "scale"
    has_counter = haskey(value, "counter")
    has_scale = haskey(value, "scale")
    is_counter_pattern = has_counter && has_scale

    return is_type_pattern || is_counter_pattern
end

"""
    _resolve_programmatic_pattern(key, pattern, root_annotations, spec, dimensions)

Resolve a single programmatic list pattern to a vector.
"""
function _resolve_programmatic_pattern(key::String, pattern::Dict, root_annotations::Dict, spec::NMRData, dimensions::Vector)
    # Check if this is a counter-based pattern
    if haskey(pattern, "counter") && haskey(pattern, "scale")
        counter = get(pattern, "counter", nothing)
        scale = get(pattern, "scale", nothing)

        if isnothing(counter)
            @warn "Counter-based pattern missing 'counter' value for: $key"
            return nothing
        end

        if isnothing(scale)
            @warn "Counter-based pattern missing 'scale' value for: $key"
            return nothing
        end

        # Counter must be a vector or array
        if !(counter isa AbstractVector)
            @warn "Counter-based pattern 'counter' must be an array for: $key"
            return nothing
        end

        # Generate list by multiplying each counter element by scale
        return [c * scale for c in counter]
    end

    # Otherwise, handle type-based patterns (linear/log)
    # Find which dimension this key corresponds to
    dim_path = _find_dimension_path(key, root_annotations)
    if isnothing(dim_path)
        @warn "Could not find dimension path for programmatic list key: $key"
        return nothing
    end

    # Find dimension number in the dimensions array
    dim_index = findfirst(==(dim_path), dimensions)
    if isnothing(dim_index)
        @warn "Could not find dimension for programmatic list: $dim_path not in dimensions array"
        return nothing
    end

    # Get number of points in this dimension (before reversal)
    npoints = size(spec, length(dimensions) - dim_index + 1)

    # Get pattern parameters
    pattern_type = get(pattern, "type", "linear")
    start_val = get(pattern, "start", nothing)
    step_val = get(pattern, "step", nothing)
    end_val = get(pattern, "end", nothing)

    if isnothing(start_val)
        @warn "Programmatic list pattern missing 'start' value for: $key"
        return nothing
    end

    # Generate the list based on pattern type
    if pattern_type == "linear"
        if !isnothing(step_val)
            # Linear with start/step
            return [start_val + (i - 1) * step_val for i in 1:npoints]
        elseif !isnothing(end_val)
            # Linear with start/end
            return collect(range(start_val, end_val, length=npoints))
        else
            @warn "Programmatic list pattern must have either 'step' or 'end': $key"
            return nothing
        end
    elseif pattern_type == "log"
        if !isnothing(end_val)
            # Logarithmic spacing
            return exp.(range(log(start_val), log(end_val), length=npoints))
        else
            @warn "Logarithmic programmatic list pattern requires 'end' value: $key"
            return nothing
        end
    else
        @warn "Unknown programmatic list type: $pattern_type (expected 'linear' or 'log')"
        return nothing
    end
end

"""
    _find_dimension_path(key, annotations, prefix="")

Find the dotted path to a key in the annotations dictionary.
Returns the path that should match entries in the dimensions array.
"""
function _find_dimension_path(key::String, annotations::Dict, prefix::String="")
    # Check if this key exists at the current level
    if haskey(annotations, key)
        return isempty(prefix) ? key : "$prefix.$key"
    end

    # Recursively search in nested dictionaries
    for (k, v) in annotations
        if v isa Dict && k != "dimensions"  # Don't search in dimensions array itself
            new_prefix = isempty(prefix) ? k : "$prefix.$k"
            result = _find_dimension_path(key, v, new_prefix)
            if !isnothing(result)
                return result
            end
        end
    end

    return nothing
end