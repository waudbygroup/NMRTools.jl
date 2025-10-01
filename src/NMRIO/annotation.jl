"""
    NMR Pulse Programme Annotation Parser for NMRTools.jl
    
    Parses semantic annotations from NMR pulse programme strings into structured dictionaries.
"""

function annotate!(spec::NMRData)
    pp = pulseprogram(spec)
    if isnothing(pp) || ismissing(pp) || length(pp) == 0
        return nothing
    end
    annotations = parse_annotations(pp)
    resolve_parameter_references!(annotations, spec)
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
References are strings matching Bruker parameter patterns like:
- p1, p2, p3, ... (pulse lengths)
- pl1, pl2, pl3, ... (pulse powers)  
- d1, d18, ... (delays)

Parameters are resolved using the acqus() function to get values from the acqus file.

# Arguments
- `annotations::Dict{String, Any}`: Annotations dictionary to modify in-place
- `spec::NMRData`: NMRData object containing acqus metadata

# Examples
```julia
# Before resolution: {"length": "p1", "power": "pl1"}
# After resolution: {"length": 9.2, "power": -3.0}
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

Handles parameter patterns:
- p1, p2, p3, ... -> acqus(spec, :p, 1), acqus(spec, :p, 2), ...
- pl1, pl2, pl3, ... -> acqus(spec, :pl, 1), acqus(spec, :pl, 2), ...
- d1, d18, ... -> acqus(spec, :d, 1), acqus(spec, :d, 18), ...
- cnst1, cnst2, ... -> acqus(spec, :cnst, 1), acqus(spec, :cnst, 2), ...
"""
function _resolve_parameter(param_str::String, spec::NMRData)
    # Convert to lowercase for case-insensitive matching
    param_lower = lowercase(strip(param_str))

    # patterns to match:
    patterns = [r"^p(\d+)$" => :p,              # p
                r"^pl(\d+)$" => :plw,           # pl
                r"^spnam(\d+)$" => :spnam,      # d
                r"^cnst(\d+)$" => :cnst,        # spnam
                r"^sp(\d+)$" => :spw,           # sp
                r"^d(\d+)$" => :d,              # cnst
                r"^gpnam(\d+)$" => :gpnam,      # gpnam
                r"^gpx(\d+)$" => :gpx,          # gpx
                r"^gpy(\d+)$" => :gpy,          # gpy
                r"^gpz(\d+)$" => :gpz]

    for (pattern, type) in patterns
        m = match(pattern, param_lower)
        if !isnothing(m)
            index = parse(Int, m.captures[1])
            return acqus(spec, type, index)
        end
    end

    # nuclei: f1 => :nuc1, f2 => :nuc2, etc.
    m = match(r"^f(\d+)$", param_lower)
    if !isnothing(m)
        index = parse(Int, m.captures[1])
        return acqus(spec, Symbol("nuc$index"))
    end

    # match lists (e.g. '<$FQ1LIST>')
    patterns = [r"^<\$fq1list>$" => :fq1list,
                r"^<\$fq2list>$" => :fq2list,
                r"^<\$fq3list>$" => :fq3list,
                r"^<\$fq4list>$" => :fq4list,
                r"^<\$fq5list>$" => :fq5list,
                r"^<\$fq6list>$" => :fq6list,
                r"^<\$fq7list>$" => :fq7list,
                r"^<\$fq8list>$" => :fq8list,
                r"^<\$vclist>$" => :vclist,
                r"^<\$vdlist>$" => :vdlist,
                r"^<\$valist>$" => :valist,
                r"^<\$vplist>$" => :vplist]
    for (pattern, type) in patterns
        m = match(pattern, param_lower)
        if !isnothing(m)
            return acqus(spec, type)
        end
    end

    # No match found
    return nothing
end

# Example usage and testing
"""
    test_parser()
    
Test the annotation parser with example pulse programme content.
"""
function test_parser()
    # Example pulse programme content with updated syntax
    test_content = """
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
    """

    println("Parsing test pulse programme...")
    annotations = parse_annotations(test_content)

    # Display results
    for (key, value) in annotations
        println("$key: $value")
    end

    return annotations
end
