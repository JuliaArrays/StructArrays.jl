# Some counterintuitive behaviors

When created from parent arrays representing each field of the final `struct`, StructArrays creates a "view" which
doesn't explicitly store any structs; rather, it materializes a struct element on the fly when `getindex` is called. This is typically very efficient; for example, if all the struct fields are `isbits`, then materializing a new struct does not allocate.

However, on-the-fly generation means that there is no storage allocated for the created `struct`. Consequently, mutation is transient and may result in counterintuitive behavior.

Finally, when created from an array-of-structs, StructArrays creates a copy of the "parent" data. This effectively "detaches" the StructArray from the original data.

These issues are elucidated below.

## Modifying a field of a struct element

For this demonstration, throughout we'll use this mutable struct:

```jldoctest counter1; setup=:(using StructArrays)
julia> mutable struct Foo{T}
           a::T
           b::T
       end
```

### The "view" case (SOA)

When created from separate parent arrays, you get a view of the parents, which means that modifying the `StructArray` also modifies the parents:

```jldoctest counter1
julia> a = [1,1,1,1]
4-element Vector{Int64}:
 1
 1
 1
 1

julia> b = [2,2,2,2]
4-element Vector{Int64}:
 2
 2
 2
 2

julia> soa = StructArray{Foo}((a, b))
4-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Foo:
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
```

Now let's modify some elements:

```jldoctest counter1
julia> soa.a[1] = 5
5

julia> soa[2] = Foo(6, 7)
Foo{Int64}(6, 7)

julia> b[3] = 8
8
```

All three of these modify both `soa` and the parent arrays `a` and `b`:

```jldoctest counter1
julia> soa
4-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Foo:
 Foo{Int64}(5, 2)
 Foo{Int64}(6, 7)
 Foo{Int64}(1, 8)
 Foo{Int64}(1, 2)

julia> a
4-element Vector{Int64}:
 5
 6
 1
 1

julia> b
4-element Vector{Int64}:
 2
 7
 8
 2
```

This is because `soa` is a "view" of `a` and `b` (it has no independent storage of its own).

However, you may be surprised by the following:

```jldoctest counter1
julia> soa[4].b = 9
9

julia> soa
4-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Foo:
 Foo{Int64}(5, 2)
 Foo{Int64}(6, 7)
 Foo{Int64}(1, 8)
 Foo{Int64}(1, 2)

julia> b
4-element Vector{Int64}:
 2
 7
 8
 2
```

This assignment had no persistent effect on `soa` or `b`. This occurs because `soa[4]` is generated
on-the-fly; since it returns a `Foo`, which is mutable, you can change its fields. However, the modified `Foo` object
is not stored anywhere.

To store a modification, one would instead need

```jldoctest counter1
julia> x = soa[4]; x.b = 10; soa[4] = x     # store the modified `x` in `soa`
Foo{Int64}(1, 10)

julia> soa
4-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Foo:
 Foo{Int64}(5, 2)
 Foo{Int64}(6, 7)
 Foo{Int64}(1, 8)
 Foo{Int64}(1, 10)

julia> b
4-element Vector{Int64}:
  2
  7
  8
 10
```

!!! note
    This behavior only arises for *mutable* `struct`s. If `Foo` were immutable, re-assigning the `b` field would be an error, and there would be no opportunity for confusion. Moreover, the performance of immutable struct creation is generally much better than for mutable structs. Thus, it is recommended to use immutable structs with StructArray whenever possible.

### The "copy" case (AOS->SOA)

Above, we created a StructArray from arrays `a` and `b`, which creates a "view." The same is not true if you create a StructArray from an array-of-structs:

```jldoctest counter1
julia> aos = [Foo(1,2) for i = 1:4]
4-element Vector{Foo{Int64}}:
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)

julia> soa = StructArray(aos)
4-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Foo{Int64}:
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)

julia> soa.a[1] = 5
5

julia> soa[2] = Foo(6, 7)
Foo{Int64}(6, 7)

julia> soa
4-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype Foo{Int64}:
 Foo{Int64}(5, 2)
 Foo{Int64}(6, 7)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)

julia> aos
4-element Vector{Foo{Int64}}:
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
 Foo{Int64}(1, 2)
```

None of the changes to `soa` "propagated" to `aos`. This is because a StructArray has an SOA in-memory layout; to generate this layout, the data need to be copied. Consequently, in this case `soa` is decoupled from `aos`.

## Broadcasted assignment for array entries

Broadcasted in-place assignment can also behave counterintuitively for StructArrays.
```jldoctest; setup=:(using StructArrays)
julia> using StaticArrays   # for FieldVector

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

## Mutability

The component arrays of a StructArray can be modified in-place mutable even if the `struct` element type of the overall array is immutable. A StructArray with immutable elements will in many cases behave identically to (but be more efficient than) a StructArray with mutable elements.
