using Base.Sort, Base.Order

isstringarray(::Any) = false
ispooled(::AbstractArray) = false

function Base.permute!(c::StructVector, p::AbstractVector)
    foreachfield(c) do v
        if  v isa StructVector || isstringarray(v) || ispooled(v)
            permute!(v, p)
        else
            copyto!(v, v[p])
        end
    end
    return c
end

struct TiedIndices{T <: AbstractVector}
    vec::T
    perm::Vector{Int}
    extrema::Tuple{Int, Int}
end

TiedIndices(vec::AbstractVector, perm=sortperm(vec)) =
    TiedIndices(vec, perm, extrema(vec))

Base.IteratorSize(::Type{<:TiedIndices}) = Base.SizeUnknown()

function Base.iterate(n::TiedIndices, i = n.extrema[1])
    vec, perm = n.vec, n.perm
    l = n.extrema[2]
    i > l && return nothing
    row = vec[perm[i]]
    i1 = i
    @inbounds while i1 <= l && isequal(row, vec[perm[i1]])
        i1 += 1
    end
    return (row => i:(i1-1), i1)
end

function Base.sortperm(c::StructVector{T};
    alg = DEFAULT_UNSTABLE) where {T<:Union{Tuple, NamedTuple}}

    cols = fieldarrays(c)
    x = cols[1]
    p = sortperm(x; alg = alg)
    if length(cols) > 1
        y = cols[2]
        refine_perm!(p, cols, 1, x, y, 1, length(x))
    end
    return p
end

# # assuming x[p] is sorted, sort by remaining columns where x[p] is constant
function refine_perm!(p, cols, c, x, y, lo, hi)
    temp = similar(p, 0)
    order = Perm(Forward, y)
    nc = length(cols)
    for (_, idxs) in TiedIndices(x, p, (lo, hi))
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

Base.@noinline function sort_sub_by!(v, i0, i1, by::Vector{T}, order, temp) where T<:Integer
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

