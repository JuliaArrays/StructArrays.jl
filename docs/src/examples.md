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

## Example usage with StaticArray elements

```julia
julia> using StructArrays, StaticArrays

julia> x = StructArray([SVector{2}(1,2) for i = 1:5])
5-element StructArray(::Vector{Tuple{Int64, Int64}}) with eltype SVector{2, Int64}:
 [1, 2]
 [1, 2]
 [1, 2]
 [1, 2]
 [1, 2]

julia> A = StructArray([SMatrix{2,2}([1 2;3 4]) for i = 1:5])
5-element StructArray(::Vector{NTuple{4, Int64}}) with eltype SMatrix{2, 2, Int64, 4}:
 [1 2; 3 4]
 [1 2; 3 4]
 [1 2; 3 4]
 [1 2; 3 4]
 [1 2; 3 4]

julia> B = StructArray([SArray{Tuple{2,2,2}}(reshape(1:8,2,2,2)) for i = 1:5]); B[1]
2×2×2 SArray{Tuple{2, 2, 2}, Int64, 3, 8} with indices SOneTo(2)×SOneTo(2)×SOneTo(2):
[:, :, 1] =
 1  3
 2  4

[:, :, 2] =
 5  7
 6  8
```