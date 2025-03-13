module NMRBase

const EXPERIMENTAL = """
    WARNING: This feature is experimental. It may change in future versions, and may
    not be 100% reliable in all cases. Please file github issues if problems occur.
    """

# DimensionalData documentation urls
const DDdocs = "https://rafaqz.github.io/DimensionalData.jl/stable/api"
const DDdimdocs = joinpath(DDdocs, "#DimensionalData.Dimension")
const DDarraydocs = joinpath(DDdocs, "#DimensionalData.AbstractDimensionalArray")


using LinearAlgebra
using Optim
using Reexport
using SimpleTraits
using SpecialFunctions
using Statistics

@reexport using DimensionalData

using DimensionalData.Tables,
      DimensionalData.Lookups,
      DimensionalData.Dimensions,
      DimensionalData.Lookups.IntervalSets

using DimensionalData: Name, NoName
using .Dimensions: StandardIndices, DimTuple
using .Lookups: LookupTuple


include("exceptions.jl")
include("nuclei.jl")
include("coherences.jl")
include("isotopedata.jl")
include("dimensions.jl")
include("nmrdata.jl")
include("windows.jl")
include("metadata.jl")
include("noise.jl")
include("pcls.jl")

macro exportinstances(enum)
    eval = GlobalRef(Core, :eval)
    return :($eval($__module__, Expr(:export, map(Symbol, instances($enum))...)))
end

# Exceptions
export NMRToolsError

# Nuclei
export Nucleus
@exportinstances Nucleus
export spin
export gyromagneticratio

# coherences
export Coherence
export SQ, MQ
export coherenceorder

# NMRData
export AbstractNMRData
export NMRData
# traits
export hasnonfrequencydimension, HasNonFrequencyDimension
# NMR properties
export scale
export estimatenoise!
export decimate

# Dimensions
export NMRDimension
export FrequencyDimension
export NonFrequencyDimension
export TimeDimension
export GradientDimension
export UnknownDimension
export F1Dim, F2Dim, F3Dim, F4Dim
export T1Dim, T2Dim, T3Dim, T4Dim
export TrelaxDim, TkinDim
export G1Dim, G2Dim, G3Dim, G4Dim
export X1Dim, X2Dim, X3Dim, X4Dim

export getω
export replacedimension
export setkinetictimes
export setrelaxtimes
export setgradientlist
export add_offset

# Metadata
export metadata
export defaultmetadata
export metadatahelp
export label, label!, units
export acqus

# Window functions
export WindowFunction
export NullWindow
export UnknownWindow
export ExponentialWindow
export SineWindow
export GeneralSineWindow, CosWindow, Cos²Window
export GaussWindow
export GeneralGaussWindow, LorentzToGaussWindow
export lineshape
export apod

export LineshapeComplexity
export RealLineshape
export ComplexLineshape

# phase-constrained least squares
export pcls

end
