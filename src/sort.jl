using Base.Sort, Base.Order

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

function Base.sortperm(c::StructVector{T}) where {T<:Union{Tuple, NamedTuple}}

    cols = fieldarrays(c)
    x = cols[1]
    p = sortperm(x)
    if length(cols) > 1
        y = cols[2]
        refine_perm!(p, cols, 1, x, y, 1, length(x))
    end
    return p
end

Base.sort!(c::StructArray{<:Union{Tuple, NamedTuple}}) = permute!(c, sortperm(c))
Base.sort(c::StructArray{<:Union{Tuple, NamedTuple}}) = c[sortperm(c)]

# Given an ordering `p`, return a vector `v` such that `Perm(Forward, v)` is
# equivalent to `p`. Return `nothing` if such vector is not found.
forward_vec(p::Perm{ForwardOrdering}) = p.data
forward_vec(::Ordering) = nothing

# Methods from IndexedTables to refine sorting:
# # assuming x[p] is sorted, sort by remaining columns where x[p] is constant
function refine_perm!(p, cols, c, x, y′, lo, hi)
    temp = similar(p, 0)
    order = Perm(Forward, y′)
    y = something(forward_vec(order), y′)
    nc = length(cols)
    for (_, idxs) in TiedIndices(optimize_isequal(x), p, lo:hi)
        i, i1 = extrema(idxs)
        if i1 > i
            sort_sub_by!(p, i, i1, y, order, temp)
            if c < nc-1
                z = cols[c+2]
                refine_perm!(p, cols, c+1, y, z, i, i1)
            end
        end
    end
end

# sort the values in v[i0:i1] in place, by array `by`
Base.@noinline function sort_sub_by!(v, i0, i1, by, order, temp)
    empty!(temp)
    sort!(v, i0, i1, MergeSort, order, temp)
end

Base.@noinline function sort_sub_by!(v, i0, i1, by::AbstractVector{T}, order, temp) where T<:Integer
    min = max = by[v[i0]]
    @inbounds for i = i0+1:i1
        val = by[v[i]]
        if val < min
            min = val
        elseif val > max
            max = val
        end
    end
    rangelen = max-min+1
    n = i1-i0+1
    if rangelen <= n
        sort_int_range_sub_by!(v, i0-1, n, by, rangelen, min, temp)
    else
        empty!(temp)
        sort!(v, i0, i1, MergeSort, order, temp)
    end
    v
end

# in-place counting sort of x[ioffs+1:ioffs+n] by values in `by`
function sort_int_range_sub_by!(x, ioffs, n, by, rangelen, minval, temp)
    offs = 1 - minval

    where = fill(0, rangelen+1)
    where[1] = 1
    @inbounds for i = 1:n
        where[by[x[i+ioffs]] + offs + 1] += 1
    end
    cumsum!(where, where)

    length(temp) < n && resize!(temp, n)
    @inbounds for i = 1:n
        xi = x[i+ioffs]
        label = by[xi] + offs
        wl = where[label]
        temp[wl] = xi
        where[label] = wl+1
    end

    @inbounds for i = 1:n
        x[i+ioffs] = temp[i]
    end
    x
end
