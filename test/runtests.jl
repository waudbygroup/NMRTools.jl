using NMRTools
using Test
using SafeTestsets

@safetestset "NMRBase" begin
    include("nmrbase_test.jl")
end
