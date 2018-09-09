using StructArrays
using Test

# write your own tests here
@testset "index" begin
    a, b = [1 2; 3 4], [4 5; 6 7]
    t = StructArray((a = a, b = b))
    @test t[2,2] == (a = 4, b = 7)
    @test t[2,1:2] == StructArray((a = [3, 4], b = [6, 7]))
    @test view(t, 2, 1:2) == StructArray((a = view(a, 2, 1:2), b = view(b, 2, 1:2)))
end

@testset "complex" begin
    a, b = [1 2; 3 4], [4 5; 6 7]
    t = StructArray{ComplexF64}(a, b)
    @test t[2,2] == ComplexF64(4, 7)
    @test t[2,1:2] == StructArray{ComplexF64}([3, 4], [6, 7])
    @test view(t, 2, 1:2) == StructArray{ComplexF64}(view(a, 2, 1:2), view(b, 2, 1:2))
end

@testset "resize!" begin
    t = StructArray{Pair}([3, 5], ["a", "b"])
    resize!(t, 5)
    @test length(t) == 5
    p = 1 => "c"
    t[5] = p
    @test t[5] == p
end

@testset "concat" begin
    t = StructArray{Pair}([3, 5], ["a", "b"])
    push!(t, (2 => "c"))
    @test t == StructArray{Pair}([3, 5, 2], ["a", "b", "c"])
    append!(t, t)
    @test t == StructArray{Pair}([3, 5, 2, 3, 5, 2], ["a", "b", "c", "a", "b", "c"])
    t = StructArray{Pair}([3, 5], ["a", "b"])
    t2 = StructArray{Pair}([1, 6], ["a", "b"])
    @test cat(t, t2; dims=1) == StructArray{Pair}([3, 5, 1, 6], ["a", "b", "a", "b"]) == vcat(t, t2)
    @test vcat(t, t2) isa StructArray
    @test cat(t, t2; dims=2) == StructArray{Pair}([3 1; 5 6], ["a" "a"; "b" "b"]) == hcat(t, t2)
    @test hcat(t, t2) isa StructArray
end

f_infer() = StructArray{ComplexF64}(rand(2,2), rand(2,2))
@testset "inferrability" begin
    @inferred f_infer()
end

@testset "propertynames" begin
    a = StructArray{ComplexF64}(Float64[], Float64[])
    @test sort(collect(propertynames(a))) == [:im, :re]
end
