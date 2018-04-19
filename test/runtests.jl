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

@testset "concat" begin
    t = StructureArray{Pair}([3, 5], ["a", "b"])
    push!(t, (2 => "c"))
    @test t == StructureArray{Pair}([3, 5, 2], ["a", "b", "c"])
    append!(t, t)
    @test t == StructureArray{Pair}([3, 5, 2, 3, 5, 2], ["a", "b", "c", "a", "b", "c"])
    t = StructureArray{Pair}([3, 5], ["a", "b"])
    t2 = StructureArray{Pair}([1, 6], ["a", "b"])
    @test cat(1, t, t2) == StructureArray{Pair}([3, 5, 1, 6], ["a", "b", "a", "b"]) == vcat(t, t2)
    @test vcat(t, t2) isa StructureArray
    @test cat(2, t, t2) == StructureArray{Pair}([3 1; 5 6], ["a" "a"; "b" "b"]) == hcat(t, t2)
    @test hcat(t, t2) isa StructureArray
end
