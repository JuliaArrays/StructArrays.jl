# StructureArrays

[![Build Status](https://travis-ci.org/piever/StructureArrays.jl.svg?branch=master)](https://travis-ci.org/piever/StructureArrays.jl)
[![codecov.io](http://codecov.io/github/piever/StructureArrays.jl/coverage.svg?branch=master)](http://codecov.io/github/piever/StructureArrays.jl?branch=master)

This package introduces the type `StructureArray` which is an `AbstractArray` whose elements are `struct` (for example `NamedTuples`,  or `ComplexF64`, or a custom user defined `struct`). While a `StructureArray` iterates `structs`, the layout is column based (meaning each field of the `struct` is stored in a seprate `Array`).

`Base.getproperty` or the dot syntax can be used to access columns, whereas rows can be accessed with `getindex`.

The package is largely inspired from the `Columns` type in [IndexedTables](https://github.com/JuliaComputing/IndexedTables.jl)

## Example usage to store complex numbers

```julia
julia> using StructureArrays, Random

julia> srand(4);

julia> s = StructureArray{ComplexF64}(rand(2,2), rand(2,2))
2×2 StructureArray{Complex{Float64},2,NamedTuple{(:re, :im),Tuple{Array{Float64,2},Array{Float64,2}}}}:
 0.680079+0.625239im   0.92407+0.267358im
 0.874437+0.737254im  0.929336+0.804478im

julia> s[1, 1]
0.680079235935741 + 0.6252391193298537im

julia> s.re
2×2 Array{Float64,2}:
 0.680079  0.92407
 0.874437  0.929336
```

## Example usage to store a data table

```julia
julia> t = StructureArray((a = [1, 2], b = ["x", "y"]))
2-element StructureArray{NamedTuple{(:a, :b),Tuple{Int64,String}},1,NamedTuple{(:a, :b),Tuple{Array{Int64,1},Array{String,1}}}}:
 (a = 1, b = "x")
 (a = 2, b = "y")

julia> t[1]
(a = 1, b = "x")

julia> t.a
2-element Array{Int64,1}:
 1
 2

julia> push!(t, (a = 3, b = "z"))
3-element StructureArray{NamedTuple{(:a, :b),Tuple{Int64,String}},1,NamedTuple{(:a, :b),Tuple{Array{Int64,1},Array{String,1}}}}:
 (a = 1, b = "x")
 (a = 2, b = "y")
 (a = 3, b = "z")
```

## Lightweight package

This package aims to be extremely lightweight: so far it has 0 dependencies. One of the reasons to keep it so is to promote its use as a building block for table manipulation packages.

## Warning

The package is still pretty much under development and available only on Julia 0.7 (as it uses `NamedTuples` extensively).
