# Important, for broadcast joins we cannot assume c and d have same number of columns:
# c could have more columns than d
@generated function rowcmp(c::StructVector, i, d::StructVector{C, D}, j) where {C, D}
    N = fieldcount(D)
    ex = :(cmp(getfield(fieldarrays(c),$N)[i], getfield(fieldarrays(d),$N)[j]))
    for n in N-1:-1:1
        ex = quote
            let k = rowcmp(getfield(fieldarrays(c),$n), i, getfield(fieldarrays(d),$n), j)
                (k == 0) ? ($ex) : k
            end
        end
    end
    ex
end

@inline function rowcmp(c::AbstractVector, i, d::AbstractVector, j)
    cmp(c[i], d[j])
end

struct GroupJoinPerm{LP<:GroupPerm, RP<:GroupPerm}
    left::LP
    right::RP
end

GroupJoinPerm(lkeys::AbstractVector, rkeys::AbstractVector, lperm=sortperm(lkeys), rperm=sortperm(rkeys)) =
    GroupJoinPerm(GroupPerm(lkeys, lperm), GroupPerm(rkeys, rperm))

function _pick(s, a, b)
    if a === nothing && b === nothing
        return nothing
    elseif a === nothing
        return (1:0, b[1]), (1, a, b)
    elseif b === nothing
        return (a[1], 1:0), (-1, a, b)
    else
        lp = sortperm(s.left)
        rp = sortperm(s.right)
        cmp = rowcmp(parent(s.left), lp[first(a[1])], parent(s.right), rp[first(b[1])])
        if cmp < 0
            return (a[1], 1:0), (-1, a, b)
        elseif cmp == 0
            return (a[1], b[1]), (0, a, b)
        else
            return (1:0, b[1]), (1, a, b)
        end
    end
end

function Base.iterate(s::GroupJoinPerm)
    l = iterate(s.left)
    r = iterate(s.right)
    _pick(s, l, r)
end

function Base.iterate(s::GroupJoinPerm, (select, l, r))
    (select <= 0) && (l = iterate(s.left, l[2]))
    (select >= 0) && (r = iterate(s.right, r[2]))
    _pick(s, l, r)
end

Base.IteratorSize(::Type{<:GroupJoinPerm}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{<:GroupJoinPerm}) = Base.HasEltype()
Base.eltype(::Type{<:GroupJoinPerm}) = Tuple{UnitRange{Int}, UnitRange{Int}}
