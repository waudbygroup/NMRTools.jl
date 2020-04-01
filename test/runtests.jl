using NMRTools
using Test
using SafeTestsets

@safetestset "NMRData" begin
    include("nmrdata_test.jl")
end
