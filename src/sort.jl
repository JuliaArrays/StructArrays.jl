using Base.Sort, Base.Order

fastpermute!(v::AbstractArray, p::AbstractVector) = copyto!(v, v[p])
fastpermute!(v::StructArray, p::AbstractVector) = permute!(v, p)

function Base.permute!(c::StructArray, p::AbstractVector)
    foreachfield(v -> fastpermute!(v, p), c)
    return c
end

struct TiedIndices{T<:AbstractVector, I<:Integer, U<:AbstractUnitRange}
    vec::T
    perm::Vector{I}
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
    row = vec[perm[i]]
    i1 = i
    @inbounds while i1 <= l && isequal(row, vec[perm[i1]])
        i1 += 1
    end
    return (row => i:(i1-1), i1)
end

tiedindices(args...) = TiedIndices(args...)

function uniquesorted(args...)
    t = tiedindices(args...)
    (row for (row, _) in t)
end

function finduniquesorted(args...)
    t = tiedindices(args...)
    p = sortperm(t)
    (row => p[idxs] for (row, idxs) in t)
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
    for (_, idxs) in TiedIndices(x, p, lo:hi)
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

