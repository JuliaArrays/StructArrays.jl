# Overview of StructArrays.jl

This package introduces the type `StructArray` which is an `AbstractArray` whose elements are `struct` (for example `NamedTuples`,  or `ComplexF64`, or a custom user defined `struct`). While a `StructArray` iterates `structs`, the layout uses separate arrays for each field of the `struct`. This is often called [Structure-Of-Arrays (SOA)](https://en.wikipedia.org/wiki/AoS_and_SoA); the concepts will be explained in greater detail below. `struct` entries of a StructArray are constructed on-the-fly. This contrasts with the "Array-Of-Structs" (AOS) layout where individual array elements are explicitly stored as `struct`s.

`Base.getproperty` or the dot syntax can be used to access struct fields of element of a `StructArray`, whereas elements can be accessed with `getindex` (`[]`).

The package was largely inspired by the `Columns` type in [IndexedTables](https://github.com/JuliaComputing/IndexedTables.jl) which it now replaces.

## Collection and initialization

One can create a `StructArray` by providing the struct type and a tuple or NamedTuple of field arrays:
```@repl intro
using StructArrays
struct Foo{T}
    a::T
    b::T
end
adata = [1 2; 3 4]; bdata = [10 20; 30 40];
x = StructArray{Foo}((adata, bdata))
```

You can also initialze a StructArray by passing in a NamedTuple, in which case the name (rather than the order) specifies how the input arrays are assigned to fields:

```@repl intro
x = StructArray{Foo}((b = adata, a = bdata))    # initialize a with bdata and vice versa
```

If a struct is not specified, a StructArray with Tuple or NamedTuple elements will be created:
```@repl intro
x = StructArray((adata, bdata))
x = StructArray((a = adata, b = bdata))
```

It's also possible to create a `StructArray` by choosing a particular dimension to interpret as the components of a struct:

```@repl intro
x = StructArray{Complex{Int}}(adata; dims=1)  # along dimension 1, the first item `re` and the second is `im`
x = StructArray{Complex{Int}}(adata; dims=2)  # along dimension 2, the first item `re` and the second is `im`
```

One can also create a `StructArray` from an iterable of structs without creating an intermediate `Array`:

```@repl intro
StructArray(log(j+2.0*im) for j in 1:10)
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

Finally, it is possible to create a StructArray from an array-of-structs:

```jldoctest; setup=:(using StructArrays)
julia> aos = [1+2im, 3+4im]
2-element Vector{Complex{Int64}}:
 1 + 2im
 3 + 4im

julia> aos.re     # Vectors do not have fields, so this is an error
ERROR: type Array has no field re
[...]

julia> soa = StructArray(aos)
2-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Complex{Int64}:
 1 + 2im
 3 + 4im

julia> soa.re
2-element Vector{Int64}:
 1
 3
```

!!! warning
    Unlike the other cases above, `soa` contains a *copy* of the data in `aos`. For more discussion, see [Some counterintuitive behaviors](@ref).

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

