using StructureArrays
using Test

# write your own tests here
@testset "index" begin
    a, b = [1 2; 3 4], [4 5; 6 7]
    t = StructureArray((a = a, b = b))
    @test t[2,2] == (a = 4, b = 7)
    @test t[2,1:2] == StructureArray((a = [3, 4], b = [6, 7]))
    @test view(t, 2, 1:2) == StructureArray((a = view(a, 2, 1:2), b = view(b, 2, 1:2)))
end

@testset "complex" begin
    a, b = [1 2; 3 4], [4 5; 6 7]
    t = StructureArray{ComplexF64}(a, b)
    @test t[2,2] == ComplexF64(4, 7)
    @test t[2,1:2] == StructureArray{ComplexF64}([3, 4], [6, 7])
    @test view(t, 2, 1:2) == StructureArray{ComplexF64}(view(a, 2, 1:2), view(b, 2, 1:2))
end
