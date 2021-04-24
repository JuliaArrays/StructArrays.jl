# Some counterintuitive behaviors 

StructArrays doesn't explicitly store any structs; rather, it materializes a struct element on the fly when `getindex` is called. This is typically very efficient; for example, if all the struct fields are `isbits`, then materializing a new struct does not allocate. However, this can lead to counterintuitive behavior when modifying entries of a StructArray. 

## Modifying the field of a struct element

```julia
julia> mutable struct Foo{T}
       a::T
       b::T
       end
       
julia> x = StructArray([Foo(1,2) for i = 1:5])

julia> x[1].a = 10

julia> x # remains unchanged
5-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Foo{Int64}:
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
```
The assignment `x[1].a = 10` first calls `getindex(x,1)`, then sets property `a` of the accessed element. However, since StructArrays constructs `Foo(x.a[1],x.b[1])` on the fly when when accessing `x[1]`, setting `x[1].a = 10` modifies the materialized struct rather than the StructArray `x`. 

Note that one can modify a field of a StructArray entry via `x[1] = x[1].a = 10`. `x[1].a = 10` creates a new `Foo` element, modifies the field `a`, then returns the modified struct. Assigning this to `x[1]` then unpacks `a` and `b` from the modified struct and assigns entries of the field arrays `x.a[1] = a`, `x.b[1] = b`.).

## Broadcasted assignment for array entries

Broadcasted in-place assignment can also behave counterintuitively for StructArrays. 
```julia
julia> mutable struct Bar{T} <: FieldVector{2,T}
       a::T
       b::T
       end

julia> x = StructArray([Bar(1,2) for i = 1:5])
5-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Bar{Int64}:
 [1, 2]
 [1, 2]
 [1, 2]
 [1, 2]
 [1, 2]

julia> x[1] .= 1
2-element Bar{Int64} with indices SOneTo(2):
 1
 1

julia> x
5-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Bar{Int64}:
 [1, 2]
 [1, 2]
 [1, 2]
 [1, 2]
 [1, 2]       
```
Because setting `x[1] .= 1` creates a `Bar` struct first, broadcasted assignment modifies this new materialized struct rather than the StructArray `x`. Note, however, that `x[1] = x[1] .= 1` works, since it assigns the modified materialized struct to the first entry of `x`.

## Mutable struct types

Each of these counterintuitive behaviors occur when using StructArrays with mutable elements. However, since a StructArray is mutable even if its entries are immutable, a StructArray with immutable elements will in many cases behave identically to (but be more efficient than) a StructArray with mutable elements. Thus, it is recommended to use immutable structs with StructArray whenever possible. 
