using StructArrays
import Tables, PooledArrays, WeakRefStrings
using Test

@testset "index" begin
    a, b = [1 2; 3 4], [4 5; 6 7]
    t = StructArray((a = a, b = b))
    @test (@inferred t[2,2]) == (a = 4, b = 7)
    @test (@inferred t[2,1:2]) == StructArray((a = [3, 4], b = [6, 7]))
    @test_throws BoundsError t[3,3]
    @test (@inferred view(t, 2, 1:2)) == StructArray((a = view(a, 2, 1:2), b = view(b, 2, 1:2)))
end

@testset "fieldarrays" begin
    t = StructArray(a = 1:10, b = rand(Bool, 10))
    @test StructArrays.propertynames(t) == (:a, :b)
    @test StructArrays.propertynames(StructArrays.fieldarrays(t)) == (:a, :b)
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
    @test v_pooled == StructArrays.pool(v)
    s = WeakRefStrings.StringArray(["a", "b", "c"])
    @test StructArrays.pool(s) isa PooledArrays.PooledArray{String}
    @test StructArrays.pool(s)[1] == "a"
    @test StructArrays.pool(s)[2] == "b"
    @test StructArrays.pool(s)[3] == "c"
    @test StructArrays.pool(StructArrays.pool(s)) == StructArrays.pool(s)
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

@testset "namedtuple" begin
    @inferred StructArrays.to_namedtuple(1+2im)
    @test StructArrays.to_namedtuple(1+2im) == (re = 1, im = 2)
    @test StructArrays.to_namedtuple((a=1,)) == (a=1,)
    @test StructArrays.to_namedtuple((1, 2, :s)) == (x1=1, x2=2, x3=:s)
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

@testset "groupjoin" begin
    a = [1, 2, 1, 1, 0, 9, -100]
    b = [-2, 12, 1, 1, 0, 11, 9]
    itr = StructArrays.GroupJoinPerm(a, b)
    s = StructArray(itr)
    as, bs = fieldarrays(s)
    @test as == [1:1, 1:0, 2:2, 3:5, 6:6, 7:7, 1:0, 1:0]
    @test bs == [1:0, 1:1, 2:2, 3:4, 1:0, 5:5, 6:6, 7:7]
end

@testset "similar" begin
    t = StructArray(a = rand(10), b = rand(Bool, 10))
    s = similar(t)
    @test eltype(s) == NamedTuple{(:a, :b), Tuple{Float64, Bool}}
    @test size(s) == (10,)
    t = StructArray(a = rand(10, 2), b = rand(Bool, 10, 2))
    s = similar(t, 3, 5)
    @test eltype(s) == NamedTuple{(:a, :b), Tuple{Float64, Bool}}
    @test size(s) == (3, 5)
    s = similar(t, (3, 5))
    @test eltype(s) == NamedTuple{(:a, :b), Tuple{Float64, Bool}}
    @test size(s) == (3, 5)
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
end

@testset "kwargs constructor" begin
    a = [1.2]
    b = [2.3]
    @test StructArray(a=a, b=b) == StructArray((a=a, b=b))
    @test StructArray{ComplexF64}(re=a, im=b) == StructArray{ComplexF64}((a, b))
    f1() = StructArray(a=[1.2], b=["test"])
    f2() = StructArray{Pair}(first=[1.2], second=["test"])
    t1 = @inferred f1()
    t2 = @inferred f2()
    @test t1 == StructArray((a=[1.2], b=["test"]))
    @test t2 == StructArray{Pair}(([1.2], ["test"]))
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
    t = StructArray{Pair}(([3, 5], ["a", "b"]))
    resize!(t, 5)
    @test length(t) == 5
    p = 1 => "c"
    t[5] = p
    @test t[5] == p
end

@testset "concat" begin
    t = StructArray{Pair}(([3, 5], ["a", "b"]))
    push!(t, (2 => "c"))
    @test t == StructArray{Pair}(([3, 5, 2], ["a", "b", "c"]))
    append!(t, t)
    @test t == StructArray{Pair}(([3, 5, 2, 3, 5, 2], ["a", "b", "c", "a", "b", "c"]))
    t = StructArray{Pair}(([3, 5], ["a", "b"]))
    t2 = StructArray{Pair}(([1, 6], ["a", "b"]))
    @test cat(t, t2; dims=1)::StructArray == StructArray{Pair}(([3, 5, 1, 6], ["a", "b", "a", "b"])) == vcat(t, t2)
    @test vcat(t, t2) isa StructArray
    @test cat(t, t2; dims=2)::StructArray == StructArray{Pair}(([3 1; 5 6], ["a" "a"; "b" "b"])) == hcat(t, t2)
    @test hcat(t, t2) isa StructArray
end

f_infer() = StructArray{ComplexF64}((rand(2,2), rand(2,2)))

g_infer() = StructArray([(a=(b="1",), c=2)], unwrap = t -> t <: NamedTuple)
tup_infer() = StructArray([(1, 2), (3, 4)])
cols_infer() = StructArray(([1, 2], [1.2, 2.3]))

@testset "inferrability" begin
    @inferred f_infer()
    @inferred g_infer()
    @test g_infer().a.b == ["1"]
    s = @inferred tup_infer()
    @test Tables.columns(s) == (x1 = [1, 3], x2 = [2, 4])
    @test s[1] == (1, 2)
    @test s[2] == (3, 4)
    @inferred cols_infer()
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
    @test Tables.rowaccess(s)
    @test Tables.columnaccess(s)
end

struct S
    x::Int
    y::Float64
    S(x) = new(x, x)
end

StructArrays.SkipConstructor(::Type{<:S}) = true

@testset "inner" begin
    v = StructArray{S}(([1], [1]))
    @test v[1] == S(1)
    @test v[1].y isa Float64
end

@testset "default_array" begin
    v = StructArrays.default_array(Missing, (2,))
    @test v isa Array{Missing, 1}
    v = StructArrays.default_array(Int, (2,))
    @test v isa Array{Int, 1}
end

const initializer = StructArrays.ArrayInitializer(t -> t <: Union{Tuple, NamedTuple, Pair})
collect_structarray_rec(t) = collect_structarray(t, initializer = initializer)

@testset "collectnamedtuples" begin
    v = [(a = 1, b = 2), (a = 1, b = 3)]
    collect_structarray_rec(v) == StructArray((a = Int[1, 1], b = Int[2, 3]))

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
    @test StructArrays.fieldarrays(t)[1] isa Array{Union{Int, Missing}}
    @test isequal(StructArrays.fieldarrays(t)[1], [1, missing, 3])
end

@testset "collectpairs" begin
    v = (i=>i+1 for i in 1:3)
    @test collect_structarray_rec(v) == StructArray{Pair{Int, Int}}(([1,2,3], [2,3,4]))
    @test eltype(collect_structarray_rec(v)) == Pair{Int, Int}

    v = (i == 1 ? (1.2 => i+1) : (i => i+1) for i in 1:3)
    @test collect_structarray_rec(v) == StructArray{Pair{Real, Int}}(([1.2,2,3], [2,3,4]))
    @test eltype(collect_structarray_rec(v)) == Pair{Real, Int}

    v = ((a=i,) => (b="a$i",) for i in 1:3)
    @test collect_structarray_rec(v) == StructArray(StructArray((a = [1,2,3],)) => StructArray((b = ["a1","a2","a3"],)))
    @test eltype(collect_structarray_rec(v)) == Pair{NamedTuple{(:a,), Tuple{Int64}}, NamedTuple{(:b,), Tuple{String}}}

    v = (i == 1 ? (a="1",) => (b="a$i",) : (a=i,) => (b="a$i",) for i in 1:3)
    @test collect_structarray_rec(v) == StructArray(StructArray((a = ["1",2,3],)) => StructArray((b = ["a1","a2","a3"],)))
    @test eltype(collect_structarray_rec(v)) == Pair{NamedTuple{(:a,), Tuple{Any}}, NamedTuple{(:b,), Tuple{String}}}

    # empty
    v = ((a=i,) => (b="a$i",) for i in 0:-1)
    @test collect_structarray_rec(v) == StructArray(StructArray((a = Int[],)) => StructArray((b = String[],)))
    @test eltype(collect_structarray_rec(v)) == Pair{NamedTuple{(:a,), Tuple{Int}}, NamedTuple{(:b,), Tuple{String}}}

    v = Iterators.filter(t -> t.first.a == 4, ((a=i,) => (b="a$i",) for i in 1:3))
    @test collect_structarray_rec(v) == StructArray(StructArray((a = Int[],)) => StructArray((b = String[],)))
    @test eltype(collect_structarray_rec(v)) == Pair{NamedTuple{(:a,), Tuple{Int}}, NamedTuple{(:b,), Tuple{String}}}

    t = collect_structarray_rec((b = 1,) => (a = i,) for i in (2, missing, 3))
    s = StructArray(StructArray(b = [1,1,1]) => StructArray(a = [2, missing, 3]))
    @test s[1] == t[1]
    @test ismissing(t[2].second.a)
    @test s[3] == t[3]
end

@testset "collect2D" begin
    s = (l for l in [(a=i, b=j) for i in 1:3, j in 1:4])
    v = collect_structarray(s)
    @test size(v) == (3, 4)
    @test v.a == [i for i in 1:3, j in 1:4]
    @test v.b == [j for i in 1:3, j in 1:4]
end

@testset "lazy" begin
    s = StructArray(rand(ComplexF64, 10, 10))
    rows = LazyRows(s)
    @test IndexStyle(rows) isa IndexLinear
    @test all(t -> t.re >= 0, s)
    @test all(t -> t.re >= 0, rows)
    rows[13].re = -12
    @test !all(t -> t.re >= 0, s)
    @test !all(t -> t.re >= 0, rows)
end
