using NMRTools
using Test

# generate some sample data
x1 = 0:.1:1;
x2 = 1:4;
y = [cos(n1)+n2 for n1 in x1,  n2 in x2];
@test y[1,1] == 2
@test y[11,4] ≈ 4.5403023
md = Dict{Any,Any}(:test=>"hello data")
md1 = Dict{Any,Any}(:test=>"hello axis 1")
md2 = Dict{Any,Any}(:test=>"hello axis 2")


@testset "Creating axes" begin
    ax1 = X(x1; metadata=Dict())
    ax2 = Y(x2; metadata=Dict())
    ax3 = Z(x1; metadata=Dict())
    ax4 = Ti(x2; metadata=Dict())
    @test ax1[1] == 0.0
    @test val(ax1) == x1
    @test metadata(ax1) isa Dict
end

@testset "Creating NMRData indirectly via DimensionalData" begin
    A = DimensionalArray(y, (X(x1; metadata=Dict()), Y(x2; metadata=Dict())));
    @test A[1,1] == 2
    d = NMRData(A, md)
    @test d[1,1] == 2
end

@testset "Creating NMRData directly" begin
    d = NMRData(y, (X(x1; metadata=Dict()), Y(x2; metadata=Dict())), md)
    @test d[1,1] == 2
    @test d == y
    @test metadata(d) isa Dict
    @test metadata(d)[:test] == "hello data"
    @test metadata(d,X) isa Dict
    @test metadata(d,Y) isa Dict
    @test size(d) == (11,4)
    @test length(d) == 44
    @test d[At(1.0),At(4)] ≈ 4.5403023
    @test d[Near(-0.5), Near(0.9)] == 2
    @test size(d[Between(0.25,0.65),Between(3,4)]) == (4,2)
end
