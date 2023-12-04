arrayof(::Type{S}, d::NTuple{N, Any}) where {S, N} = similar(defaultarray(S, N), d)

struct StructArrayInitializer{F, G}
    unwrap::F
    arrayof::G
end
StructArrayInitializer(unwrap::F = alwaysfalse) where {F} = StructArrayInitializer(unwrap, arrayof)

const default_initializer = StructArrayInitializer()

function (s::StructArrayInitializer)(S, d)
    ai = ArrayInitializer(s.unwrap, s.arrayof)
    buildfromschema(typ -> ai(typ, d), S)
end

struct ArrayInitializer{F, G}
    unwrap::F
    arrayof::G
end
ArrayInitializer(unwrap::F = alwaysfalse) where {F} = ArrayInitializer(unwrap, arrayof)

(s::ArrayInitializer)(S, d) = s.unwrap(S) ? buildfromschema(typ -> s(typ, d), S) : s.arrayof(S, d)

_axes(itr) = _axes(itr, Base.IteratorSize(itr))
_axes(itr, ::Base.SizeUnknown) = nothing
_axes(itr, ::Base.HasLength) = (Base.OneTo(length(itr)),)
_axes(itr, ::Base.HasShape) = axes(itr)

"""
    collect_structarray(itr; initializer = default_initializer)

Collects `itr` into a `StructArray`. The user can optionally pass a `initializer`, that is to say
a function `(S, d) -> v` that associates to a type and a size an array of eltype `S`
and size `d`. By default `initializer` returns a `StructArray` of `Array` but custom array types
may be used.
"""
function collect_structarray(itr; initializer = default_initializer)
    ax = _axes(itr)
    elem = iterate(itr)
    _collect_structarray(itr, elem, ax; initializer = initializer)
end

function _collect_structarray(itr::T, ::Nothing, ax; initializer = default_initializer) where {T}
    S = Base.@default_eltype itr
    return initializer(S, something(ax, (Base.OneTo(0),)))
end

function _collect_structarray(itr, elem, ax; initializer = default_initializer)
    el, st = elem
    S = typeof(el)
    dest = initializer(S, something(ax, (Base.OneTo(1),)))
    offs = first(LinearIndices(dest))
    @inbounds dest[offs] = el
    return _collect_structarray!(dest, itr, st, ax)
end

function _collect_structarray!(dest, itr, st, ax)
    offs = first(LinearIndices(dest)) + 1
    return collect_to_structarray!(dest, itr, offs, st)
end

_collect_structarray!(dest, itr, st, ::Nothing) =
    grow_to_structarray!(dest, itr, iterate(itr, st))

function collect_to_structarray!(dest::AbstractArray, itr, offs, st)
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen_from_instance the result type and re-dispatch.
    i = offs
    while true
        elem = iterate(itr, st)
        elem === nothing && break
        el, st = elem
        if iscompatible(el, dest)
            @inbounds dest[i] = el
            i += 1
        else
            new = widen_from_instance(dest, i, el)
            @inbounds new[i] = el
            return collect_to_structarray!(new, itr, i+1, st)
        end
    end
    return dest
end

function grow_to_structarray!(dest::AbstractArray, itr, elem = iterate(itr))
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen_from_instance the result type and re-dispatch.
    i = length(dest)+1
    while elem !== nothing
        el, st = elem
        if iscompatible(el, dest)
            push!(dest, el)
            elem = iterate(itr, st)
            i += 1
        else
            new = widen_from_instance(dest, i, el)
            push!(new, el)
            return grow_to_structarray!(new, itr, iterate(itr, st))
        end
    end
    return dest
end

# Widen `dest` to contain `el` and copy until index `i-1`
widen_from_instance(dest::AbstractArray, i, el::T) where {T} = widen_from_type(dest, i, T)
# Widen `dest` to contain elements of type `T` and copy until index `i-1`
function widen_from_type(dest::AbstractArray{S}, i, ::Type{T}) where {S, T}
    U = _promote_typejoin(S, T)
    return _widenstructarray(dest, i, U)
end

function _widenstructarray(dest::StructArray, i, ::Type{T}) where {T}
    sch = hasfields(T) ? staticschema(T) : nothing
    sch !== nothing && fieldnames(sch) == propertynames(dest) || return _widenarray(dest, i, T)
    types = ntuple(x -> fieldtype(sch, x), fieldcount(sch))
    cols = Tuple(components(dest))
    newcols = map((a, b) -> _widenstructarray(a, i, b), cols, types)
    return StructArray{T}(newcols)
end

_widenstructarray(dest::AbstractArray, i, ::Type{T}) where {T} = _widenarray(dest, i, T)

_widenarray(dest::AbstractArray{T}, i, ::Type{T}) where {T} = dest
function _widenarray(dest::AbstractArray, i, ::Type{T}) where T
    new = similar(dest, T)
    copyto!(new, firstindex(new), dest, firstindex(dest), i-1)
    return new
end

"""
    dest = StructArrays.append!!(dest, itr)

Try to append `itr` into a vector `dest`, widening the element type of `dest` if
it cannot hold the elements of `itr`. That is to say,
```julia
vcat(dest, StructVector(itr)) == append!!(dest, itr)
```
holds. Note that the `dest` argument may or may not be the same object as the
returned value.

The state of `dest` is unpredictable after `append!!` is called (e.g., it may
contain some, none or all the elements from `itr`).
"""
append!!(dest::AbstractVector, itr) =
    _append!!(dest, itr, Base.IteratorSize(itr))

function _append!!(dest::AbstractVector, itr, ::Union{Base.HasShape, Base.HasLength})
    n = length(itr)  # itr may be stateful so do this first
    fr = iterate(itr)
    fr === nothing && return dest
    el, st = fr
    i = lastindex(dest) + 1
    new = iscompatible(el, dest) ? dest : widen_from_instance(dest, i, el)
    resize!(new, length(dest) + n)
    @inbounds new[i] = el
    return collect_to_structarray!(new, itr, i + 1, st)
end

_append!!(dest::AbstractVector, itr, ::Base.SizeUnknown) =
    grow_to_structarray!(dest, itr)

# Optimized version when element collection is an `AbstractVector`
# This only works for julia 1.3 or greater, which has `append!` for `AbstractVector`
@static if VERSION ≥ v"1.3.0"
    function append!!(dest::V, v::AbstractVector{T}) where {V<:AbstractVector, T}
        new = iscompatible(T, V) ? dest : widen_from_type(dest, length(dest) + 1, T)
        return append!(new, v)
    end
end
