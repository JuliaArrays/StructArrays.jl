fastpermute!(v::AbstractArray, p::AbstractVector) = copyto!(v, v[p])
fastpermute!(v::StructArray, p::AbstractVector) = permute!(v, p)
fastpermute!(v::PooledArray, p::AbstractVector) = permute!(v, p)

optimize_isequal(v::AbstractArray) = v
optimize_isequal(v::PooledArray) = v.refs
optimize_isequal(v::StructArray{<:Union{Tuple, NamedTuple}}) = StructArray(map(optimize_isequal, fieldarrays(v)))

recover_original(v::AbstractArray, el) = el
recover_original(v::PooledArray, el) = v.pool[el]
recover_original(v::StructArray{T}, el) where {T<:Union{Tuple, NamedTuple}} = T(map(recover_original, fieldarrays(v), el))

pool(v::AbstractArray, condition = !isbitstype∘eltype) = condition(v) ? convert(PooledArray, v) : v
pool(v::StructArray, condition = !isbitstype∘eltype) = replace_storage(t -> pool(t, condition), v)

function Base.permute!(c::StructArray, p::AbstractVector)
    foreachfield(v -> fastpermute!(v, p), c)
    return c
end

struct TiedIndices{T<:AbstractVector, V<:AbstractVector{<:Integer}, U<:AbstractUnitRange}
    vec::T
    perm::V
    within::U
end

TiedIndices(vec::AbstractVector, perm=sortperm(vec)) =
    TiedIndices(vec, perm, axes(vec, 1))

Base.IteratorSize(::Type{<:TiedIndices}) = Base.SizeUnknown()

Base.eltype(::Type{<:TiedIndices{T}}) where {T} =
    Pair{eltype(T), UnitRange{Int}}

Base.sortperm(t::TiedIndices) = t.perm

function Base.iterate(n::TiedIndices, i = first(n.within))
    vec, perm = n.vec, n.perm
    l = last(n.within)
    i > l && return nothing
    @inbounds row = vec[perm[i]]
    i1 = i+1
    @inbounds while i1 <= l && isequal(row, vec[perm[i1]])
        i1 += 1
    end
    return (row => i:(i1-1), i1)
end

"""
`tiedindices(v, perm=sortperm(v))`

Given an abstract vector `v` and a permutation vector `perm`, return an iterator
of pairs `val => range` where `range` is a maximal interval such as `v[perm[range]]`
is constant: `val` is the unique value of `v[perm[range]]`.
"""
tiedindices(v, perm=sortperm(v)) = TiedIndices(v, perm)

"""
`maptiedindices(f, v, perm)`

Given a function `f`, compute the iterator `tiedindices(v, perm)` and return
in iterable object which yields `f(val, idxs)` where `val => idxs` are the pairs
iterated by `tiedindices(v, perm)`.

## Examples

`maptiedindices` is a low level building block that can be used to define grouping
operators. For example:

```jldoctest
julia> function mygroupby(f, keys, data)
           perm = sortperm(keys)
           StructArrays.maptiedindices(keys, perm) do key, idxs
               key => f(data[perm[idxs]])
           end
       end
mygroupby (generic function with 1 method)

julia> StructArray(mygroupby(sum, [1, 2, 1, 3], [1, 4, 10, 11]))
3-element StructArray{Pair{Int64,Int64},1,NamedTuple{(:first, :second),Tuple{Array{Int64,1},Array{Int64,1}}}}:
 1 => 11
 2 => 4
 3 => 11
```
"""
function maptiedindices(f, v, perm)
    fast_v = optimize_isequal(v)
    itr = TiedIndices(fast_v, perm)
    (f(recover_original(v, val), idxs) for (val, idxs) in itr)
end

function uniquesorted(keys, perm=sortperm(keys))
    maptiedindices((key, _) -> key, keys, perm)
end

function finduniquesorted(keys, perm=sortperm(keys))
    maptiedindices((key, idxs) -> (key => perm[idxs]), keys, perm)
end
