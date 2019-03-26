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

struct ArrayInitializer{F, G}
    unwrap::F
    default_array::G
end
ArrayInitializer(unwrap = t->false) = ArrayInitializer(unwrap, default_array)

(s::ArrayInitializer)(S, d) = s.unwrap(S) ? buildfromschema(typ -> s(typ, d), S) : s.default_array(S, d)

_reshape(v, itr) = _reshape(v, itr, Base.IteratorSize(itr))
_reshape(v, itr, ::Base.HasShape) = reshape(v, axes(itr))
_reshape(v, itr, ::Union{Base.HasLength, Base.SizeUnknown}) = v

"""
`collect_structarray(itr, fr=iterate(itr); initializer = default_initializer)`

Collects `itr` into a `StructArray`. The user can optionally pass a `initializer`, that is to say
a function `(S, d) -> v` that associates to a type and a size an array of eltype `S`
and size `d`. By default `initializer` returns a `StructArray` of `Array` but custom array types
may be used. `fr` represents the moment in the iteration of `itr` from which to start collecting.
"""
collect_structarray(itr; initializer = default_initializer) =
    collect_structarray(itr, iterate(itr); initializer = initializer)

collect_structarray(itr, fr; initializer = default_initializer) =
    collect_structarray(itr, fr, Base.IteratorSize(itr); initializer = initializer)

collect_structarray(itr, ::Nothing; initializer = default_initializer) =
    collect_empty_structarray(itr; initializer = initializer)

function collect_empty_structarray(itr::T; initializer = default_initializer) where {T}
    S = Core.Compiler.return_type(first, Tuple{T})
    res = initializer(S, (0,))
    _reshape(res, itr)
end

function collect_structarray(itr, elem, sz::Union{Base.HasShape, Base.HasLength};
                             initializer = default_initializer)
    el, i = elem
    S = typeof(el)
    dest = initializer(S, (length(itr),))
    dest[1] = el
    v = collect_to_structarray!(dest, itr, 2, i)
    _reshape(v, itr, sz)
end

function collect_to_structarray!(dest::AbstractArray{T}, itr, offs, st) where {T}
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen the result type and re-dispatch.
    i = offs
    while true
        elem = iterate(itr, st)
        elem === nothing && break
        el, st = elem
        if iseltype(el, dest)
            @inbounds dest[i] = el
            i += 1
        else
            new = widenstructarray(dest, i, el)
            @inbounds new[i] = el
            return collect_to_structarray!(new, itr, i+1, st)
        end
    end
    return dest
end

function collect_structarray(itr, elem, ::Base.SizeUnknown; initializer = default_initializer)
    el, st = elem
    dest = initializer(typeof(el), (1,))
    dest[1] = el
    grow_to_structarray!(dest, itr, iterate(itr, st))
end

function grow_to_structarray!(dest::AbstractArray{T}, itr, elem = iterate(itr)) where {T}
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen the result type and re-dispatch.
    i = length(dest)+1
    while elem !== nothing
        el, st = elem
        if iseltype(el, dest)
            push!(dest, el)
            elem = iterate(itr, st)
            i += 1
        else
            new = widenstructarray(dest, i, el)
            push!(new, el)
            return grow_to_structarray!(new, itr, iterate(itr, st))
        end
    end
    return dest
end

function to_structarray(::Type{T}, nt::C) where {T, C}
    S = createtype(T, C)
    StructArray{S}(nt)
end

function widenstructarray(dest::StructArray{T}, i, el::S) where {T, S}
    fs = fields(S)
    if fs === fields(T)
        new_cols = (widenstructarray(fieldarrays(dest)[ind], i, getfieldindex(el, f, ind)) for (ind, f) in enumerate(fs))
        nt = NamedTuple{fs}(Tuple(new_cols))
        v = to_structarray(T, nt)
    else
        widenarray(dest, i, el)
    end
end

widenstructarray(dest::AbstractArray, i, el) = widenarray(dest, i, el)

function widenarray(dest::AbstractArray{T}, i, el::S) where {S, T}
    S <: T && return dest
    new = similar(dest, Base.promote_typejoin(S, T), length(dest))
    copyto!(new, 1, dest, 1, i-1)
    new
end
