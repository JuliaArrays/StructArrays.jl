using StructArrays
using StructArrays: staticschema, iscompatible, _promote_typejoin, append!!
using OffsetArrays: OffsetArray, OffsetVector, OffsetMatrix
using StaticArrays
import Tables, PooledArrays, WeakRefStrings
using TypedTables: Table
using DataAPI: refarray, refvalue
using Adapt: adapt, Adapt
using JLArrays
using GPUArraysCore: backend
using LinearAlgebra
using Test
using SparseArrays
using InfiniteArrays

using Documenter: doctest
if Base.VERSION == v"1.6" && Int === Int64
    doctest(StructArrays)
end

# Most types should not be viewed as equivalent merely
# because they have the same field names. (Exception:
# NamedTuples are distinguished only by field names, so they
# are treated as equivalent to any struct with the same
# field names.) To test proper behavior, define two types
# that are "structurally" equivalent...
struct Meters
    x::Float64
end
struct Millimeters
    x::Float64
end
# ...but not naively transferrable
Base.convert(::Type{Meters}, x::Millimeters) = Meters(x.x/1000)
Base.convert(::Type{Millimeters}, x::Meters) = Millimeters(x.x*1000)


@testset "index" begin
    a, b = [1 2; 3 4], [4 5; 6 7]
    t = StructArray((a = a, b = b))
    @test (@inferred t[2,2]) == (a = 4, b = 7)
    @test (@inferred t[2,1:2]) == StructArray((a = [3, 4], b = [6, 7]))
    @test_throws BoundsError t[3,3]
    @test (@inferred view(t, 2, 1:2)) == StructArray((a = view(a, 2, 1:2), b = view(b, 2, 1:2)))
    @test @inferred(parentindices(view(t, 2, 1:2))) == (2, 1:2)
    @test_throws ArgumentError parentindices(StructArray((view([1, 2], [1]), view([1, 2], [2]))))

    # Element type conversion (issue #216)
    x = StructArray{Complex{Int}}((a, b))
    x[1,1] = 10
    x[2,2] = 20im
    @test x[1,1] === 10 + 0im
    @test x[2,2] === 0 + 20im

    # Test that explicit `setindex!` returns the entire array
    # (Julia's parser ensures that chained assignment returns the value)
    @test setindex!(x, 22, 3) === x

    s = StructArray(a=1:5)
    @test s[2:3].a === 2:3
end

@testset "eltype conversion" begin
    v = StructArray{Complex{Int}}(([1,2,3], [4,5,6]))
    @test append!(v, [7, 8]) == [1+4im, 2+5im, 3+6im, 7+0im, 8+0im]
    push!(v, (im=12, re=11))  # NamedTuples support field assignment by name
    @test v[end] === 11 + 12im
    v[end] = (re=9, im=10)
    @test v[end] === 9 + 10im

    # For some eltypes, the structarray is "nameless" and we can use regular Tuples
    v = StructArray([SVector(true, false), SVector(false, false)])
    v[end] = (true, true)
    @test v[end] === SVector(true, true)
    push!(v, (false, false))
    @test v[end] === SVector(false, false)

    z = StructArray{Meters}(undef, 0)
    push!(z, Millimeters(1100))
    @test length(z) == 1
    @test z[1] === Meters(1.1)
    append!(z, [Millimeters(1200)])
    @test z[2] === Meters(1.2)
    append!(z, StructArray{Millimeters}(([1500.0],)))
    @test z[3] === Meters(1.5)
    insert!(z, 3, Millimeters(2000))
    @test z[3] === Meters(2.0)
end

@testset "components" begin
    t = StructArray(a = 1:10, b = rand(Bool, 10))
    @test StructArrays.propertynames(t) == (:a, :b)
    @test StructArrays.propertynames(StructArrays.components(t)) == (:a, :b)
end

@testset "utils" begin
    t = StructArray(rand(ComplexF64, 2, 2))
    @test StructArrays.eltypes((re = 1.0, im = 1.0)) == NamedTuple{(:re, :im), Tuple{Float64, Float64}}
    @test !iscompatible(typeof((1, 2)), typeof(([1],)))
    @test iscompatible(typeof((1, 2)), typeof(([1], [2])))
    @test !iscompatible(typeof((1, 2)), typeof(([1.1], [2])))
    @test iscompatible(typeof(()), typeof(()))
    @test _promote_typejoin(Tuple{Int, Missing}, Tuple{Int, Int}) == Tuple{Int, Union{Int, Missing}}
    @test _promote_typejoin(Pair{Int, Missing}, Pair{Int, Int}) == Pair{Int, Union{Int, Missing}}
    @test _promote_typejoin(NamedTuple{(:a, :b), Tuple{Int, Missing}}, NamedTuple{(:a, :b), Tuple{Int, Int}}) == NamedTuple{(:a, :b), Tuple{Int, Union{Int, Missing}}}
    @test _promote_typejoin(Tuple{}, Tuple{}) == Tuple{}
    @test _promote_typejoin(Tuple{Int}, Tuple{Int, Int}) == Tuple{Int, Vararg{Int}}

    @test StructArrays.astuple(Tuple{Int}) == Tuple{Int}
    @test StructArrays.strip_params(Tuple{Int}) == Tuple
    @test StructArrays.astuple(NamedTuple{(:a,), Tuple{Float64}}) == Tuple{Float64}
    @test StructArrays.strip_params(NamedTuple{(:a,), Tuple{Float64}}) == NamedTuple{(:a,)}

    cols = (a=rand(2), b=rand(2), c=rand(2))
    @test StructArrays.findconsistentvalue(length, cols) == 2
    @test StructArrays.findconsistentvalue(length, Tuple(cols)) == 2

    cols = (a=rand(2), b=rand(2), c=rand(3))
    @test isnothing(StructArrays.findconsistentvalue(length, cols))
    @test isnothing(StructArrays.findconsistentvalue(length, Tuple(cols)))
end

@testset "indexstyle" begin
    s = StructArray(a=rand(10,10), b=view(rand(100,100), 1:10, 1:10))
    T = typeof(s)
    @test IndexStyle(T) === IndexCartesian()
    @test StructArrays.index_type(s) == CartesianIndex{2}
    @test s[100] == s[10, 10] == (a=s.a[10,10], b=s.b[10,10])
    s[100] = (a=1, b=1)
    @test s[100] == s[10, 10] == (a=1, b=1)
    s[10, 10] = (a=0, b=0)
    @test s[100] == s[10, 10] == (a=0, b=0)
    @inferred IndexStyle(StructArray(a=rand(10,10), b=rand(10,10)))
    s = StructArray(a=rand(10,10), b=rand(10,10))
    T = typeof(s)
    @test StructArrays.index_type(s) == Int
    @inferred IndexStyle(s)
    @test s[100] == s[10, 10] == (a=s.a[10,10], b=s.b[10,10])
    s[100] = (a=1, b=1)
    @test s[100] == s[10, 10] == (a=1, b=1)
    s[10, 10] = (a=0, b=0)
    @test s[100] == s[10, 10] == (a=0, b=0)

    # inference for "many" types, both for linear ad Cartesian indexing
    @inferred StructArrays.index_type(ntuple(_ -> rand(5), 2))
    @inferred StructArrays.index_type(ntuple(_ -> rand(5, 5), 3))
    @inferred StructArrays.index_type(ntuple(_ -> rand(5, 5, 5), 4))

    @inferred StructArrays.index_type(ntuple(_ -> view(rand(5), 1:3), 2))
    @inferred StructArrays.index_type(ntuple(_ -> view(rand(5, 5), 1:3, 1:2), 3))
    @inferred StructArrays.index_type(ntuple(_ -> view(rand(5, 5, 5), 1:3, 1:2, 1:4), 4))

    @inferred StructArrays.index_type(ntuple(n -> n == 1 ? rand(5, 5) : view(rand(5, 5), 1:2, 1:3), 5))
    @inferred IndexStyle(StructArray(a=rand(10,10), b=view(rand(100,100), 1:10, 1:10)))
end

@testset "replace_storage" begin
    v = StructArray(a=rand(10), b = fill("string", 10))
    v_pooled = StructArrays.replace_storage(v) do c
        isbitstype(eltype(c)) ? c : convert(PooledArrays.PooledArray, c)
    end
    @test eltype(v) == eltype(v_pooled)
    @test all(v.a .== v_pooled.a)
    @test all(v.b .== v_pooled.b)
    @test !isa(v_pooled.a, PooledArrays.PooledArray)
    @test isa(v_pooled.b, PooledArrays.PooledArray)
end

@testset "roweq" begin
    a = ["a", "b", "a", "a"]
    b = PooledArrays.PooledArray(["x", "y", "z", "x"])
    s = StructArray((a, b))
    @test StructArrays.roweq(s, 1, 1)
    @test !StructArrays.roweq(s, 1, 2)
    @test !StructArrays.roweq(s, 1, 3)
    @test StructArrays.roweq(s, 1, 4)
    strs = WeakRefStrings.StringArray(["a", "a", "b"])
    @test StructArrays.roweq(strs, 1, 1)
    @test StructArrays.roweq(strs, 1, 2)
    @test !StructArrays.roweq(strs, 1, 3)
    @test !StructArrays.roweq(strs, 2, 3)
end

@testset "permute" begin
    a = WeakRefStrings.StringVector(["a", "b", "c"])
    b = PooledArrays.PooledArray([1, 2, 3])
    c = [:a, :b, :c]
    s = StructArray(a=a, b=b, c=c)
    permute!(s, [2, 3, 1])
    @test s.a == ["b", "c", "a"]
    @test s.b == [2, 3, 1]
    @test s.c == [:b, :c, :a]
    s = StructArray(a=[1, 2], b=["a", "b"])
    t = StructArray(a=[3, 4], b=["c", "d"])
    copyto!(s, t)
    @test s == t

    s = StructArray(a=[1, 2], b=["a", "b"])
    t = StructArray(a=[3, 4], b=["c", "d"])
    copyto!(s, 1, t, 1, 2)
    @test s == t

    a = WeakRefStrings.StringVector(["a", "b", "c"])
    b = PooledArrays.PooledArray(["1", "2", "3"])
    c = [:a, :b, :c]
    s = StructArray(a=a, b=b, c=c)
    ref = refarray(s)
    Base.permute!!(ref, sortperm(s))
    @test issorted(s)
end

@testset "sortperm" begin
    c = StructArray(a=[1,1,2,2], b=[1,2,3,3], c=["a","b","c","d"])
    d = StructArray(a=[1,1,2,2], b=[1,2,3,3], c=["a","b","c","d"])
    @test issorted(c)
    @test sortperm(c) == [1,2,3,4]
    permute!(c, [2,3,4,1])
    @test c == StructArray(a=[1,2,2,1], b=[2,3,3,1], c=["b","c","d","a"])
    @test sortperm(c) == [4,1,2,3]
    @test !issorted(c)
    @test sort(c) == d
    sort!(c)
    @test c == d

    c = StructArray(a=[1,1,2,2], b=[1,2,3,3], c=PooledArrays.PooledArray(["a","b","c","d"]))
    d = StructArray(a=[1,1,2,2], b=[1,2,3,3], c=PooledArrays.PooledArray(["a","b","c","d"]))
    @test issorted(c)
    @test sortperm(c) == [1,2,3,4]
    permute!(c, [2,3,4,1])
    @test c == StructArray(a=[1,2,2,1], b=[2,3,3,1], c=PooledArrays.PooledArray(["b","c","d","a"]))
    @test sortperm(c) == [4,1,2,3]
    @test !issorted(c)
    @test sort(c) == d
    sort!(c)
    @test c == d
end

struct C
    a::Int
    b::Int
    c::String
end

@testset "in-place vector methods" begin
    c = StructArray(a=[1], b=[2], c=["a"])
    push!(c, (a=10, b=20, c="A"))
    @test c == StructArray(a=[1,10], b=[2,20], c=["a","A"])
    @test pop!(c) == (a=10, b=20, c="A")
    @test c == StructArray(a=[1], b=[2], c=["a"])

    c = StructArray(a=[1], b=[2], c=["a"])
    pushfirst!(c, (a=10, b=20, c="A"))
    @test c == StructArray(a=[10,1], b=[20,2], c=["A","a"])
    @test popfirst!(c) == (a=10, b=20, c="A")
    @test c == StructArray(a=[1], b=[2], c=["a"])

    c = StructArray(a=[1,2,3], b=[2,3,4], c=["a","b","c"])
    d = insert!(c, 2, (a=10, b=20, c="A"))
    @test d == c == StructArray(a=[1,10,2,3], b=[2,20,3,4], c=["a","A","b","c"])
    d = deleteat!(c, 2)
    @test d == c == StructArray(a=[1,2,3], b=[2,3,4], c=["a","b","c"])

    c = StructArray(a=[1], b=[2], c=["a"])
    d = [(a=10, b=20, c="A")]
    e = append!(c, d)

    @test e == c == StructArray(a=[1,10], b=[2,20], c=["a","A"])

    c = StructArray(a=[1], b=[2], c=["a"])
    d = [(a=10, b=20, c="A")]
    e = prepend!(c, d)

    @test e == c == StructArray(a=[10,1], b=[20,2], c=["A","a"])

    c = StructArray(a=[1,2,3], b=[1,4,6], c=["a","b","c"])
    d = filter!(c) do el
        return isodd(el.a) && iseven(el.b)
    end
    @test d == c == StructArray(a=[3], b=[6], c=["c"])

    c = StructArray{C}(a=[1], b=[2], c=["a"])
    push!(c, C(10, 20, "A"))
    @test c == StructArray{C}(a=[1,10], b=[2,20], c=["a","A"])
    @test pop!(c) == C(10, 20, "A")
    @test c == StructArray{C}(a=[1], b=[2], c=["a"])

    c = StructArray{C}(a=[1], b=[2], c=["a"])
    pushfirst!(c, C(10, 20, "A"))
    @test c == StructArray{C}(a=[10,1], b=[20,2], c=["A","a"])
    @test popfirst!(c) == C(10, 20, "A")
    @test c == StructArray{C}(a=[1], b=[2], c=["a"])

    c = StructArray{C}(a=[1,2,3], b=[2,3,4], c=["a","b","c"])
    d = insert!(c, 2, C(10, 20, "A"))
    @test d == c == StructArray{C}(a=[1,10,2,3], b=[2,20,3,4], c=["a","A","b","c"])
    d = deleteat!(c, 2)
    @test d == c == StructArray{C}(a=[1,2,3], b=[2,3,4], c=["a","b","c"])

    c = StructArray{C}(a=[1], b=[2], c=["a"])
    d = [C(10, 20, "A")]
    e = append!(c, d)

    @test e == c == StructArray{C}(a=[1,10], b=[2,20], c=["a","A"])

    c = StructArray{C}(a=[1], b=[2], c=["a"])
    d = [C(10, 20, "A")]
    e = prepend!(c, d)

    @test e == c == StructArray{C}(a=[10,1], b=[20,2], c=["A","a"])

    c = StructArray{C}(a=[1,2,3], b=[1,4,6], c=["a","b","c"])
    d = filter!(c) do el
        return isodd(el.a) && iseven(el.b)
    end
    @test d == c == StructArray{C}(a=[3], b=[6], c=["c"])
end

@testset "iterators" begin
    c = [1, 2, 3, 1, 1]
    d = StructArrays.GroupPerm(c)
    @test parent(d) == c
    @test eltype(d) == UnitRange{Int}
    @test Base.IteratorEltype(d) == Base.HasEltype()
    @test sortperm(d) == sortperm(c)
    s = collect(d)
    @test s == [1:3, 4:4, 5:5]
    t = collect(StructArrays.finduniquesorted(c))
    @test first.(t) == [1, 2, 3]
    @test last.(t) == [[1, 4, 5], [2], [3]]
    u = collect(StructArrays.uniquesorted(c))
    @test u == [1, 2, 3]
end

@testset "similar" begin
    t = StructArray(a = rand(10), b = rand(Bool, 10))
    s = similar(t)
    @test eltype(s) == NamedTuple{(:a, :b), Tuple{Float64, Bool}}
    @test size(s) == (10,)
    @test s isa StructArray

    t = StructArray(a = rand(10, 2), b = rand(Bool, 10, 2))
    s = similar(t, 3, 5)
    @test eltype(s) == NamedTuple{(:a, :b), Tuple{Float64, Bool}}
    @test size(s) == (3, 5)
    @test s isa StructArray

    s = similar(t, (3, 5))
    @test eltype(s) == NamedTuple{(:a, :b), Tuple{Float64, Bool}}
    @test size(s) == (3, 5)
    @test s isa StructArray

    for ET in (
            NamedTuple{(:x,)},
            NamedTuple{(:x,), Tuple{NamedTuple{(:y,)}}},
            NamedTuple{(:x, :y), Tuple{Int, S}} where S
        )
        s = similar(t, ET, (3, 5))
        @test eltype(s) === ET
        @test size(s) == (3, 5)
        @test s isa StructArray
    end

    s = similar(t, Any, (3, 5))
    @test eltype(s) == Any
    @test size(s) == (3, 5)
    @test s isa Array

    s = similar(t, (0:2, 5))
    @test eltype(s) == NamedTuple{(:a, :b), Tuple{Float64, Bool}}
    @test axes(s) == (0:2, 1:5)
    @test s isa StructArray
    @test s.a isa OffsetArray
    @test s.b isa OffsetArray

    s = similar(t, ComplexF64, 10)
    @test s isa StructArray{ComplexF64, 1, NamedTuple{(:re, :im), Tuple{Vector{Float64}, Vector{Float64}}}}
    @test size(s) == (10,)

    s = similar(t, ComplexF64, 0:9)
    VectorType = OffsetVector{Float64, Vector{Float64}}
    @test s isa StructArray{ComplexF64, 1, NamedTuple{(:re, :im), Tuple{VectorType, VectorType}}}
    @test axes(s) == (0:9,)

    s = similar(t, Float32, 2, 2)
    @test s isa Matrix{Float32}
    @test size(s) == (2, 2)

    s = similar(t, Float32, 0:1, 2)
    @test s isa OffsetMatrix{Float32, Matrix{Float32}}
    @test axes(s) == (0:1, 1:2)

    s = similar(t, ComplexF64, (Base.OneTo(2),))
    @test s isa StructArray
    @test s.re isa Vector{Float64}
    @test axes(s) == (1:2,)

    s = similar(t, Int, (Base.OneTo(2),))
    @test s isa Vector{Int}
    @test axes(s) == (1:2,)

    s = similar(t, ComplexF64, (Base.IdentityUnitRange(5:7),))
    @test s isa StructArray
    @test s.re isa OffsetVector{Float64}
    @test axes(s) == (5:7,)

    s = similar(t, Int, (Base.IdentityUnitRange(5:7),))
    @test s isa OffsetVector{Int}
    @test axes(s) == (5:7,)
end

@testset "similar type" begin
    t = StructArray(a = rand(10), b = rand(10))
    T = typeof(t)
    s = similar(T, 3)
    @test typeof(s) == typeof(t)
    @test size(s) == (3,)

    s = similar(T, 0:2)
    @test axes(s) == (0:2,)
    @test s isa StructArray{NamedTuple{(:a, :b), Tuple{Float64, Float64}}}
    VectorType = OffsetVector{Float64, Vector{Float64}}
    @test s.a isa VectorType
    @test s.b isa VectorType
end

@testset "empty" begin
    s = StructVector(a = [1, 2, 3], b = ["a", "b", "c"])
    empty!(s)
    @test isempty(s.a)
    @test isempty(s.b)
end

@testset "constructor from existing array" begin
    v = rand(ComplexF64, 5, 3)
    t = @inferred StructArray(v)
    @test size(t) == (5, 3)
    @test t[2,2] == v[2,2]
    t2 = convert(StructArray, v)::StructArray
    @test t2 == t
    t3 = StructArray(t)::StructArray
    @test t3 == t
    @test convert(StructArray, t) == t

    v = rand(ComplexF64, 5)
    t = @inferred StructVector(v)
    @test t[2] == v[2]
    @test size(t) == (5,)
    @test t == convert(StructVector, v)
    @test t == convert(StructVector, t)

    t = StructVector([(a=1,), (a=missing,)])::StructVector
    @test isequal(t.a, [1, missing])
    @test eltype(t) <: NamedTuple{(:a,)}

    @test_throws ArgumentError StructArray([nothing])
    @test_throws ArgumentError StructArray([1, 2, 3])
end

@testset "tuple case" begin
    s = StructArray(([1], ["test"],))
    @test s[1] == (1, "test")
    @test Base.getproperty(s, 1) == [1]
    @test Base.getproperty(s, 2) == ["test"]
    t = StructArray{Tuple{Int, Float64}}(([1], [1.2]))
    @test t[1] == (1, 1.2)

    t[1] = (2, 3)
    @test t[1] == (2, 3.0)
    push!(t, (1, 2))
    @test getproperty(t, 1) == [2, 1]
    @test getproperty(t, 2) == [3.0, 2.0]
    @test pop!(t) == (1, 2.0)
    @test getproperty(t, 1) == [2]
    @test getproperty(t, 2) == [3.0]

    @test_throws ArgumentError StructArray(([1, 2], [3]))

    @test_throws ArgumentError StructArray{Tuple{}}(())
    @test_throws ArgumentError StructArray{Tuple{}, 1, Tuple{}}(())
end

@testset "constructor from slices" begin
    if VERSION >= v"1.1"
        X = [1.0 2.0; 3.0 4.0]
        @test StructArray{Complex{Float64}}(X; dims=1) == [Complex(1.0,3.0), Complex(2.0,4.0)]
        @test StructArray{Complex{Float64}}(X; dims=2) == [Complex(1.0,2.0), Complex(3.0,4.0)]

        X = [1.0 2.0; 3.0 4.0; 5.0 6.0]
        @test StructArray{Tuple{Float64,Complex{Float64}}}(X; dims=1) == [(1.0,Complex(3.0,5.0)), (2.0, Complex(4.0,6.0))]
    end
end

struct A
    x::Int
    y::Int
    A(x) = new(x, x)
end

@testset "internal constructor" begin
    v = A.([1, 2, 3])
    s = StructArray(v)
    @test s[1] == A(1)
    @test s[2] == A(2)
    @test s[3] == A(3)
end

@testset "kwargs constructor" begin
    a = [1.2]
    b = [2.3]
    @test StructArray(a=a, b=b) == StructArray((a=a, b=b))
    @test StructArray{ComplexF64}(re=a, im=b) == StructArray{ComplexF64}((a, b))
    f1() = StructArray(a=[1.2], b=["test"])
    f2() = StructArray{Pair{Float64, String}}(first=[1.2], second=["test"])
    t1 = @inferred f1()
    t2 = @inferred f2()
    @test t1 == StructArray((a=[1.2], b=["test"]))
    @test t2 == StructArray{Pair{Float64, String}}(([1.2], ["test"]))

    @test_throws ArgumentError StructArray(a=[1, 2], b=[3])
end

@testset "complex" begin
    a, b = [1 2; 3 4], [4 5; 6 7]
    t = StructArray{ComplexF64}((a, b))
    @test t[2,2] == ComplexF64(4, 7)
    @test t[2,1:2] == StructArray{ComplexF64}(([3, 4], [6, 7]))
    @test view(t, 2, 1:2) == StructArray{ComplexF64}((view(a, 2, 1:2), view(b, 2, 1:2)))
end

@testset "copy" begin
    a, b = [1 2; 3 4], [4 5; 6 7]
    t = StructArray{ComplexF64}((a, b))
    t2 = @inferred copy(t)
    @test t2[1,1] == 1.0 + im*4.0
    t2[1,1] = 2.0 + im*4.0
    # Test we actually did a copy
    @test t[1,1] == 1.0 + im*4.0
    # Test that `copy` works, even when the array type changes (e.g. views)
    s = rand(10, 2)
    v = StructArray{ComplexF64}((view(s, :, 1), view(s, :, 2)))
    v2 = copy(v)
    @test v2.re isa Vector
    @test v2.im isa Vector
    @test v2.re == copy(v.re)
    @test v2.im == copy(v.im)
end

@testset "undef initializer" begin
    t = @inferred StructArray{ComplexF64}(undef, 5, 5)
    @test eltype(t) == ComplexF64
    @test size(t) == (5,5)
    c = 2 + im
    t[1,1] = c
    @test t[1,1] == c
end

@testset "resize!" begin
    t = StructArray{Pair{Int, String}}(([3, 5], ["a", "b"]))
    resize!(t, 5)
    @test length(t) == 5
    p = 1 => "c"
    t[5] = p
    @test t[5] == p
end

@testset "sizehint!" begin
    t = StructArray{Pair{Int, Symbol}}(([3, 5], [:a, :b]))
    sizehint!(t, 5)
    @test @allocated(resize!(t, 5)) == 0
    @test length(t) == 5
    p = 1 => :c
    t[5] = p
    @test t[5] == p
end

@testset "fill!" begin
    @testset "dense array, complex" begin
        A = zeros(3,3)
        B = zeros(3,3)
        S = StructArray{Complex{eltype(A)}}((A, B))
        fill!(S, 2+3im)
        @test all(==(2), A)
        @test all(==(3), B)
    end

    @testset "offset array, custom struct" begin
        struct Vec3D{T} <: FieldVector{3, T}
            x :: T
            y :: T
            z :: T
        end

        A = zeros(3:6, 3:6)
        B = zeros(3:6, 3:6)
        C = zeros(3:6, 3:6)
        S = StructArray{Vec3D{eltype(A)}}((A, B, C))
        fill!(S, Vec3D(1,2,3))
        @test all(==(1), A)
        @test all(==(2), B)
        @test all(==(3), C)
    end

    @testset "Tuple" begin
        S = StructArray{Tuple{Int,Int}}(([1,2], [3,4]))
        fill!(S, (4,5))
        @test all(==((4,5)), S)

        S = StructArray{@NamedTuple{a::Int,b::Int}}(([1,2], [3,4]))
        fill!(S, (a=10.0, b=20.0))
        @test all(==(10), S.a)
        @test all(==(20), S.b)
    end

    @testset "sparse matrix, complex" begin
        A = spzeros(3)
        B = spzeros(3)
        S = StructArray{Complex{eltype(A)}}((A,B))
        fill!(S, 2+3im)
        @test all(==(2), A)
        @test all(==(3), B)
        @test issparse(S)
    end
end

@testset "concat" begin
    t = StructArray{Pair{Int, String}}(([3, 5], ["a", "b"]))
    push!(t, (2 => "d"))
    @test t == StructArray{Pair{Int, String}}(([3, 5, 2], ["a", "b", "d"]))
    @test pop!(t) == (2 => "d")
    push!(t, (2 => "c"))
    @test t == StructArray{Pair{Int, String}}(([3, 5, 2], ["a", "b", "c"]))
    append!(t, t)
    @test t == StructArray{Pair{Int, String}}(([3, 5, 2, 3, 5, 2], ["a", "b", "c", "a", "b", "c"]))
    t = StructArray{Pair{Int, String}}(([3, 5], ["a", "b"]))
    t2 = StructArray{Pair{Int, String}}(([1, 6], ["a", "b"]))
    vertical_concat = StructArray{Pair{Int, String}}(([3, 5, 1, 6], ["a", "b", "a", "b"]))
    @test cat(t, t2; dims=1)::StructArray == vertical_concat == vcat(t, t2)
    @test vcat(t, t2) isa StructArray
    horizontal_concat = StructArray{Pair{Int, String}}(([3 1; 5 6], ["a" "a"; "b" "b"]))
    @test cat(t, t2; dims=2)::StructArray == horizontal_concat == hcat(t, t2)
    @test hcat(t, t2) isa StructArray
    t3 = StructArray(x=view([1], 1:1:1), y=view([:a], 1:1:1))
    @test @inferred(vcat(t3)) == t3
    @inferred vcat(t3, t3)
    @inferred vcat(t3, collect(t3))
    # Check that `cat(dims=1)` doesn't commit type piracy (#254)
    # We only test that this works, the return value is immaterial
    @test cat(dims=1) == vcat()
end

f_infer() = StructArray{ComplexF64}((rand(2,2), rand(2,2)))
g_infer() = StructArray([(a=(b="1",), c=2)], unwrap = t -> t <: NamedTuple)
tup_infer() = StructArray([(1, 2), (3, 4)])
cols_infer() = StructArray(([1, 2], [1.2, 2.3]))
nt_infer(nt) = StructArray{typeof(nt)}(undef, 4)
eltype_infer() = StructArray((rand(10), rand(Int, 10)))
named_eltype_infer() = StructArray((x=rand(10), y=rand(Int, 10)))
compatible_infer() = Val(iscompatible(Tuple{Int, Int}, Tuple{Vector{Int}, Vector{Real}}))
function promote_infer()
    x = (a=1, b=1.2)
    y = (a=1.2, b="a")
    T = _promote_typejoin(typeof(x), typeof(y))
    return convert(T, x)
end
function map_params_infer()
    v = StructArray(rand(ComplexF64, 2, 2))
    f(T) = similar(v, T)
    types = Tuple{Int, Float64, ComplexF32, String}
    return StructArrays.map_params(f, types)
end

@testset "inferrability" begin
    @inferred f_infer()
    @inferred g_infer()
    @test g_infer().a.b == ["1"]
    s = @inferred tup_infer()
    @test StructArrays.components(s) == ([1, 3], [2, 4])
    @test s[1] == (1, 2)
    @test s[2] == (3, 4)
    @inferred cols_infer()
    @inferred nt_infer((x = 3, y = :a, z = :b))
    @inferred eltype_infer()
    @inferred named_eltype_infer()
    @inferred compatible_infer()
    @inferred promote_infer()
    @inferred map_params_infer()
end

@testset "propertynames" begin
    a = StructArray{ComplexF64}((Float64[], Float64[]))
    @test sort(collect(propertynames(a))) == [:im, :re]
end

@testset "tables" begin
    s = StructArray([(a=1, b="test")])
    @test Tables.schema(s) == Tables.Schema((:a, :b), (Int, String))
    @test Tables.rows(s)[1].a == 1
    @test Tables.rows(s)[1].b == "test"
    @test Tables.columns(s).a == [1]
    @test Tables.columns(s).b == ["test"]
    @test Tables.istable(s)
    @test Tables.istable(typeof(s))
    @test Tables.rowaccess(s)
    @test Tables.rowaccess(typeof(s))
    @test Tables.columnaccess(s)
    @test Tables.columnaccess(typeof(s))
    @test Tables.getcolumn(Tables.columns(s), 1) == [1]
    @test Tables.getcolumn(Tables.columns(s), :a) == [1]
    @test Tables.getcolumn(Tables.columns(s), 2) == ["test"]
    @test Tables.getcolumn(Tables.columns(s), :b) == ["test"]
    @test append!(StructArray([1im]), [(re = 111, im = 222)]) ==
        StructArray([1im, 111 + 222im])
    @test append!(StructArray([1im]), (x for x in [(re = 111, im = 222)])) ==
        StructArray([1im, 111 + 222im])
    @test append!(StructArray([1im]), Table(re = [111], im = [222])) ==
        StructArray([1im, 111 + 222im])
    # Testing integer column "names":
    @test invoke(append!, Tuple{StructVector,Any}, StructArray(([0],)), StructArray(([1],))) ==
        StructArray(([0, 1],))

    dtab = (a=[1,2],) |> Tables.dictcolumntable
    @test StructArray(dtab) == [(a=1,), (a=2,)]
    @test StructArray{NamedTuple{(:a,), Tuple{Float64}}}(dtab) == [(a=1.,), (a=2.,)]
    @test StructVector{NamedTuple{(:a,), Tuple{Float64}}}(dtab) == [(a=1,), (a=2,)]

    tblbase = (a=[1,2], b=["3", "4"])
    @testset for tblfunc in [Tables.columntable, Tables.rowtable, Tables.dictcolumntable, Tables.dictrowtable]
        tbl = tblfunc(tblbase)
        sa = StructArrays.fromtable(tbl)
        @test sa::StructArray == [(a=1, b="3"), (a=2, b="4")]
        sa = Tables.materializer(StructArray)(tbl)
        @test sa::StructArray == [(a=1, b="3"), (a=2, b="4")]
        sa = Tables.materializer(sa)(tbl)
        @test sa::StructArray == [(a=1, b="3"), (a=2, b="4")]
    end
end

struct S
    x::Int
    y::Float64
    S(x) = new(x, x)
end

StructArrays.createinstance(::Type{<:S}, x, y) = S(x)

@testset "inner" begin
    v = StructArray{S}(([1], [1]))
    @test v[1] == S(1)
    @test v[1].y isa Float64
end

@testset "arrayof" begin
    v = StructArrays.arrayof(Missing, (2,))
    @test v isa Array{Missing, 1}
    v = StructArrays.arrayof(Int, (2,))
    @test v isa Array{Int, 1}
end

unwrap(t) = t <: Union{Tuple, NamedTuple, Pair}
const initializer = StructArrays.ArrayInitializer(unwrap)
collect_structarray_rec(t) = collect_structarray(t, initializer = initializer)

@testset "collectnamedtuples" begin
    v = [(a = 1, b = 2), (a = 1, b = 3)]
    @test collect_structarray_rec(v) == StructArray((a = Int[1, 1], b = Int[2, 3]))

    # test inferrability with constant eltype
    itr = [(a = 1, b = 2), (a = 1, b = 2), (a = 1, b = 12)]
    el, st = iterate(itr)
    dest = initializer(typeof(el), (3,))
    dest[1] = el
    @inferred StructArrays.collect_to_structarray!(dest, itr, 2, st)

    v = [(a = 1, b = 2), (a = 1.2, b = 3)]
    @test collect_structarray_rec(v) == StructArray((a = [1, 1.2], b = Int[2, 3]))
    @test typeof(collect_structarray_rec(v)) == typeof(StructArray((a = Real[1, 1.2], b = Int[2, 3])))
    @test StructArray(v[i] for i in eachindex(v)) == StructArray((a = [1, 1.2], b = Int[2, 3]))

    s = StructArray(a = [1, 2], b  = [3, 4])
    @test collect_structarray(LazyRow(s, i) for i in eachindex(s)) == s
    @test collect_structarray_rec(LazyRow(s, i) for i in eachindex(s)) == s

    v = [(a = 1, b = 2), (a = 1.2, b = "3")]
    @test collect_structarray_rec(v) == StructArray((a = [1, 1.2], b = Any[2, "3"]))
    @test typeof(collect_structarray_rec(v)) == typeof(StructArray((a = Real[1, 1.2], b = Any[2, "3"])))

    v = [(a = 1, b = 2), (a = 1.2, b = 2), (a = 1, b = "3")]
    @test collect_structarray_rec(v) == StructArray((a = Real[1, 1.2, 1], b = Any[2, 2, "3"]))
    @test typeof(collect_structarray_rec(v)) == typeof(StructArray((a = Real[1, 1.2, 1], b = Any[2, 2, "3"])))

    # length unknown
    itr = Iterators.filter(isodd, 1:8)
    tuple_itr = ((a = i+1, b = i-1) for i in itr)
    @test collect_structarray_rec(tuple_itr) == StructArray((a = [2, 4, 6, 8], b = [0, 2, 4, 6]))
    tuple_itr_real = (i == 1 ? (a = 1.2, b =i-1) : (a = i+1, b = i-1) for i in itr)
    @test collect_structarray_rec(tuple_itr_real) == StructArray((a = Real[1.2, 4, 6, 8], b = [0, 2, 4, 6]))

    # empty
    itr = Iterators.filter(t -> t > 10, 1:8)
    tuple_itr = ((a = i+1, b = i-1) for i in itr)
    @test collect_structarray_rec(tuple_itr) == StructArray((a = Int[], b = Int[]))

    itr = (i for i in 0:-1)
    tuple_itr = ((a = i+1, b = i-1) for i in itr)
    @test collect_structarray_rec(tuple_itr) == StructArray((a = Int[], b = Int[]))
end

@testset "collecttuples" begin
    v = [(1, 2), (1, 3)]
    @test collect_structarray_rec(v) == StructArray((Int[1, 1], Int[2, 3]))
    @inferred collect_structarray_rec(v)

    @test collect_structarray(v) == StructArray((Int[1, 1], Int[2, 3]))
    @inferred collect_structarray(v)

    v = [(1, 2), (1.2, 3)]
    @test collect_structarray_rec(v) == StructArray((Real[1, 1.2], Int[2, 3]))

    v = [(1, 2), (1.2, "3")]
    @test collect_structarray_rec(v) == StructArray((Real[1, 1.2], Any[2, "3"]))
    @test typeof(collect_structarray_rec(v)) == typeof(StructArray((Real[1, 1.2], Any[2, "3"])))

    v = [(1, 2), (1.2, 2), (1, "3")]
    @test collect_structarray_rec(v) == StructArray((Real[1, 1.2, 1], Any[2, 2, "3"]))
    # length unknown
    itr = Iterators.filter(isodd, 1:8)
    tuple_itr = ((i+1, i-1) for i in itr)
    @test collect_structarray_rec(tuple_itr) == StructArray(([2, 4, 6, 8], [0, 2, 4, 6]))
    tuple_itr_real = (i == 1 ? (1.2, i-1) : (i+1, i-1) for i in itr)
    @test collect_structarray_rec(tuple_itr_real) == StructArray((Real[1.2, 4, 6, 8], [0, 2, 4, 6]))
    @test typeof(collect_structarray_rec(tuple_itr_real)) == typeof(StructArray((Real[1.2, 4, 6, 8], [0, 2, 4, 6])))

    # empty
    itr = Iterators.filter(t -> t > 10, 1:8)
    tuple_itr = ((i+1, i-1) for i in itr)
    @test collect_structarray_rec(tuple_itr) == StructArray((Int[], Int[]))

    itr = (i for i in 0:-1)
    tuple_itr = ((i+1, i-1) for i in itr)
    @test collect_structarray_rec(tuple_itr) == StructArray((Int[], Int[]))
end

@testset "collectscalars" begin
    v = (i for i in 1:3)
    @test collect_structarray_rec(v) == [1,2,3]
    @inferred collect_structarray_rec(v)

    v = (i == 1 ? 1.2 : i for i in 1:3)
    @test collect_structarray_rec(v) == collect(v)

    itr = Iterators.filter(isodd, 1:100)
    @test collect_structarray_rec(itr) == collect(itr)
    real_itr = (i == 1 ? 1.5 : i for i in itr)
    @test collect_structarray_rec(real_itr) == collect(real_itr)
    @test eltype(collect_structarray_rec(real_itr)) == Real

    #empty
    itr = Iterators.filter(t -> t > 10, 1:8)
    tuple_itr = (exp(i) for i in itr)
    @test collect_structarray_rec(tuple_itr) == Float64[]

    itr = (i for i in 0:-1)
    tuple_itr = (exp(i) for i in itr)
    @test collect_structarray_rec(tuple_itr) == Float64[]

    t = collect_structarray_rec((a = i,) for i in (1, missing, 3))
    @test StructArrays.components(t)[1] isa Array{Union{Int, Missing}}
    @test isequal(StructArrays.components(t)[1], [1, missing, 3])
end

pair_structarray((first, last)) = StructArray{Pair{eltype(first), eltype(last)}}((first, last))

@testset "collectpairs" begin
    v = (i=>i+1 for i in 1:3)
    @test collect_structarray_rec(v) == pair_structarray([1,2,3] => [2,3,4])
    @test eltype(collect_structarray_rec(v)) == Pair{Int, Int}

    v = (i == 1 ? (1.2 => i+1) : (i => i+1) for i in 1:3)
    @test collect_structarray_rec(v) == pair_structarray([1.2,2,3] => [2,3,4])
    @test eltype(collect_structarray_rec(v)) == Pair{Real, Int}

    v = ((a=i,) => (b="a$i",) for i in 1:3)
    @test collect_structarray_rec(v) == pair_structarray(StructArray((a = [1,2,3],)) => StructArray((b = ["a1","a2","a3"],)))
    @test eltype(collect_structarray_rec(v)) == Pair{NamedTuple{(:a,), Tuple{Int64}}, NamedTuple{(:b,), Tuple{String}}}

    v = (i == 1 ? (a="1",) => (b="a$i",) : (a=i,) => (b="a$i",) for i in 1:3)
    @test collect_structarray_rec(v) == pair_structarray(StructArray((a = ["1",2,3],)) => StructArray((b = ["a1","a2","a3"],)))
    @test eltype(collect_structarray_rec(v)) == Pair{NamedTuple{(:a,), Tuple{Any}}, NamedTuple{(:b,), Tuple{String}}}

    # empty
    v = ((a=i,) => (b="a$i",) for i in 0:-1)
    @test collect_structarray_rec(v) == pair_structarray(StructArray((a = Int[],)) => StructArray((b = String[],)))
    @test eltype(collect_structarray_rec(v)) == Pair{NamedTuple{(:a,), Tuple{Int}}, NamedTuple{(:b,), Tuple{String}}}

    v = Iterators.filter(t -> t.first.a == 4, ((a=i,) => (b="a$i",) for i in 1:3))
    @test collect_structarray_rec(v) == pair_structarray(StructArray((a = Int[],)) => StructArray((b = String[],)))
    @test eltype(collect_structarray_rec(v)) == Pair{NamedTuple{(:a,), Tuple{Int}}, NamedTuple{(:b,), Tuple{String}}}

    t = collect_structarray_rec((b = 1,) => (a = i,) for i in (2, missing, 3))
    s = pair_structarray(StructArray(b = [1,1,1]) => StructArray(a = [2, missing, 3]))
    @test s[1] == t[1]
    @test ismissing(t[2].second.a)
    @test s[3] == t[3]
end

@testset "collect2D" begin
    s = ((a=i, b=j) for i in 1:3, j in 1:4)
    v = collect_structarray(s)
    @test size(v) == (3, 4)
    @test eltype(v) == @NamedTuple{a::Int, b::Int}
    @test v.a == [i for i in 1:3, j in 1:4]
    @test v.b == [j for i in 1:3, j in 1:4]

    s = (i == 1 ? (a=nothing, b=j) : (a=i, b=j) for i in 1:3, j in 1:4)
    v = collect_structarray(s)
    @test size(v) == (3, 4)
    @test eltype(v) == @NamedTuple{a::Union{Int, Nothing}, b::Int}
    @test v.a == [i == 1 ? nothing : i for i in 1:3, j in 1:4]
    @test v.b == [j for i in 1:3, j in 1:4]
end

@testset "collectoffset" begin
    s = OffsetArray([(a=1,) for i in 1:10], -3)
    sa = StructArray(s)
    @test sa isa StructArray
    @test axes(sa) == (-2:7,)
    @test sa.a == fill(1, -2:7)

    sa = StructArray(i for i in s)
    @test sa isa StructArray
    @test axes(sa) == (-2:7,)
    @test sa.a == fill(1, -2:7)

    zero_origin(T, d) = OffsetArray{T}(undef, map(r -> r .- 1, d))
    sa = collect_structarray(
        [(a = 1,), (a = 2,), (a = 3,)],
        initializer = StructArrays.StructArrayInitializer(t -> false, zero_origin),
    )
    @test sa isa StructArray
    @test collect(sa.a) == 1:3
    @test sa.a isa OffsetArray

    sa = collect_structarray(
        (x for x in [(a = 1,), (a = 2,), (a = 3,)] if true),
        initializer = StructArrays.StructArrayInitializer(t -> false, zero_origin),
    )
    @test sa isa StructArray
    @test collect(sa.a) == 1:3
    @test sa.a isa OffsetArray
end

@testset "collectstructarrays" begin
    s = StructArray(a = rand(10), b = rand(10))
    t = StructArray(a = rand(10), b = rand(10))
    v = StructArray([s, t])
    @test v.a[1] == s.a
    @test v.a[2] == t.a
    @test v.b[1] == s.b
    @test v.b[2] == t.b
    @test v[1] == s
    @test v[2] == t

    s = LazyRows(StructArray(a = rand(10), b = rand(10)))
    t = LazyRows(StructArray(a = rand(10), b = rand(10)))
    v = StructArray([s, t])
    @test v.a[1] == s.a
    @test v.a[2] == t.a
    @test v.b[1] == s.b
    @test v.b[2] == t.b
    @test v[1] == s
    @test v[2] == t
end

@testset "hasfields" begin
    @test StructArrays.hasfields(ComplexF64)
    @test !StructArrays.hasfields(Any)
    @test StructArrays.hasfields(Tuple{Union{Int, Missing}})
    @test StructArrays.hasfields(typeof((a=1,)))
    @test !StructArrays.hasfields(NamedTuple)
    @test !StructArrays.hasfields(Tuple{Int, Vararg{Int, N}} where {N})
    @test StructArrays.hasfields(Missing)
    @test !StructArrays.hasfields(Union{Tuple{Int}, Missing})
    @test StructArrays.hasfields(Nothing)
    @test !StructArrays.hasfields(Union{Tuple{Int}, Nothing})
end

@testset "reshape" begin
    s = StructArray(a=[1,2,3,4], b=["a","b","c","d"])

    rs = reshape(s, (2, 2))
    @test rs.a == [1 3; 2 4]
    @test rs.b == ["a" "c"; "b" "d"]

    rs = reshape(s, (:,))
    @test rs.a == s.a
    @test rs.b == s.b

    rs = reshape(s, (2, :))
    @test rs.a == [1 3; 2 4]
    @test rs.b == ["a" "c"; "b" "d"]

    rs = reshape(s, (2, Base.OneTo(2)))
    @test rs.a == [1 3; 2 4]
    @test rs.b == ["a" "c"; "b" "d"]

    rs = reshape(s, (0:1, :))
    @test rs.a == OffsetArray([1 3; 2 4], (-1, 0))
    @test rs.b == OffsetArray(["a" "c"; "b" "d"], (-1, 0))

    rs = reshape(s, (0:1, 1:2))
    @test rs.a == OffsetArray([1 3; 2 4], (-1, 0))
    @test rs.b == OffsetArray(["a" "c"; "b" "d"], (-1, 0))
end

@testset "lazy" begin
    s = StructArray{ComplexF64}((rand(10, 10), view(rand(100, 100), 1:10, 1:10)))
    rows = LazyRows(s)
    @test propertynames(rows) == (:re, :im)
    @test propertynames(rows[1]) == (:re, :im)
    @test staticschema(eltype(rows)) == staticschema(ComplexF64)
    @test getproperty(rows, 1) isa Matrix{Float64}
    @test getproperty(rows, :re) isa Matrix{Float64}
    @test IndexStyle(rows) isa IndexCartesian
    @test IndexStyle(typeof(rows)) isa IndexCartesian
    @test all(t -> t.re >= 0, s)
    @test all(t -> t.re >= 0, rows)
    rows[13].re = -12
    rows[13].im = 0

    s = StructArray(rand(ComplexF64, 10, 10))
    rows = LazyRows(s)
    @test propertynames(rows) == (:re, :im)
    @test propertynames(rows[1]) == (:re, :im)
    @test staticschema(eltype(rows)) == staticschema(ComplexF64)
    @test getproperty(rows, 1) isa Matrix{Float64}
    @test getproperty(rows, :re) isa Matrix{Float64}
    @test IndexStyle(rows) isa IndexLinear
    @test IndexStyle(typeof(rows)) isa IndexLinear
    @test all(t -> t.re >= 0, s)
    @test all(t -> t.re >= 0, rows)
    rows[13].re = -12
    rows[13].im = 0
    @test !all(t -> t.re >= 0, s)
    @test !all(t -> t.re >= 0, rows)

    @test !all(t -> t.re >= 0, s)
    @test !all(t -> t.re >= 0, rows)
    io = IOBuffer()
    show(io, rows[13])
    str = String(take!(io))
    @test str == "LazyRow(re = -12.0, im = 0.0)"

    io = IOBuffer()
    Base.showarg(io, rows, true)
    str = String(take!(io))
    if VERSION < v"1.6-"
        @test str == "LazyRows(::Array{Float64,2}, ::Array{Float64,2}) with eltype LazyRow{Complex{Float64}}"
    else
        @test str == "LazyRows(::Matrix{Float64}, ::Matrix{Float64}) with eltype LazyRow{ComplexF64}"
    end
    io = IOBuffer()
    Base.showarg(io, rows, false)
    str = String(take!(io))
    if VERSION < v"1.6-"
        @test str == "LazyRows(::Array{Float64,2}, ::Array{Float64,2})"
    else
        @test str == "LazyRows(::Matrix{Float64}, ::Matrix{Float64})"
    end
    s = StructArray((rand(10, 10), rand(10, 10)))
    rows = LazyRows(s)
    @test IndexStyle(rows) isa IndexLinear
    @test IndexStyle(typeof(rows)) isa IndexLinear
    @test all(t -> Tables.getcolumn(t, 1) >= 0, s)
    @test all(t -> getproperty(t, 1) >= 0, rows)
    setproperty!(rows[13], 1, -12)
    setproperty!(rows[13], 2, 0)
    @test !all(t -> Tables.getcolumn(t, 1) >= 0, s)
    @test !all(t -> getproperty(t, 1) >= 0, rows)

    io = IOBuffer()
    show(io, rows[13])
    str = String(take!(io))
    @test str == "LazyRow(-12.0, 0.0)"

    io = IOBuffer()
    Base.showarg(io, rows, true)
    str = String(take!(io))
    if VERSION < v"1.6-"
        @test str == "LazyRows(::Array{Float64,2}, ::Array{Float64,2}) with eltype LazyRow{Tuple{Float64,Float64}}"
    else
        @test str == "LazyRows(::Matrix{Float64}, ::Matrix{Float64}) with eltype LazyRow{Tuple{Float64, Float64}}"
    end
    io = IOBuffer()
    Base.showarg(io, rows, false)
    str = String(take!(io))
    if VERSION < v"1.6-"
        @test str == "LazyRows(::Array{Float64,2}, ::Array{Float64,2})"
    else
        @test str == "LazyRows(::Matrix{Float64}, ::Matrix{Float64})"
    end
end

@testset "refarray" begin
    s = PooledArrays.PooledArray(["a", "b", "c", "c"])
    @test refarray(s) == UInt8.([1, 2, 3, 3])

    s = WeakRefStrings.StringArray(["a", "b"])
    @test refarray(s) isa WeakRefStrings.StringArray{WeakRefStrings.WeakRefString{UInt8}}
    @test all(isequal.(s, refarray(s)))
    s = WeakRefStrings.StringArray(["a", missing])
    @test refarray(s) isa WeakRefStrings.StringArray{Union{WeakRefStrings.WeakRefString{UInt8}, Missing}}
    @test all(isequal.(s, refarray(s)))
    a = WeakRefStrings.StringVector(["a", "b", "c"])
    b = PooledArrays.PooledArray(["1", "2", "3"])
    c = [:a, :b, :c]
    s = StructArray(a=a, b=b, c=c)
    ref = refarray(s)
    @test ref[1].a isa WeakRefStrings.WeakRefString{UInt8}
    @test ref[1].b isa Integer
    for i in 1:3
        @test refvalue(s, ref[i]) == s[i]
    end
end

@testset "show" begin
    s = StructArray(Complex{Int64}[1+im, 2-im])
    io = IOBuffer()
    Base.showarg(io, s, true)
    str = String(take!(io))
    if VERSION < v"1.6-"
        @test str == "StructArray(::Array{Int64,1}, ::Array{Int64,1}) with eltype Complex{Int64}"
    else
        @test str == "StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Complex{Int64}"
    end
    io = IOBuffer()
    Base.showarg(io, s, false)
    str = String(take!(io))
    if VERSION < v"1.6-"
        @test str == "StructArray(::Array{Int64,1}, ::Array{Int64,1})"
    else
        @test str == "StructArray(::Vector{Int64}, ::Vector{Int64})"
    end
end

@testset "append!!" begin
    dest_examples = [
        ("mutate", StructVector(a = [1], b = [2])),
        ("widen", StructVector(a = [1], b = [nothing])),
    ]
    itr = [(a = 1, b = 2), (a = 1, b = 2), (a = 1, b = 12)]
    itr_examples = [
        ("HasLength", () -> itr),
        ("StructArray", () -> StructArray(itr)),
        ("SizeUnknown", () -> (x for x in itr if isodd(x.a))),
        # Broken due to https://github.com/JuliaArrays/StructArrays.jl/issues/100:
        # ("empty", (x for x in itr if false)),
        ("stateful", () -> Iterators.Stateful(itr)),
    ]
    @testset "$destlabel $itrlabel" for (destlabel, dest) in dest_examples,
                                        (itrlabel, makeitr) in itr_examples

        @test vcat(dest, StructVector(makeitr())) == append!!(copy(dest), makeitr())
    end
end

@testset "sparse" begin
    @testset "Vector" begin
        v = [1,0,2]
        sv = StructArray{Complex{Int}}((v, v))
        spv = @inferred sparse(sv)
        @test spv isa SparseVector{eltype(sv)}
        @test spv == sv
    end
    @testset "Matrix" begin
        d = Diagonal(Float64[1:4;])
        sa = StructArray{ComplexF64}((d, d))
        sp = @inferred sparse(sa)
        @test sp isa SparseMatrixCSC{eltype(sa)}
        @test sp == sa
    end
end

struct ArrayConverter end

Adapt.adapt_storage(::ArrayConverter, xs::AbstractArray) = convert(Array, xs)

@testset "adapt" begin
    s = StructArray(a = 1:10, b = StructArray(c = 1:10, d = 1:10))
    t = adapt(ArrayConverter(), s)
    @test propertynames(t) == (:a, :b)
    @test s == t
    @test t.a isa Array
    @test t.b.c isa Array
    @test t.b.d isa Array
end

# The following code defines `MyArray1/2/3` with different `BroadcastStyle`s.
# 1. `MyArray1` and `MyArray1` have `similar` defined.
#     We use them to simulate `BroadcastStyle` overloading `Base.copyto!`.
# 2. `MyArray3` has no `similar` defined. 
#    We use it to simulate `BroadcastStyle` overloading `Base.copy`.
# 3. Their resolved style could be summaryized as (`-` means conflict)
#              |  MyArray1  |  MyArray2  |  MyArray3  |  Array
#    -------------------------------------------------------------
#    MyArray1  |  MyArray1  |      -     |  MyArray1  |  MyArray1
#    MyArray2  |      -     |  MyArray2  |      -     |  MyArray2
#    MyArray3  |  MyArray1  |      -     |  MyArray3  |  MyArray3
#    Array     |  MyArray1  |  Array     |  MyArray3  |  Array

for S in (1, 2, 3)
    MyArray = Symbol(:MyArray, S)
    @eval begin
        struct $MyArray{T,N} <: AbstractArray{T,N}
            A::Array{T,N}
        end
        $MyArray{T}(::UndefInitializer, sz::Dims) where T = $MyArray(Array{T}(undef, sz))
        Base.IndexStyle(::Type{<:$MyArray}) = IndexLinear()
        Base.getindex(A::$MyArray, i::Int) = A.A[i]
        Base.setindex!(A::$MyArray, val, i::Int) = A.A[i] = val
        Base.size(A::$MyArray) = Base.size(A.A)
        Base.BroadcastStyle(::Type{<:$MyArray}) = Broadcast.ArrayStyle{$MyArray}()
        StructArrays.always_struct_broadcast(::Broadcast.ArrayStyle{$MyArray}) = true
    end
end
Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{MyArray1}}, ::Type{ElType}) where ElType =
    MyArray1{ElType}(undef, size(bc))
Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{MyArray2}}, ::Type{ElType}) where ElType =
    MyArray2{ElType}(undef, size(bc))
Base.BroadcastStyle(::Broadcast.ArrayStyle{MyArray1}, ::Broadcast.ArrayStyle{MyArray3}) = Broadcast.ArrayStyle{MyArray1}()
Base.BroadcastStyle(::Broadcast.ArrayStyle{MyArray2}, S::Broadcast.DefaultArrayStyle) = S

@testset "broadcast" begin
    s = StructArray{ComplexF64}((rand(2,2), rand(2,2)))
    @test isa(@inferred(s .+ s), StructArray)
    @test (s .+ s).re == 2*s.re
    @test (s .+ s).im == 2*s.im
    @test isa(@inferred(broadcast(t->1, s)), Array)
    @test all(x->x==1, broadcast(t->1, s))
    @test isa(@inferred(s .+ 1), StructArray)
    @test s .+ 1 == StructArray{ComplexF64}((s.re .+ 1, s.im))
    r = rand(2,2)
    @test isa(@inferred(s .+ r), StructArray)
    @test s .+ r == StructArray{ComplexF64}((s.re .+ r, s.im))

    # used inside of broadcast but we also test it here explicitly
    @test isa(@inferred(Base.dataids(s)), NTuple{N, UInt} where {N})


    @testset "style conflict check" begin
        using StructArrays: StructArrayStyle
        # Make sure we can handle style with similar defined
        # And we can handle most conflicts
        # `s1` and `s2` have similar defined, but `s3` does not
        # `s2` conflicts with `s1` and `s3` and is weaker than `DefaultArrayStyle`
        s1 = StructArray{ComplexF64}((MyArray1(rand(2)), MyArray1(rand(2))))
        s2 = StructArray{ComplexF64}((MyArray2(rand(2)), MyArray2(rand(2))))
        s3 = StructArray{ComplexF64}((MyArray3(rand(2)), MyArray3(rand(2))))
        s4 = StructArray{ComplexF64}((rand(2), rand(2)))
        test_set = Any[s1, s2, s3, s4]
        tested_style = Any[]
        dotaddadd((a, b, c),) = @. a + b + c
        for as in Iterators.product(test_set, test_set, test_set)
            ares = map(a->a.re, as)
            aims = map(a->a.im, as)
            style = Broadcast.combine_styles(ares...)
            @test Broadcast.combine_styles(as...) === StructArrayStyle{typeof(style),1}()
            if !(style in tested_style)
                push!(tested_style, style)
                if style isa Broadcast.ArrayStyle{MyArray3}
                    @test_throws MethodError dotaddadd(as)
                else
                    d = StructArray{ComplexF64}((dotaddadd(ares), dotaddadd(aims)))
                    @test @inferred(dotaddadd(as))::typeof(d) == d
                end
            end
        end
        @test length(tested_style) == 5
    end
    # test for dimensionality track
    s = StructArray{ComplexF64}((MyArray1(rand(2)), MyArray1(rand(2))))
    @test Base.broadcasted(+, s, s) isa Broadcast.Broadcasted{<:Broadcast.AbstractArrayStyle{1}}
    @test Base.broadcasted(+, s, 1:2) isa Broadcast.Broadcasted{<:Broadcast.AbstractArrayStyle{1}}
    @test Base.broadcasted(+, s, reshape(1:2,1,2)) isa Broadcast.Broadcasted{<:Broadcast.AbstractArrayStyle{2}}
    @test Base.broadcasted(+, reshape(1:2,1,1,2), s) isa Broadcast.Broadcasted{<:Broadcast.AbstractArrayStyle{3}}
    @test Base.broadcasted(+, s, MyArray1(rand(2))) isa Broadcast.Broadcasted{<:Broadcast.AbstractArrayStyle{Any}}

    #parent_style
    @test StructArrays.parent_style(StructArrayStyle{Broadcast.DefaultArrayStyle{0},2}()) == Broadcast.DefaultArrayStyle{2}
    @test StructArrays.parent_style(StructArrayStyle{Broadcast.Style{Tuple},2}()) == Broadcast.Style{Tuple}

    # allocation test for overloaded `broadcast_unalias`
    StructArrays.always_struct_broadcast(::Broadcast.ArrayStyle{MyArray1}) = false
    f(s) = s .+= 1
    f(s)
    @test (@allocated f(s)) == 0
    
    # issue #185
    A = StructArray(randn(ComplexF64, 3, 3))
    B = randn(ComplexF64, 3, 3)
    c = StructArray(randn(ComplexF64, 3))
    A .= B .* c
    @test @inferred(B .* c) == A == B .* collect(c)

    # issue #189
    v = StructArray([(a="s1",), (a="s2",)])
    @test @inferred(broadcast(el -> el.a, v)) == ["s1", "s2"]

    @test identity.(StructArray(x=StructArray(a=1:3)))::StructArray == [(x=(a=1,),), (x=(a=2,),), (x=(a=3,),)]
    @test (x -> x.x.a).(StructArray(x=StructArray(a=1:3))) == [1, 2, 3]
    @test identity.(StructArray(x=StructArray(x=StructArray(a=1:3))))::StructArray == [(x=(x=(a=1,),),), (x=(x=(a=2,),),), (x=(x=(a=3,),),)]
    @test (x -> x.x.x.a).(StructArray(x=StructArray(x=StructArray(a=1:3)))) == [1, 2, 3]

    @testset "ambiguity check" begin
        test_set = Any[StructArray([1;2+im]),
                    1:2, 
                    (1,2),
                    StructArray(@SArray [1;1+2im]),
                    (@SArray [1 2]),
                    1]
        tested_style = StructArrayStyle[]
        dotaddsub((a, b, c),) = @. a + b - c
        for as in Iterators.product(test_set, test_set, test_set)
            if any(a -> a isa StructArray, as)
                style = Broadcast.combine_styles(as...)
                if !(style in tested_style)
                    push!(tested_style, style)
                    @test @inferred(dotaddsub(as))::StructArray == dotaddsub(map(collect, as))
                end
            end
        end
        @test length(tested_style) == 4
    end

    @testset "allocation test" begin
        a = StructArray{ComplexF64}(undef, 1)
        sa = StructArray{ComplexF64}((SizedVector{1}(a.re), SizedVector{1}(a.re)))
        allocated(a) = @allocated  a .+ 1
        @test allocated(a) == 2allocated(a.re)
        @test allocated(sa) == 2allocated(sa.re)
        allocated2(a) = @allocated a .= complex.(a.im, a.re)
        @test allocated2(a) == 0
    end

    @testset "StructStaticArray" begin
        bclog(s) = log.(s)
        test_allocated(f, s) = @test (@allocated f(s)) == 0
        a = @SMatrix [float(i) for i in 1:10, j in 1:10]
        b = @SMatrix [0. for i in 1:10, j in 1:10]
        s = StructArray{ComplexF64}((a , b))
        @test (@inferred bclog(s)) isa typeof(s)
        s0 = StructArray{ComplexF64}((similar(a, Size(0,0)), similar(a, Size(0,0))))
        @test (@inferred bclog(s0)) isa typeof(s0)
        test_allocated(bclog, s)
        @test abs.(s) .+ ((1,) .+ (1,2,3,4,5,6,7,8,9,10)) isa SMatrix
        bc = Base.broadcasted(+, s, s, ntuple(identity, 10));
        bc = Base.broadcasted(+, bc, bc, s);
        @test @inferred(Broadcast.axes(bc)) === axes(s)
    end

    @testset "StructJLArray" begin
        bcabs(a) = abs.(a)
        bcmul2(a) = 2 .* a
        a = StructArray(randn(ComplexF32, 10, 10))
        sa = jl(a)
        @test sa isa StructArray
        @test @inferred(backend(sa)) === backend(sa.re) === backend(sa.im) === backend(jl(a.re))
        @test collect(@inferred(bcabs(sa))) == bcabs(a)
        @test backend(bcabs(sa)) === backend(sa)
        @test @inferred(bcmul2(sa)) isa StructArray
        @test backend(bcmul2(sa)) === backend(sa)
        @test (sa .+= 1) === sa
    end

    @testset "StructSparseArray" begin
        a = sprand(10, 10, 0.5)
        b = sprand(10, 10, 0.5)
        c = StructArray{ComplexF64}((a, b))
        d = identity.(c)
        @test d isa SparseMatrixCSC
    end
end

@testset "map" begin
    s = StructArray(a=[1, 2, 3])

    t = @inferred(map(x -> x, s))
    @test t isa StructArray
    @test t == s

    t = @inferred(map(x -> x.a, s))
    @test t isa Vector
    @test t == [1, 2, 3]

    t = map(x -> (a=x.a,), StructVector(a=[1, missing]))::StructVector
    @test isequal(t.a, [1, missing])
    @test eltype(t) <: NamedTuple{(:a,)}
    t = map(x -> (a=rand(["", 1, nothing]),), StructVector(a=1:10))::StructVector
    @test eltype(t) <: NamedTuple{(:a,)}

    t = VERSION >= v"1.7" ? @inferred(map(x -> (a=x.a, b=2), s)) : map(x -> (a=x.a, b=2), s)
    @test t isa StructArray
    @test map(x -> (a=x.a, b=2), s) == [(a=1, b=2), (a=2, b=2), (a=3, b=2)]

    so = reshape(s, Base.IdentityUnitRange(11:13))
    to = @inferred(map(x -> x, so))
    @test to isa StructArray
    @test axes(to) == axes(so)
    @test to == so
end

@testset "staticarrays" begin
    # test that staticschema returns the right things
    for StaticVectorType = [SVector, MVector, SizedVector]
        @test StructArrays.staticschema(StaticVectorType{2,Float64}) == Tuple{Float64,Float64}
    end

    # test broadcast + components for vectors
    for StaticVectorType = [SVector, MVector, SizedVector]
        x = @inferred StructArray([StaticVectorType{2}(Float64[i;i+1]) for i = 1:2])
        y = @inferred StructArray([StaticVectorType{2}(Float64[i+1;i+2]) for i = 1:2])
        @test StructArrays.components(x) == ([1.0,2.0], [2.0,3.0])
        @test x .+ y == StructArray([StaticVectorType{2}(Float64[2*i+1;2*i+3]) for i = 1:2])
    end
    for StaticVectorType = [SVector, MVector]
        x = @inferred StructArray([StaticVectorType{2}(Float64[i;i+1]) for i = 1:2])
        # numbered and named property access:
        @test x.:1 == [1.0,2.0]
        @test x.y == [2.0,3.0]
    end
    # test broadcast + components for general arrays
    for StaticArrayType = [SArray, MArray, SizedArray]
        x = @inferred StructArray([StaticArrayType{Tuple{1,2}}(ones(1,2) .+ i) for i = 0:1])
        y = @inferred StructArray([StaticArrayType{Tuple{1,2}}(2*ones(1,2) .+ i) for i = 0:1])
        @test StructArrays.components(x) == ([1., 2.], [1., 2.])
        @test x .+ y == StructArray([StaticArrayType{Tuple{1,2}}(3*ones(1,2) .+ 2*i) for i = 0:1])
    end

    # test FieldVector constructor (see https://github.com/JuliaArrays/StructArrays.jl/issues/205)
    struct FlippedVec2D <: FieldVector{2,Float64}
        x::Float64
        y::Float64
    end
    # tuple constructors should respect the flipped ordering
    FlippedVec2D(t::Tuple) = FlippedVec2D(t[2], t[1])

    # define a custom getindex to test StructArrays.component(::FieldArray) behavior
    Base.getindex(a::FlippedVec2D, index::Int) = index==1 ? a.y : a.x
    Base.Tuple(a::FlippedVec2D) = (a.y, a.x)
    a = StructArray([FlippedVec2D(1.0,2.0)])
    @test a.x == [1.0]
    @test a.y == [2.0]
    @test a.x[1] == a[1].x

    # test custom indices and components
    @test typeof(StructArrays.components(a)) == NamedTuple{(:x, :y), NTuple{2, Vector{Float64}}}
    @test StructArrays.components(a) == (; x = [1.0], y = [2.0])

    # test type stability of creating views with "many" homogeneous components
    for n in 1:10
        u = StructArray(randn(SVector{n, Float64}) for _ in 1:10, _ in 1:5)
        @inferred view(u, :, 1)
        @inferred view(u, 1, :)
    end
end

# Test fallback (non-@generated) variant of map_params
@testset "map_params" begin
    v = StructArray(rand(ComplexF64, 2, 2))
    f(T) = similar(v, T)

    types = Tuple{Int, Float64, ComplexF32, String}
    namedtypes = NamedTuple{(:a, :b, :c, :d), types}
    A = @inferred StructArrays.map_params_as_tuple(f, types)
    B = StructArrays.map_params_as_tuple_fallback(f, types)
    C = @inferred StructArrays.map_params_as_tuple(f, namedtypes)
    D = StructArrays.map_params_as_tuple_fallback(f, namedtypes)
    @test typeof(A) === typeof(B) === typeof(C) === typeof(D)

    types = Tuple{Int, Float64, ComplexF32}
    A = map(zero, fieldtypes(types))
    B = @inferred StructArrays.map_params(zero, types)
    C = StructArrays.map_params_as_tuple(zero, types)
    D = StructArrays.map_params_as_tuple_fallback(zero, types)
    @test A === B === C === D

    namedtypes = NamedTuple{(:a, :b, :c), types}
    A = map(zero, NamedTuple{(:a, :b, :c)}(map(zero, fieldtypes(types))))
    B = @inferred StructArrays.map_params(zero, namedtypes)
    C = StructArrays.map_params_as_tuple(zero, types)
    D = StructArrays.map_params_as_tuple_fallback(zero, types)
    @test A === B
    @test Tuple(A) === C === D

    nonconcretenamedtypes = NamedTuple{(:a, :b, :c)}
    A = map(f, NamedTuple{(:a, :b, :c)}((Any, Any, Any)))
    B = @inferred StructArrays.map_params(f, nonconcretenamedtypes)
    C = StructArrays.map_params_as_tuple(f, nonconcretenamedtypes)
    D = StructArrays.map_params_as_tuple_fallback(f, nonconcretenamedtypes)
    @test typeof(A) === typeof(B)
    @test typeof(Tuple(A)) === typeof(C) === typeof(D)
end

@testset "OffsetArray zero" begin
    s = StructArray{ComplexF64}((rand(2), rand(2)))
    soff = OffsetArray(s, 0:1)
    @test isa(parent(zero(soff)), StructArray)
end

# issue #230
@testset "StaticArray zero" begin
    u = StructArray([SVector(1.0)])
    @test zero(u) == StructArray([SVector(0.0)])
    @test typeof(zero(u)) == typeof(StructArray([SVector(0.0)]))
end

@testset "parametric type" begin
    struct PS{A, B}
        a::A
        b::B
    end

    xs = StructArray([(a=1, b=2), (a=3, b=nothing)])
    ss = map(x -> PS(x.a, x.b), xs)
    @test ss == [PS(1, 2), PS(3, nothing)]
end

@testset "IteratorSize" begin
    S = StructArray{ComplexF64}((zeros(1), zeros(1)))
    @test Base.IteratorSize(S) == Base.HasShape{1}()
    S = StructArray{ComplexF64}((zeros(1,2), zeros(1,2)))
    @test Base.IteratorSize(S) == Base.HasShape{2}()
    S = StructArray{Complex{Int}}((1:∞, 1:∞))
    @test Base.IteratorSize(S) == Base.IsInfinite()
end
