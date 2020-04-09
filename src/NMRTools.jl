module NMRTools

using Lazy
using Reexport
using SimpleTraits
@reexport using DimensionalData
#: Dimension, IndependentDim, DependentDim,
    # XDim, YDim, ZDim, TimeDim,
    # ParametricDimension, Dim, AnonDim,
    # Selector, Between, At, Contains, Near,
    # Locus, Center, Start, End, AutoLocus, #NoLocus,
    # Order, Ordered, Unordered, UnknownOrder, AutoOrder,
    # Sampling, Points, Intervals,
    # Span, Regular, Irregular, AutoSpan,
    # IndexMode, AutoIndex, #UnknownIndex, NoIndex,
    # Aligned, AbstractSampled, Sampled,
    # AbstractCategorical, Categorical,
    # Unaligned, Transformed,
    # AbstractDimensionalArray, DimensionalArray,
    # data, dims, refdims, metadata, name, shortname,
    # val, label, units, order, bounds, locus, mode, <|
    # dimnum, hasdim, setdims, swapdims, rebuild

export NMRData
export HasPseudoDimension
export X, Y, Z, Ti

include("nmrdata.jl")


end # module
