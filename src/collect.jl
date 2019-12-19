default_array(::Type{S}, d) where {S} = Array{S}(undef, d)

struct StructArrayInitializer{F, G}
    unwrap::F
    default_array::G
end
StructArrayInitializer(unwrap = t->false) = StructArrayInitializer(unwrap, default_array)

const default_initializer = StructArrayInitializer()

function (s::StructArrayInitializer)(S, d)
    ai = ArrayInitializer(s.unwrap, s.default_array)
    buildfromschema(typ -> ai(typ, d), S)
end
(s::StructArrayInitializer)(::Type{Union{}}, d) = s.default_array(Union{}, d)

struct ArrayInitializer{F, G}
    unwrap::F
    default_array::G
end
ArrayInitializer(unwrap = t->false) = ArrayInitializer(unwrap, default_array)

(s::ArrayInitializer)(S, d) = s.unwrap(S) ? buildfromschema(typ -> s(typ, d), S) : s.default_array(S, d)
(s::ArrayInitializer)(::Type{Union{}}, d) = s.default_array(Union{}, d)
_reshape(v, itr) = _reshape(v, itr, Base.IteratorSize(itr))
_reshape(v, itr, ::Base.HasShape) = reshapestructarray(v, axes(itr))
_reshape(v, itr, ::Union{Base.HasLength, Base.SizeUnknown}) = v

# temporary workaround before it gets easier to support reshape with offset axis
reshapestructarray(v::AbstractArray, d) = reshape(v, d)
reshapestructarray(v::StructArray{T}, d) where {T} =
    StructArray{T}(map(x -> reshapestructarray(x, d), fieldarrays(v)))

function collect_empty_structarray(itr::T; initializer = default_initializer) where {T}
    S = Core.Compiler.return_type(first, Tuple{T})
    res = initializer(S, (0,))
    _reshape(res, itr)
end

"""
`collect_structarray(itr, fr=iterate(itr); initializer = default_initializer)`

Collects `itr` into a `StructArray`. The user can optionally pass a `initializer`, that is to say
a function `(S, d) -> v` that associates to a type and a size an array of eltype `S`
and size `d`. By default `initializer` returns a `StructArray` of `Array` but custom array types
may be used. `fr` represents the moment in the iteration of `itr` from which to start collecting.
"""
collect_structarray(itr; initializer = default_initializer) =
    _collect_structarray(itr, Base.IteratorSize(itr); initializer = initializer)

function _collect_structarray(itr, sz::Union{Base.HasShape, Base.HasLength};
                              initializer = default_initializer)
    len = length(itr)
    elem = iterate(itr)
    elem === nothing && return initializer(Union{}, (0,))
    el, st = elem
    S = typeof(el)
    dest = initializer(S, (len,))
    dest[1] = el
    v = collect_to_structarray!(dest, itr, 2, st, initializer = initializer)
    _reshape(v, itr, sz)
end

function _collect_structarray(itr, ::Base.SizeUnknown; initializer = default_initializer)
    elem = iterate(itr)
    elem === nothing && return initializer(Union{}, (0,))
    el, st = elem
    S = typeof(el)
    dest = initializer(S, (1,))
    dest[1] = el
    grow_to_structarray!(dest, itr, iterate(itr, st), initializer = initializer)
end

function collect_to_structarray!(dest::AbstractArray, itr, offs, st;
                                 initializer = default_initializer)
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen the result type and re-dispatch.
    i = offs
    while true
        elem = iterate(itr, st)
        elem === nothing && break
        el, st = elem
        if iscompatible(el, dest)
            @inbounds dest[i] = el
            i += 1
        else
            new = widen(dest, i, el, initializer = initializer)
            @inbounds new[i] = el
            return collect_to_structarray!(new, itr, i+1, st, initializer = initializer)
        end
    end
    return dest
end

function grow_to_structarray!(dest::AbstractArray, itr, elem = iterate(itr);
                              initializer = default_initializer)
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen the result type and re-dispatch.
    i = length(dest)+1
    while elem !== nothing
        el, st = elem
        if iscompatible(el, dest)
            push!(dest, el)
            elem = iterate(itr, st)
            i += 1
        else
            new = widen(dest, i, el, initializer = initializer)
            push!(new, el)
            return grow_to_structarray!(new, itr, iterate(itr, st), initializer = initializer)
        end
    end
    return dest
end

function widen(dest::AbstractArray{S}, i, el::T;
               initializer = default_initializer) where {S, T}
    return widenstructarray(dest, i, _promote_typejoin(S, T))
end
function widen(dest::AbstractArray{Union{}}, i, el::T;
               initializer = default_initializer) where {T}
    return initializer(T, size(dest))
end

function widenstructarray(dest::StructArray, i, ::Type{T}) where {T}
    sch = hasfields(T) ? staticschema(T) : nothing
    sch !== nothing && fieldnames(sch) == propertynames(dest) || return widenarray(dest, i, T)
    types = ntuple(x -> fieldtype(sch, x), fieldcount(sch))
    cols = Tuple(fieldarrays(dest))
    newcols = map((a, b) -> widenstructarray(a, i, b), cols, types)
    return StructArray{T}(newcols)
end

widenstructarray(dest::AbstractArray, i, ::Type{T}) where {T} = widenarray(dest, i, T)

widenarray(dest::AbstractArray{T}, i, ::Type{T}) where {T} = dest
function widenarray(dest::AbstractArray, i, ::Type{T}) where T
    new = similar(dest, T, length(dest))
    copyto!(new, 1, dest, 1, i-1)
    new
end

"""
`append!!(dest, itr) -> dest′`

Try to append `itr` into a vector `dest`.  Widen element type of
`dest` if it cannot hold the elements of `itr`.  That is to say,

```julia
vcat(dest, StructVector(itr)) == append!!(dest, itr)
```

holds.  Note that `dest′` may or may not be the same object as `dest`.
The state of `dest` is unpredictable after `append!!`
is called (e.g., it may contain just half of the elements from `itr`).
"""
append!!(dest::AbstractVector, itr; initializer = default_initializer) =
    _append!!(dest, itr, Base.IteratorSize(itr), initializer = initializer)

function _append!!(dest::AbstractVector, itr, ::Union{Base.HasShape, Base.HasLength};
                   initializer = default_initializer)
    n = length(itr)  # itr may be stateful so do this first
    fr = iterate(itr)
    fr === nothing && return dest
    el, st = fr
    i = lastindex(dest) + 1
    new = iscompatible(el, dest) ? dest : widen(dest, i, el, initializer = initializer)
    resize!(new, length(dest) + n)
    @inbounds new[i] = el
    return collect_to_structarray!(new, itr, i + 1, st, initializer = initializer)
end

_append!!(dest::AbstractVector, itr, ::Base.SizeUnknown; initializer = default_initializer) =
    grow_to_structarray!(dest, itr, initializer = initializer)
