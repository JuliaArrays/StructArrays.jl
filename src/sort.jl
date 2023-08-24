using Base.Sort, Base.Order

Base.permute!(sa::StructArray, p::AbstractVector) = foreachfield(v -> permute!(v, p), sa)

struct GroupPerm{V<:AbstractVector, P<:AbstractVector{<:Integer}, U<:AbstractUnitRange}
    vec::V
    perm::P
    within::U
end

GroupPerm(vec, perm=sortperm(vec)) = GroupPerm(vec, perm, axes(vec, 1))

Base.sortperm(g::GroupPerm) = g.perm
Base.parent(g::GroupPerm) = g.vec

function Base.iterate(g::GroupPerm, i = first(g.within))
    vec, perm = g.vec, g.perm
    l = last(g.within)
    i > l && return nothing
    @inbounds pi = perm[i]
    i1 = i+1
    @inbounds while i1 <= l && roweq(vec, pi, perm[i1])
        i1 += 1
    end
    return (i:(i1-1), i1)
end

Base.IteratorSize(::Type{<:GroupPerm}) = Base.SizeUnknown()

Base.eltype(::Type{<:GroupPerm}) = UnitRange{Int}

@inline function roweq(x::AbstractVector, i, j)
    r = refarray(x)
    @inbounds eq = isequal(r[i], r[j])
    return eq
end

roweq(t::Tuple{}, i, j) = true
roweq(t::Tuple, i, j) = roweq(t[1], i, j) ? roweq(tail(t), i, j) : false
roweq(s::StructArray, i, j) = roweq(Tuple(components(s)), i, j)

function uniquesorted(keys, perm=sortperm(keys))
    (keys[perm[idxs[1]]] for idxs in GroupPerm(keys, perm))
end

function finduniquesorted(keys, perm=sortperm(keys))
    func = function (idxs)
        p_idxs = perm[idxs]
        return keys[p_idxs[1]] => p_idxs
    end
    (func(idxs) for idxs in GroupPerm(keys, perm))
end

function Base.sortperm(c::StructVector{T}) where {T<:Union{Tuple, NamedTuple}}
    cols = components(c)
    x = cols[1]
    p = sortperm(x)
    if length(cols) > 1
        y = cols[2]
        refine_perm!(p, cols, 1, x, y, 1, length(x))
    end
    return p
end

Base.sort!(c::StructArray{<:Union{Tuple, NamedTuple}}) = (permute!(c, sortperm(c)); c)
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
    for idxs in GroupPerm(x, p, lo:hi)
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
