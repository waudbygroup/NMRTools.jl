using NMRTools
using SimpleTraits
using Test

# generate some sample data
x1 = X(0:.1:1);
x2 = Y(1:4);
x3 = Ti(10:10:30);
y1 = [cos(n1) for n1 in x1];
y2 = [cos(n1)+n2 for n1 in x1,  n2 in x2];
y3 = [cos(n1)+n2/n3 for n1 in x1,  n2 in x2, n3 in x3];
md = Dict{Any,Any}(:test=>"hello data");
md1 = Dict{Any,Any}(:test=>"hello axis 1");
md2 = Dict{Any,Any}(:test=>"hello axis 2");
md3 = Dict{Any,Any}(:test=>"hello axis 3");
@test y2[1,1] == 2
@test y2[11,4] ≈ 4.5403023


@testset "Creating axes" begin
    for f in [X, Y, Z, Ti]
        ax = f(0:.1:1)
        @test ax[1] == 0.0
        @test val(ax) == 0:.1:1
        @test metadata(ax) isa Dict
    end
end

@testset "Creating NMRData indirectly via DimensionalData" begin
    A = DimensionalArray(y2, (X(x1), Y(x2)));
    @test A[1,1] == 2
    d = NMRData(A, md)
    @test d[1,1] == 2
end

@testset "Creating NMRData" begin
    d = NMRData(y2, (x1, x2))
    @test metadata(d) isa Dict
    d = NMRData(y2, (x1, x2), md)
    @test d[1,1] == 2
    @test d == y2
    @test metadata(d) isa Dict
    @test metadata(d)[:test] == "hello data"
    @test metadata(d,X) isa Dict
    @test metadata(d,Y) isa Dict
    @test metadata(d,1) isa Dict
    @test size(d) == (11,4)
    @test length(d) == 44
    @test d[At(1.0),At(4)] ≈ 4.5403023
    @test d[Near(-0.5), Near(0.9)] == 2
    @test size(d[Between(0.25,0.65),Between(3,4)]) == (4,2)
    d = NMRData(y2, (X(0:.1:1, md1), Y(1:4, md2)), md)
    @test metadata(d,X)[:test] == "hello axis 1"
    @test metadata(d,Y)[:test] == "hello axis 2"
end

@traitfn f(x::X) where {X; HasPseudoDimension{X}} = "Fake!"
@traitfn f(x::X) where {X; Not{HasPseudoDimension{X}}} = "Real!"

@testset "HasPseudoDim trait" begin
    d = NMRData(y1, (X(x1), ))
    @test f(d) == "Real!"
    d = NMRData(y2, (X(x1), Y(x2)))
    @test f(d) == "Real!"
    d = NMRData(y2, (X(x1), Ti(x2)))
    @test f(d) == "Fake!"
    d = NMRData(y3, (X(x1), Y(x2), Z(x3)))
    @test f(d) == "Real!"
    d = NMRData(y3, (X(x1), Y(x2), Ti(x3)))
    @test f(d) == "Fake!"
end
