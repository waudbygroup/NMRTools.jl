# default constructor: dictionary of Symbol => Any #################################################

# struct NMRMetadata <: DimensionalData.Dimensions.LookupArrays.AbstractMetadata
# Metadata() = Metadata(Dict{Symbol,Any}())

# getters ##########################################################################################

# metadata accessor functions
"""
    metadata(nmrdata, key)
    metadata(nmrdata, dim, key)
    metadata(nmrdimension, key)

Return the metadata for specified key, or `nothing` if not found. Keys are passed as symbols.

# Examples (spectrum metadata)
- `:ns`: number of scans
- `:ds`: number of dummy scans
- `:rg`: receiver gain
- `:ndim`: number of dimensions
- `:title`: spectrum title (contents of title pdata file)
- `:filename`: spectrum filename
- `:pulseprogram`: title of pulse program used for acquisition
- `:experimentfolder`: path to experiment
- `:noise`: RMS noise level

# Examples (dimension metadata)
- `:pseudodim`: flag indicating non-frequency domain data
- `:npoints`: final number of (real) data points in dimension (after extraction)
- `:td`: number of complex points acquired
- `:tdzf`: number of complex points when FT executed, including LP and ZF
- `:bf`: base frequency, in MHz
- `:sf`: carrier frequency, in MHz
- `:offsethz`: carrier offset from bf, in Hz
- `:offsetppm`: carrier offset from bf, in ppm
- `:swhz`: spectrum width, in Hz
- `:swppm`: spectrum width, in ppm
- `:region`: extracted region, expressed as a range in points, otherwise missing
- `:window`: `WindowFunction` indicating applied apodization

See also [`estimatenoise!`](@ref).
"""
function metadata end

metadata(A::AbstractNMRData, key::Symbol) = get(metadata(A), key, nothing)
metadata(A::AbstractNMRData, dim, key::Symbol) = get(metadata(A, dim), key, nothing)
metadata(d::NMRDimension, key::Symbol) = get(metadata(d), key, nothing)

Base.getindex(A::AbstractNMRData, key::Symbol) = metadata(A, key)
Base.getindex(A::AbstractNMRData, dim, key::Symbol) = metadata(A, dim, key)
Base.getindex(d::NMRDimension, key::Symbol) = metadata(d, key)
Base.setindex!(A::AbstractNMRData, v, key::Symbol) = setindex!(metadata(A), v, key)  #(A[key] = v  =>  metadata(A)[key] = v)
function Base.setindex!(A::AbstractNMRData, v, dim, key::Symbol)
    return setindex!(metadata(A, dim), v, key)
end  #(A[dim, key] = v  =>  metadata(A, dim)[key] = v)
Base.setindex!(d::NMRDimension, v, key::Symbol) = setindex!(metadata(d), v, key)  #(d[key] = v  =>  metadata(d)[key] = v)

"""
    units(nmrdata)
    units(nmrdata, dim)
    units(nmrdimension)

Return the physical units associated with an `NMRData` structure or an `NMRDimension`.
"""
function units end
units(A::AbstractNMRData) = metadata(A, :units)
units(A::AbstractNMRData, dim) = metadata(A, dim, :units)
units(d::NMRDimension) = get(metadata(d), :units, nothing)

"""
    label(nmrdata)
    label(nmrdata, dim)
    label(nmrdimension)

Return a short label associated with an `NMRData` structure or an `NMRDimension`.
By default, for a spectrum this is obtained from the first line of the title file.
For a frequency dimension, this is normally something of the form `1H chemical shift (ppm)`.

See also [`label!`](@ref).
"""
function label end
label(A::AbstractNMRData) = metadata(A, :label)
label(A::AbstractNMRData, dim) = metadata(A, dim, :label)
label(d::NMRDimension) = get(metadata(d), :label, nothing)

"""
    label!(nmrdata, labeltext)
    label!(nmrdata, dim, labeltext)
    label!(nmrdimension, labeltext)

Set the label associated with an `NMRData` structure or an `NMRDimension`.

See also [`label`](@ref).
"""
function label! end
label!(A::AbstractNMRData, labeltext::AbstractString) = (A[:label] = labeltext)
label!(A::AbstractNMRData, dim, labeltext::AbstractString) = (A[dim, :label] = labeltext)
label!(d::NMRDimension, labeltext::AbstractString) = (d[:label] = labeltext)

"""
    acqus(nmrdata)
    acqus(nmrdata, key)
    acqus(nmrdata, key, index)

Return data from a Bruker acqus file, or `nothing` if it does not exist.
Keys can be passed as symbols or strings. If no key is specified, a dictionary
is returned representing the entire acqus file.

If present, the contents of auxilliary files such as `vclist` and `vdlist` can
be accessed using this function.

# Examples
```julia-repl
julia> acqus(expt, :pulprog)
"zgesgp"
julia> acqus(expt, "TE")
276.9988
julia> acqus(expt, :p, 1)
9.2
julia> acqus(expt, "D", 1)
0.1
julia> acqus(expt, :vclist)
11-element Vector{Int64}:
[...]
```

See also [`metadata`](@ref).
"""
acqus(A::AbstractNMRData) = metadata(A, :acqus)
function acqus(A::AbstractNMRData, key::Symbol)
    return ismissing(acqus(A)) ? missing : get(acqus(A), key, missing)
end
acqus(A::AbstractNMRData, key::String) = acqus(A, Symbol(lowercase(key)))
acqus(A::AbstractNMRData, key, index) = acqus(A, key)[index]

# # Metadata for NMRData #############################################################################

function defaultmetadata(::Type{<:AbstractNMRData})
    defaults = Dict{Symbol,Any}(:title => "",
                                :label => "",
                                :filename => nothing,
                                :format => nothing,
                                :lastserialised => nothing,
                                :pulseprogram => nothing,
                                :ns => nothing,
                                :rg => nothing,
                                :noise => nothing)

    return Metadata{NMRData}(defaults)
end

# Metadata for Dimensions ##########################################################################

function defaultmetadata(T::Type{<:NMRDimension})
    defaults = Dict{Symbol,Any}(:label => "",
                                :units => nothing)
    return Metadata{T}(defaults)
end

function defaultmetadata(::Type{<:FrequencyDimension})
    defaults = Dict{Symbol,Any}(:label => "",
                                :coherence => nothing,
                                :bf => nothing,
                                :offsethz => nothing,
                                :offsetppm => nothing,
                                :swhz => nothing,
                                :swppm => nothing,
                                :td => nothing,
                                :tdzf => nothing,
                                :npoints => nothing,
                                :region => nothing,
                                :units => nothing,
                                :window => nothing,
                                :mcindex => nothing)
    return Metadata{FrequencyDimension}(defaults)
end

function defaultmetadata(::Type{<:TimeDimension})
    defaults = Dict{Symbol,Any}(:label => "",
                                :units => nothing,
                                :window => nothing,
                                :mcindex => nothing)
    return Metadata{TimeDimension}(defaults)
end

function defaultmetadata(::Type{<:TrelaxDim})
    defaults = Dict{Symbol,Any}(:label => "Relaxation time",
                                :units => nothing)
    return Metadata{TrelaxDim}(defaults)
end

function defaultmetadata(::Type{<:TkinDim})
    defaults = Dict{Symbol,Any}(:label => "Time elapsed",
                                :units => nothing)
    return Metadata{TkinDim}(defaults)
end

function defaultmetadata(::Type{<:UnknownDimension})
    defaults = Dict{Symbol,Any}(:label => "",
                                :units => nothing)
    return Metadata{UnknownDimension}(defaults)
end

# Metadata entry definitions and help ##############################################################
function metadatahelp(A::Type{T}) where {T<:Union{NMRData,NMRDimension}}
    m = Metadata{A}()
    return Dict(map(kv -> kv[1] => metadatahelp(kv[1]), m))
end

function metadatahelp(key::Symbol)
    return get(metadatahelp(), key, "No information is available on this entry.")
end

function metadatahelp()
    d = Dict(:title => "Experiment title (may be multi-line)",
             :label => "Short experiment or axis description",
             :filename => "Original filename or template",
             :format => ":NMRPipe or :pdata",
             :pulseprogram => "Pulse program (PULPROG) from acqus file",
             :ns => "Number of scans",
             :rg => "Receiver gain",
             :noise => "RMS noise level",
             :units => "Axis units",
             :window => "Window function",
             :mcindex => "Index of imaginary component associated with axis (for multicomplex data)")
    return d
end