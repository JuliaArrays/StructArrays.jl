# Advanced techniques

## Structures with non-standard data layout

StructArrays support structures with custom data layout. The user is required to overload `staticschema` in order to define the custom layout, `component` to access fields of the custom layout, and `createinstance(T, fields...)` to create an instance of type `T` from its custom fields `fields`. In other word, given `x::T`, `createinstance(T, (component(x, f) for f in fieldnames(staticschema(T)))...)` should successfully return an instance of type `T`.

Here is an example of a type `MyType` that has as custom fields either its field `data` or fields of its field `rest` (which is a named tuple):

```@repl advanced1
using StructArrays

struct MyType{T, NT<:NamedTuple}
    data::T
    rest::NT
end

MyType(x; kwargs...) = MyType(x, values(kwargs))
```

Let's create a small array of these objects:

```@repl advanced1
s = [MyType(i/5, a=6-i, b=2) for i in 1:5]
```

The default `StructArray` does not unpack the `NamedTuple`:

```@repl advanced1
sa = StructArray(s);
sa.rest
sa.a
```

Suppose we wish to give the keywords their own fields. We can define custom `staticschema`, `component`, and `createinstance` methods for `MyType`:

```@repl advanced1
function StructArrays.staticschema(::Type{MyType{T, NamedTuple{names, types}}}) where {T, names, types}
    # Define the desired names and eltypes of the "fields"
    return NamedTuple{(:data, names...), Base.tuple_type_cons(T, types)}
end;

function StructArrays.component(m::MyType, key::Symbol)
    # Define a component-extractor
    return key === :data ? getfield(m, 1) : getfield(getfield(m, 2), key)
end;

function StructArrays.createinstance(::Type{MyType{T, NT}}, x, args...) where {T, NT}
    # Generate an instance of MyType from components
    return MyType(x, NT(args))
end;
```

and now:

```@repl advanced1
sa = StructArray(s);
sa.a
sa.b
```

The above strategy has been tested and implemented in [GeometryBasics.jl](https://github.com/JuliaGeometry/GeometryBasics.jl).

## Mutate-or-widen style accumulation

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

## Using StructArrays in CUDA kernels

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

