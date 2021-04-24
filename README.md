# StructArrays

[![CI](https://github.com/JuliaArrays/StructArrays.jl/workflows/CI/badge.svg?branch=master)](https://github.com/JuliaArrays/StructArrays.jl/actions?query=workflow%3ACI+branch%3Amaster)
[![codecov.io](http://codecov.io/github/JuliaArrays/StructArrays.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaArrays/StructArrays.jl?branch=master)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaArrays.github.io/StructArrays.jl/dev)

This package introduces the type `StructArray` which is an `AbstractArray` whose elements are `struct` (for example `NamedTuples`,  or `ComplexF64`, or a custom user defined `struct`). While a `StructArray` iterates `structs`, the layout is column based (meaning each field of the `struct` is stored in a separate `Array`).

`Base.getproperty` or the dot syntax can be used to access columns, whereas rows can be accessed with `getindex`.

The package was largely inspired by the `Columns` type in [IndexedTables](https://github.com/JuliaComputing/IndexedTables.jl) which it now replaces.

## Example usage to store complex numbers

```julia
julia> using StructArrays, Random

julia> Random.seed!(4);

julia> s = StructArray{ComplexF64}((rand(2,2), rand(2,2)))
2×2 StructArray(::Array{Float64,2}, ::Array{Float64,2}) with eltype Complex{Float64}:
 0.680079+0.625239im   0.92407+0.267358im
 0.874437+0.737254im  0.929336+0.804478im

julia> s[1, 1]
0.680079235935741 + 0.6252391193298537im

julia> s.re
2×2 Array{Float64,2}:
 0.680079  0.92407
 0.874437  0.929336

julia> StructArrays.components(s) # obtain all field arrays as a named tuple
(re = [0.680079 0.92407; 0.874437 0.929336], im = [0.625239 0.267358; 0.737254 0.804478])
```

Note that the same approach can be used directly from an `Array` of complex numbers:

```julia
julia> StructArray([1+im, 3-2im])
2-element StructArray(::Array{Int64,1}, ::Array{Int64,1}) with eltype Complex{Int64}:
 1 + 1im
 3 - 2im
```

## Collection and initialization

One can also create a `StructArray` from an iterable of structs without creating an intermediate `Array`:

```julia
julia> StructArray(log(j+2.0*im) for j in 1:10)
10-element StructArray(::Array{Float64,1}, ::Array{Float64,1}) with eltype Complex{Float64}:
 0.8047189562170501 + 1.1071487177940904im
 1.0397207708399179 + 0.7853981633974483im
 1.2824746787307684 + 0.5880026035475675im
 1.4978661367769954 + 0.4636476090008061im
  1.683647914993237 + 0.3805063771123649im
 1.8444397270569681 + 0.3217505543966422im
  1.985145956776061 + 0.27829965900511133im
 2.1097538525880535 + 0.24497866312686414im
 2.2213256282451583 + 0.21866894587394195im
 2.3221954495706862 + 0.19739555984988078im
```

Another option is to create an uninitialized `StructArray` and then fill it with data. Just like in normal arrays, this is done with the `undef` syntax:

```julia
julia> s = StructArray{ComplexF64}(undef, 2, 2)
2×2 StructArray(::Array{Float64,2}, ::Array{Float64,2}) with eltype Complex{Float64}:
 6.91646e-310+6.91646e-310im  6.91646e-310+6.91646e-310im
 6.91646e-310+6.91646e-310im  6.91646e-310+6.91646e-310im

julia> rand!(s)
2×2 StructArray(::Array{Float64,2}, ::Array{Float64,2}) with eltype Complex{Float64}:
 0.680079+0.874437im  0.625239+0.737254im
  0.92407+0.929336im  0.267358+0.804478im
```

## Using custom array types

StructArrays supports using custom array types. It is always possible to pass field arrays of a custom type. The "custom array of structs to struct of custom arrays" transformation will use the `similar` method of the custom array type. This can be useful when working on the GPU for example:

```julia
julia> using StructArrays, CuArrays

julia> a = CuArray(rand(Float32, 10));

julia> b = CuArray(rand(Float32, 10));

julia> StructArray{ComplexF32}((a, b))
10-element StructArray(::CuArray{Float32,1}, ::CuArray{Float32,1}) with eltype Complex{Float32}:
  0.19555175f0 + 0.9604322f0im
  0.68348145f0 + 0.5778245f0im
  0.69664395f0 + 0.79825306f0im
 0.118531585f0 + 0.3031248f0im
  0.80057466f0 + 0.8964418f0im
  0.63772964f0 + 0.2923274f0im
  0.65374136f0 + 0.7932533f0im
   0.6043732f0 + 0.65964353f0im
   0.1106627f0 + 0.090207934f0im
    0.707458f0 + 0.1700114f0im

julia> c = CuArray(rand(ComplexF32, 10));

julia> StructArray(c)
10-element StructArray(::Array{Float32,1}, ::Array{Float32,1}) with eltype Complex{Float32}:
  0.7176411f0 + 0.864058f0im
   0.252609f0 + 0.14824867f0im
 0.26842773f0 + 0.9084332f0im
 0.33128333f0 + 0.5106474f0im
  0.6509278f0 + 0.87059164f0im
  0.9522146f0 + 0.053706646f0im
   0.899577f0 + 0.63242567f0im
   0.325814f0 + 0.59225655f0im
 0.56267905f0 + 0.21927536f0im
 0.49719965f0 + 0.754143f0im
```

If you already have your data in a `StructArray` with field arrays of a given format (say plain `Array`) you can change them with `replace_storage`:

```julia
julia> s = StructArray([1.0+im, 2.0-im])
2-element StructArray(::Array{Float64,1}, ::Array{Float64,1}) with eltype Complex{Float64}:
 1.0 + 1.0im
 2.0 - 1.0im

julia> replace_storage(CuArray, s)
2-element StructArray(::CuArray{Float64,1}, ::CuArray{Float64,1}) with eltype Complex{Float64}:
 1.0 + 1.0im
 2.0 - 1.0im
```

## Example usage to store a data table

```julia
julia> t = StructArray((a = [1, 2], b = ["x", "y"]))
2-element StructArray(::Array{Int64,1}, ::Array{String,1}) with eltype NamedTuple{(:a, :b),Tuple{Int64,String}}:
 (a = 1, b = "x")
 (a = 2, b = "y")

julia> t[1]
(a = 1, b = "x")

julia> t.a
2-element Array{Int64,1}:
 1
 2

julia> push!(t, (a = 3, b = "z"))
3-element StructArray(::Array{Int64,1}, ::Array{String,1}) with eltype NamedTuple{(:a, :b),Tuple{Int64,String}}:
 (a = 1, b = "x")
 (a = 2, b = "y")
 (a = 3, b = "z")
```

## Lazy row iteration

StructArrays also provides a `LazyRow` wrapper for lazy row iteration. `LazyRow(t, i)` does not materialize the i-th row but returns a lazy wrapper around it on which `getproperty` does the correct thing. This is useful when the row has many fields only some of which are necessary. It also allows changing columns in place.

```julia
julia> t = StructArray((a = [1, 2], b = ["x", "y"]));

julia> LazyRow(t, 2).a
2

julia> LazyRow(t, 2).a = 123
123

julia> t
2-element StructArray(::Array{Int64,1}, ::Array{String,1}) with eltype NamedTuple{(:a, :b),Tuple{Int64,String}}:
 (a = 1, b = "x")
 (a = 123, b = "y")
```

To iterate in a lazy way one can simply iterate `LazyRows`:

```julia
julia> map(t -> t.b ^ t.a, LazyRows(t))
2-element Array{String,1}:
 "x"
 "yy"
```

## Advanced: structures with non-standard data layout

StructArrays support structures with custom data layout. The user is required to overload `staticschema` in order to define the custom layout, `component` to access fields of the custom layout, and `createinstance(T, fields...)` to create an instance of type `T` from its custom fields `fields`. In other word, given `x::T`, `createinstance(T, (component(x, f) for f in fieldnames(staticschema(T)))...)` should successfully return an instance of type `T`.

Here is an example of a type `MyType` that has as custom fields either its field `data` or fields of its field `rest` (which is a named tuple):

```julia
using StructArrays

struct MyType{T, NT<:NamedTuple}
    data::T
    rest::NT
end

MyType(x; kwargs...) = MyType(x, values(kwargs))

function StructArrays.staticschema(::Type{MyType{T, NamedTuple{names, types}}}) where {T, names, types}
    return NamedTuple{(:data, names...), Base.tuple_type_cons(T, types)}
end

function StructArrays.component(m::MyType, key::Symbol)
    return key === :data ? getfield(m, 1) : getfield(getfield(m, 2), key)
end

# generate an instance of MyType type
function StructArrays.createinstance(::Type{MyType{T, NT}}, x, args...) where {T, NT}
    return MyType(x, NT(args))
end

s = [MyType(rand(), a=1, b=2) for i in 1:10]
StructArray(s)
```

In the above example, our `MyType` was composed of `data` of type `Float64` and `rest` of type `NamedTuple`. In many practical cases where there are custom types involved it's hard for StructArrays to automatically widen the types in case they are heterogeneous. The following example demonstrates a widening method in that scenario.

```julia
using Tables

# add a source of custom type data
struct Location{U}
    x::U
    y::U
end
struct Region{V}
    area::V
end

s1 = MyType(Location(1, 0), place = "Delhi", rainfall = 200)
s2 = MyType(Location(2.5, 1.9), place = "Mumbai", rainfall = 1010)
s3 = MyType(Region([Location(1, 0), Location(2.5, 1.9)]), place = "North India", rainfall = missing)

s = [s1, s2, s3]
# Now if we try to do StructArray(s)
# we will get an error

function meta_table(iter)
    cols = Tables.columntable(iter)
    meta_table(first(cols), Base.tail(cols)) 
end

function meta_table(data, rest::NT) where NT<:NamedTuple
    F = MyType{eltype(data), StructArrays.eltypes(NT)}
    return StructArray{F}(; data=data, rest...)
end

meta_table(s)
```

The above strategy has been tested and implemented in [GeometryBasics.jl](https://github.com/JuliaGeometry/GeometryBasics.jl).

## Advanced: mutate-or-widen style accumulation

StructArrays provides a function `StructArrays.append!!(dest, src)` (unexported) for "mutate-or-widen" style accumulation.  This function can be used via [`BangBang.append!!`](https://juliafolds.github.io/BangBang.jl/dev/#BangBang.append!!) and [`BangBang.push!!`](https://juliafolds.github.io/BangBang.jl/dev/#BangBang.push!!) as well.

`StructArrays.append!!` works like `append!(dest, src)` if `dest` can contain all element types in `src` iterator; i.e., it _mutates_ `dest` in-place:

```julia
julia> dest = StructVector((a=[1], b=[2]))
1-element StructArray(::Array{Int64,1}, ::Array{Int64,1}) with eltype NamedTuple{(:a, :b),Tuple{Int64,Int64}}:
 (a = 1, b = 2)

julia> StructArrays.append!!(dest, [(a = 3, b = 4)])
2-element StructArray(::Array{Int64,1}, ::Array{Int64,1}) with eltype NamedTuple{(:a, :b),Tuple{Int64,Int64}}:
 (a = 1, b = 2)
 (a = 3, b = 4)

julia> ans === dest
true
```

Unlike `append!`, `append!!` can also _widen_ element type of `dest` array:

```julia
julia> StructArrays.append!!(dest, [(a = missing, b = 6)])
3-element StructArray(::Array{Union{Missing, Int64},1}, ::Array{Int64,1}) with eltype NamedTuple{(:a, :b),Tuple{Union{Missing, Int64},Int64}}:
 NamedTuple{(:a, :b),Tuple{Union{Missing, Int64},Int64}}((1, 2))
 NamedTuple{(:a, :b),Tuple{Union{Missing, Int64},Int64}}((3, 4))
 NamedTuple{(:a, :b),Tuple{Union{Missing, Int64},Int64}}((missing, 6))

julia> ans === dest
false
```

Since the original array `dest` cannot hold the input, a new array is created (`ans !== dest`).

Combined with [function barriers](https://docs.julialang.org/en/latest/manual/performance-tips/#kernel-functions-1), `append!!` is a useful building block for implementing `collect`-like functions.

## Advanced: using StructArrays in CUDA kernels

It is possible to combine StructArrays with [CUDAnative](https://github.com/JuliaGPU/CUDAnative.jl), in order to create CUDA kernels that work on StructArrays directly on the GPU. Make sure you are familiar with the CUDAnative documentation (esp. kernels with plain `CuArray`s) before experimenting with kernels based on `StructArray`s.

```julia
using CUDAnative, CuArrays, StructArrays
d = StructArray(a = rand(100), b = rand(100))

# move to GPU
dd = replace_storage(CuArray, d)
de = similar(dd)

# a simple kernel, to copy the content of `dd` onto `de`
function kernel!(dest, src)
    i = (blockIdx().x-1)*blockDim().x + threadIdx().x
    if i <= length(dest)
        dest[i] = src[i]
    end
    return nothing
end

threads = 1024
blocks = cld(length(dd),threads)

@cuda threads=threads blocks=blocks kernel!(de, dd)
```

## Applying a function on each field array

```julia
julia> struct Foo
       a::Int
       b::String
       end

julia> s = StructArray([Foo(11, "a"), Foo(22, "b"), Foo(33, "c"), Foo(44, "d"), Foo(55, "e")]);

julia> s
5-element StructArray(::Vector{Int64}, ::Vector{String}) with eltype Foo:
 Foo(11, "a")
 Foo(22, "b")
 Foo(33, "c")
 Foo(44, "d")
 Foo(55, "e")

julia> StructArrays.foreachfield(v -> deleteat!(v, 3), s)

julia> s
4-element StructArray(::Vector{Int64}, ::Vector{String}) with eltype Foo:
 Foo(11, "a")
 Foo(22, "b")
 Foo(44, "d")
 Foo(55, "e")
```
