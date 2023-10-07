"""
    AbstractNMRData <: DimensionalData.AbstractDimArray

Abstract supertype for objects that wrap an array of NMR data, and metadata about
its contents.

`AbstractNMRData`s inherit from [`AbstractDimArray`]($DDarraydocs)
from DimensionalData.jl. They can be indexed as regular Julia arrays or with
DimensionalData.jl [`Dimension`]($DDdimdocs)s.
"""
abstract type AbstractNMRData{T,N,D,A} <: AbstractDimArray{T,N,D,A} end

# Base methods #####################################################################################

function Base.:(==)(A::AbstractNMRData{T,N}, B::AbstractNMRData{T,N}) where {T,N}
    return size(A) == size(B) && all(A .== B)
end

Base.parent(A::AbstractNMRData) = A.data
# NOTE In the future, specialise for file-based data (see Rasters.jl/array.jl)
Base.Array(A::AbstractNMRData) = Array(parent(A))
Base.collect(A::AbstractNMRData) = collect(parent(A))
# TODO define similar() to inherit metadata appropriately

# Interface methods ################################################################################

"""
    missingval(x)

Returns the value representing missing data in the dataset.
"""
function missingval end
missingval(x) = missing
missingval(A::AbstractNMRData) = A.missingval

# DimensionalData methods ##########################################################################

# Rebuild types of AbstractNMRData
function DD.rebuild(X::A, data, dims::Tuple, refdims, name,
                    metadata=metadata(X), missingval=missingval(X)) where {A<:AbstractNMRData}
    # HACK use A.name.wrapper to return the type (i.e. constructor) stripped of parameters.
    # This may not be a stable feature. See discussions:
    # - https://discourse.julialang.org/t/get-generic-constructor-of-parametric-type/57189/5
    # - https://github.com/JuliaObjects/ConstructionBase.jl/blob/master/src/constructorof.md
    return (A.name.wrapper)(data, dims, refdims, name, metadata, missingval)
end

function DD.rebuild(A::AbstractNMRData;
                    data=parent(A), dims=dims(A), refdims=refdims(A), name=name(A),
                    metadata=metadata(A), missingval=missingval(A))
    return rebuild(A, data, dims, refdims, name, metadata, missingval)
end

# NOTE In the future, specialise for file-based data (see Rasters.jl/array.jl)
function DD.modify(f, A::AbstractNMRData)
    newdata = f(parent(A))
    size(newdata) == size(A) ||
        error("$f returns an array with size $(size(newdata)) when the original size was $(size(A))")
    return rebuild(A, newdata)
end

# function DD.DimTable(As::Tuple{<:AbstractNMRData,Vararg{<:AbstractNMRData}}...)
#     return DD.DimTable(DimStack(map(read, As...)))
# end

# Concrete implementation ##########################################################################

"""
    NMRData <: AbstractNMRData
    NMRData(A::AbstractArray{T,N}, dims; kw...)
    NMRData(A::AbstractNMRData; kw...)

A generic [`AbstractNMRData`](@ref) for NMR array data. It holds memory-backed arrays.

# Keywords

- `dims`: `Tuple` of `NMRDimension`s for the array.
- `name`: `Symbol` name for the array, which will also retreive named layers if `NMRData`
    is used on a multi-layered file like a NetCDF.
- `missingval`: value representing missing data, normally detected from the file. Set manually
    when you know the value is not specified or is incorrect. This will *not* change any
    values in the NMRData, it simply assigns which value is treated as missing. To replace all of
    the missing values in the NMRData, use [`replace_missing`](@ref).
- `metadata`: `ArrayMetadata` object for the array, or `NoMetadata()`.

# Internal Keywords

In some cases it is possible to set these keywords as well.

- `data`: can replace the data in an `AbstractNMRData`

- `refdims`: `Tuple of` position `Dimension`s the array was sliced from, defaulting to `()`.
"""
struct NMRData{T,N,D<:Tuple,R<:Tuple,A<:AbstractArray{T,N},Na,Me,Mi} <:
       AbstractNMRData{T,N,D,A}
    data::A
    dims::D
    refdims::R
    name::Na
    metadata::Me
    missingval::Mi
end

function NMRData(A::AbstractArray, dims::Tuple;
                 refdims=(), name=Symbol(""), metadata=defaultmetadata(NMRData), missingval=missing)
    return NMRData(A, Dimensions.format(dims, A), refdims, name, metadata, missingval)
end

function NMRData(A::AbstractArray{<:Any,1}, dims::Tuple{<:Dimension,<:Dimension,Vararg};
                 kw...)
    return NMRData(reshape(A, map(length, dims)), dims; kw...)
end

# function NMRData(table, dims::Tuple; name=first(_not_a_dimcol(table, dims)), kw...)
#     Tables.istable(table) ||
#         throw(ArgumentError("First argument to `NMRData` is not a table or other known object: $table"))
#     isnothing(name) && throw(UndefKeywordError(:name))
#     cols = Tables.columns(table)
#     A = reshape(cols[name], map(length, dims))
#     return NMRData(A, dims; name, kw...)
# end

NMRData(A::AbstractArray; dims, kw...) = NMRData(A, dims; kw...)

function NMRData(A::AbstractDimArray;
                 data=parent(A), dims=dims(A), refdims=refdims(A),
                 name=name(A), metadata=metadata(A), missingval=missingval(A), kw...)
    return NMRData(data, dims; refdims, name, metadata, missingval, kw...)
end

# function NMRData(filename::AbstractString, dims::Tuple{<:Dimension,<:Dimension,Vararg};
#                  kw...)
#     return NMRData(filename; dims, kw...)
# end

# TODO ??
# DD.dimconstructor(::Tuple{<:Dimension{<:AbstractProjected},Vararg{<:Dimension}}) = NMRData









# Getters ##########################################################################################
"""
    data(nmrdata)

Return the numerical data associated with the specified NMRData.
"""
data(A::NMRData) = A.data



"""
    data(nmrdata, dim)

Return the numerical data associated with the specified dimension.
"""
data(A::NMRData, dim) = data(dims(A, dim))

# Methods ##########################################################################################
"""
    scale(d::AbstractNMRData)

Return a scaling factor for the data combining the number of scans, receiver gain, and, if
specified, the sample concentration.
```math
\\mathrm{scale} = \\mathrm{ns} \\cdot \\mathrm{rg} \\cdot \\mathrm{conc}
```
"""
function scale(d::AbstractNMRData)
    # get ns, rg, and concentration, with safe defaults in case missing
    ns = get(metadata(d), :ns, 1)
    rg = get(metadata(d), :rg, 1)
    conc = get(metadata(d), :conc, 1)
    return ns * rg * conc
end


# Set pseudo-dimension data

"""
    setkinetictimes(A::NMRData, tvals, units=nothing)

Return a new NMRData with the unknown dimension or time dimension replaced
with a kinetic time axis containing the passed values (and optionally, units).
"""
function setkinetictimes(A::NMRData, tvals, units=nothing)
    hasnonfrequencydimension(A) || throw(NMRToolsError("cannot set time values: data does not have a non-frequency dimension"))

    nonfreqdims = isa.(dims(A), NonFrequencyDimension)
    sum(nonfreqdims) == 1 || throw(NMRToolsError("multiple non-frequency dimensions are present - ambiguous command"))

    olddim = findfirst(nonfreqdims)
    newdim = TkinDim(tvals)
    newA = replacedimension(A::NMRData, olddim, newdim)

    label!(newA, newdim, "Time elapsed")
    newA[newdim, :units] = units

    return newA
end



"""
    setrelaxtimes(A::NMRData, tvals, units="")

Return a new NMRData with the unknown dimension or time dimension replaced
with a relaxation time axis containing the passed values (and optionally, units).
"""
function setrelaxtimes(A::NMRData, tvals, units="")
    hasnonfrequencydimension(A) || throw(NMRToolsError("cannot set time values: data does not have a non-frequency dimension"))

    nonfreqdims = isa.(dims(A), NonFrequencyDimension)
    sum(nonfreqdims) == 1 || throw(NMRToolsError("multiple non-frequency dimensions are present - ambiguous command"))

    olddim = findfirst(nonfreqdims)
    newdim = TrelaxDim(tvals)
    newA = replacedimension(A::NMRData, olddim, newdim)

    label!(newA, newdim, "Relaxation time")
    newA[newdim, :units] = units

    return newA
end



"""
    setgradientlist(A::NMRData, relativegradientlist, Gmax=nothing)

Return a new NMRData with an unknown dimension replaced with a gradient axis
containing the passed values. A default gradient strength of 0.55 T m⁻¹ will
be set, but a warning raised for the user.
"""
function setgradientlist(A::NMRData, relativegradientlist, Gmax=nothing)
    hasnonfrequencydimension(A) || throw(NMRToolsError("cannot set gradient values: data does not have a non-frequency dimension"))
    
    unknowndims = isa.(dims(A), UnknownDimension)
    sum(unknowndims) == 1 || throw(NMRToolsError("multiple unknown dimensions are present - ambiguous command"))

    if isnothing(Gmax)
        @warn("a maximum gradient strength of 0.55 T m⁻¹ is being assumed - this is roughly correct for modern Bruker systems but calibration is recommended")
        gvals = 0.55 * relativegradientlist
    else
        gvals = Gmax * relativegradientlist
    end

    olddim = findfirst(unknowndims)
    newdim = G1Dim(gvals)
    newA = replacedimension(A::NMRData, olddim, newdim)

    label!(newA, newdim, "Gradient strength")
    newA[newdim, :units] = "T m⁻¹"

    return newA
end



"""
    replacedimension(nmrdata, olddimnumber, newdim)

Return a new NMRData, in which the numbered axis is replaced by a new `Dimension`.
"""
function replacedimension(A::NMRData, olddimnumber, newdim)
    olddim = dims(A, olddimnumber)
    length(olddim) == length(newdim) || throw(NMRToolsError("size of old and new dimensions are not compatible"))
    merge!(metadata(newdim).val, metadata(olddim).val)

    olddims = Vector{NMRDimension}([dims(A)...])
    olddims[olddimnumber] = newdim
    newdims = tuple(olddims...)

    NMRData(A.data, newdims, name=A.name, refdims=A.refdims, metadata=A.metadata)
end





"""
    decimate(data, n dims=1)

Decimate NMR data into n-point averages along the specified dimension.
Note that data are *averaged* and not *summed*. Noise metadata is not updated.
"""
function decimate(expt::NMRData, n, dims=1)
	np = size(expt, dims) ÷ n
	out = selectdim(expt, dims, 1:n:(np*n)) # preallocate decimated NMRData
	
	sz = [size(out)...]
	insert!(sz, dims, n)
	
	y = selectdim(data(expt), dims, 1:(np*n))
	y = reshape(y, sz...)
	y = reduce(+, y, dims=dims) / n
	
	outsz = [size(out)...]
	outsz[dims] = np
	data(out) .= reshape(y, outsz...)

	out
end



function decimate(signal, n, dims=1)
	np = size(signal, dims) ÷ n
	y = selectdim(signal, dims, 1:(np*n))
	
	sz = [size(signal)...]
	sz[dims] = np
	insert!(sz, dims, n)
	
	y = reshape(y, sz...)
	y = sum(y, dims=dims) / n

	outsz = [size(signal)...]
	outsz[dims] = np
	reshape(y, outsz...)
end



"""
    stack(expts::Vector{NMRData})

Combine a collection of equally-sized NMRData into one larger array, by arranging them
along a new dimension, of type `UnknownDimension`.

Throws a `DimensionMismatch` if data are not of compatible shapes.
"""
function Base.stack(expts::Vector{D}) where {D <: AbstractNMRData{T,N}} where {T,N}
    # construct new data
    newdata = stack(data, expts)
    
    # construct new dimensions
    n = length(expts)
    if N==1
        newdim = X2Dim(1:n)
    elseif N==2
        newdim = X3Dim(1:n)
    elseif N==3
        newdim = X4Dim(1:n)
    end
    newdims = [dims(expts[1])..., newdim]
    # push!(newdims, newdim)
    newdims = tuple(newdims...)

    # check and warn if dimensions don't match
    allequal(map(dims, expts)) || warn("stack: dimensions of expts 1 and $i are not equal")

    # construct new metadata, based on metadata for first spectrum
    newmd = deepcopy(metadata(first(expts)))
    newmd[:ndim] = N + 1

    # check and warn if ns don't match between experiments
    ns = map(e -> e[:ns], expts)
    allequal(ns) || @warn "stack: experiments do not have same ns" ns
    rg = map(e -> e[:rg], expts)
    allequal(rg) || @warn "stack: experiments do not have same rg" rg
   
    NMRData(newdata, newdims, metadata=newmd)
end



# Arithmetic #######################################################################################

# BUG - it would be nice to propagate the noise, but at the moment metadata is shallow-copied during
# arithmetic operations so the operation changes the original input values as well.

# function Base.:+(a::NMRData, b::NMRData)
#     c = invoke(+, Tuple{DimensionalData.AbstractDimArray, DimensionalData.AbstractDimArray}, a, b)
#     c = NMRData(c.data, dims(c), name=c.name, refdims=c.refdims, metadata=copy(metadata(c)))
#     delete!(metadata(c), :noise) # delete old entry
#     c[:noise] = sqrt(get(metadata(a), :noise, 0)^2 + get(metadata(b), :noise, 0)^2)
#     return c
# end

# function Base.:-(a::NMRData, b::NMRData)
#     c = invoke(-, Tuple{DimensionalData.AbstractDimArray, DimensionalData.AbstractDimArray}, a, b)
#     c = NMRData(c.data, dims(c), name=c.name, refdims=c.refdims, metadata=copy(metadata(c)))
#     delete!(metadata(c), :noise) # delete old entry
#     c[:noise] = sqrt(get(metadata(a), :noise, 0)^2 + get(metadata(b), :noise, 0)^2)
#     return c
# end

# function Base.:*(a::Number, b::NMRData)
#     c = invoke(*, Tuple{Number, DimensionalData.AbstractDimArray}, a, b)
#     c = NMRData(c.data, dims(c), name=c.name, refdims=c.refdims, metadata=copy(metadata(c)))
#     delete!(metadata(c), :noise) # delete old entry
#     c[:noise] = a * get(metadata(b), :noise, 0)
#     return c
# end

# function Base.:/(a::NMRData, b::Number)
#     c = invoke(/, Tuple{DimensionalData.AbstractDimArray, Number}, a, b)
#     c = NMRData(c.data, dims(c), name=c.name, refdims=c.refdims, metadata=copy(metadata(c)))
#     delete!(metadata(c), :noise) # delete old entry
#     c[:noise] = get(metadata(a), :noise, 0) / b
#     return c
# end


# Traits ###########################################################################################
"""
    @traitdef HasNonFrequencyDimension{D}

A trait indicating whether the data object has a non-frequency domain dimension.

# Example

```julia
@traitfn f(x::X) where {X; HasNonFrequencyDimension{X}} = "This spectrum has a non-frequency domain dimension!"
@traitfn f(x::X) where {X; Not{HasNonFrequencyDimension{X}}} = "This is a pure frequency-domain spectrum!"
```
"""
@traitdef HasNonFrequencyDimension{D}

# adapted from expansion of @traitimpl
# this is a pure function because it only depends on the type definition of NMRData
Base.@pure function SimpleTraits.trait(t::Type{HasNonFrequencyDimension{D}}) where D<:NMRData{T,N,A} where {T,N,A}
    if any(map(dim->(typeintersect(dim, FrequencyDimension) == Union{}), A.parameters))
        HasNonFrequencyDimension{D}
    else
        Not{HasNonFrequencyDimension{D}}
    end
end

"""
    hasnonfrequencydimension(spectrum)

Return true if the spectrum contains a non-frequency domain dimension.

# Example

```julia
julia> y2=loadnmr("exampledata/2D_HN/test.ft2");
julia> hasnonfrequencydimension(y2)
false
julia> y3=loadnmr("exampledata/pseudo3D_HN_R2/ft/test%03d.ft2");
julia> hasnonfrequencydimension(y3)
true
```
"""
function hasnonfrequencydimension(spectrum::NMRData{T,N,A}) where {T,N,A}
    any(map(dim->(typeintersect(dim, FrequencyDimension) == Union{}), A.parameters))
end