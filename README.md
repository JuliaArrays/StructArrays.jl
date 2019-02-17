# StructArrays

[![Build Status](https://travis-ci.org/piever/StructArrays.jl.svg?branch=master)](https://travis-ci.org/piever/StructArrays.jl)
[![codecov.io](http://codecov.io/github/piever/StructArrays.jl/coverage.svg?branch=master)](http://codecov.io/github/piever/StructArrays.jl?branch=master)

This package introduces the type `StructArray` which is an `AbstractArray` whose elements are `struct` (for example `NamedTuples`,  or `ComplexF64`, or a custom user defined `struct`). While a `StructArray` iterates `structs`, the layout is column based (meaning each field of the `struct` is stored in a seprate `Array`).

`Base.getproperty` or the dot syntax can be used to access columns, whereas rows can be accessed with `getindex`.

The package was largely inspired by the `Columns` type in [IndexedTables](https://github.com/JuliaComputing/IndexedTables.jl) which it now replaces.

## Example usage to store complex numbers

```julia
julia> using StructArrays, Random

julia> Random.seed!(4);

julia> s = StructArray{ComplexF64}((rand(2,2), rand(2,2)))
2×2 StructArray{Complex{Float64},2,NamedTuple{(:re, :im),Tuple{Array{Float64,2},Array{Float64,2}}}}:
 0.680079+0.625239im   0.92407+0.267358im
 0.874437+0.737254im  0.929336+0.804478im

julia> s[1, 1]
0.680079235935741 + 0.6252391193298537im

julia> s.re
2×2 Array{Float64,2}:
 0.680079  0.92407
 0.874437  0.929336

julia> fieldarrays(s) # obtain all field arrays as a named tuple
(re = [0.680079 0.92407; 0.874437 0.929336], im = [0.625239 0.267358; 0.737254 0.804478])
```

Note that the same approach can be used directly from an `Array` of complex numbers:

```julia
julia> StructArray([1+im, 3-2im])
2-element StructArray{Complex{Int64},1,NamedTuple{(:re, :im),Tuple{Array{Int64,1},Array{Int64,1}}}}:
 1 + 1im
 3 - 2im
```

### Collection and initialization

One can also create a `StructArrray` from an iterable of structs without creating an intermediate `Array`:

```julia
julia> StructArray(log(j+2.0*im) for j in 1:10)
10-element StructArray{Complex{Float64},1,NamedTuple{(:re, :im),Tuple{Array{Float64,1},Array{Float64,1}}}}:
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
2×2 StructArray{Complex{Float64},2,NamedTuple{(:re, :im),Tuple{Array{Float64,2},Array{Float64,2}}}}:
 6.91646e-310+6.91646e-310im  6.91646e-310+6.91646e-310im
 6.91646e-310+6.91646e-310im  6.91646e-310+6.91646e-310im

julia> rand!(s)
2×2 StructArray{Complex{Float64},2,NamedTuple{(:re, :im),Tuple{Array{Float64,2},Array{Float64,2}}}}:
  0.446415+0.671453im  0.0797964+0.675723im
 0.0340059+0.420472im   0.907252+0.808263im
```

### Using custom array types

StructArrays supports using custom array types. It is always possible to pass field arrays of a custom type. The "custom array of structs to struct of custom arrays" transformation will use the `similar` method of the custom array type. This can be useful when working on the GPU for example:

```julia
julia> using StructArrays, CuArrays

julia> a = CuArray(rand(Float32, 10));

julia> b = CuArray(rand(Float32, 10));

julia> StructArray{ComplexF32}((a, b))
10-element StructArray{Complex{Float32},1,NamedTuple{(:re, :im),Tuple{CuArray{Float32,1},CuArray{Float32,1}}}}:
   0.7539003f0 + 0.5406891f0im
   0.2818451f0 + 0.60345674f0im
   0.3271774f0 + 0.56674314f0im
   0.6943406f0 + 0.8360009f0im
   0.9609026f0 + 0.27519035f0im
 0.051933408f0 + 0.93443274f0im
  0.51335454f0 + 0.90320504f0im
   0.6588727f0 + 0.16270757f0im
  0.20075476f0 + 0.6591008f0im
  0.58832633f0 + 0.45309567f0im

julia> c = CuArray(rand(ComplexF32, 10));

julia> StructArray(c)
10-element StructArray{Complex{Float32},1,NamedTuple{(:re, :im),Tuple{CuArray{Float32,1},CuArray{Float32,1}}}}:
  0.76695776f0 + 0.31588173f0im
   0.9804857f0 + 0.15740407f0im
  0.85849273f0 + 0.51903546f0im
 0.106796384f0 + 0.9493377f0im
  0.38152885f0 + 0.8419838f0im
   0.8892112f0 + 0.5276251f0im
  0.11579132f0 + 0.79168653f0im
  0.16804445f0 + 0.40545344f0im
  0.42822742f0 + 0.61150527f0im
  0.29996157f0 + 0.94151044f0im
```

## Example usage to store a data table

```julia
julia> t = StructArray((a = [1, 2], b = ["x", "y"]))
2-element StructArray{NamedTuple{(:a, :b),Tuple{Int64,String}},1,NamedTuple{(:a, :b),Tuple{Array{Int64,1},Array{String,1}}}}:
 (a = 1, b = "x")
 (a = 2, b = "y")

julia> t[1]
(a = 1, b = "x")

julia> t.a
2-element Array{Int64,1}:
 1
 2

julia> push!(t, (a = 3, b = "z"))
3-element StructArray{NamedTuple{(:a, :b),Tuple{Int64,String}},1,NamedTuple{(:a, :b),Tuple{Array{Int64,1},Array{String,1}}}}:
 (a = 1, b = "x")
 (a = 2, b = "y")
 (a = 3, b = "z")
```

