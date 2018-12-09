struct StructArrayInitializer{F}
    unwrap::F
end
StructArrayInitializer() = StructArrayInitializer(t -> false)

const default_initializer = StructArrayInitializer()

(s::StructArrayInitializer)(S, d) = StructArray{S}(undef, d; unwrap = s.unwrap)

struct ArrayInitializer{F}
    unwrap::F
end
ArrayInitializer() = ArrayInitializer(t -> false)

(s::ArrayInitializer)(S, d) = _undef_array(S, d; unwrap = s.unwrap)

_reshape(v, itr, ::Base.HasShape) = reshape(v, axes(itr))
_reshape(v, itr, ::Union{Base.HasLength, Base.SizeUnknown}) = v

function collect_columns(itr; initializer = default_initializer)
    sz = Base.IteratorSize(itr)
    v = collect_columns(itr, sz, initializer = initializer)
    _reshape(v, itr, sz)
end

function collect_empty_columns(itr::T; initializer = default_initializer) where {T}
    S = Core.Compiler.return_type(first, Tuple{T})
    initializer(S, (0,))
end

function collect_columns(@nospecialize(itr), ::Union{Base.HasShape, Base.HasLength};
    initializer = default_initializer)

    st = iterate(itr)
    st === nothing && return collect_empty_columns(itr, initializer = initializer)
    el, i = st
    dest = initializer(typeof(el), (length(itr),))
    dest[1] = el
    collect_to_columns!(dest, itr, 2, i)
end

function collect_to_columns!(dest::AbstractArray{T}, itr, offs, st) where {T}
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen the result type and re-dispatch.
    i = offs
    while true
        elem = iterate(itr, st)
        elem === nothing && break
        el, st = elem
        if isa(el, T)
            @inbounds dest[i] = el
            i += 1
        else
            new = widencolumns(dest, i, el)
            @inbounds new[i] = el
            return collect_to_columns!(new, itr, i+1, st)
        end
    end
    return dest
end

function collect_columns(itr, ::Base.SizeUnknown; initializer = default_initializer)
    elem = iterate(itr)
    elem === nothing && return collect_empty_columns(itr; initializer = initializer)
    el, st = elem
    dest = initializer(typeof(el), (1,))
    dest[1] = el
    grow_to_columns!(dest, itr, iterate(itr, st))
end

function grow_to_columns!(dest::AbstractArray{T}, itr, elem = iterate(itr)) where {T}
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen the result type and re-dispatch.
    i = length(dest)+1
    while elem !== nothing
        el, st = elem
        if isa(el, T)
            push!(dest, el)
            elem = iterate(itr, st)
            i += 1
        else
            new = widencolumns(dest, i, el)
            push!(new, el)
            return grow_to_columns!(new, itr, iterate(itr, st))
        end
    end
    return dest
end

function to_structarray(::Type{T}, nt::C) where {T, C}
    S = createtype(T, C)
    StructArray{S}(nt)
end

function widencolumns(dest::StructArray{T}, i, el::S) where {T, S}
    fs = fields(S)
    if fs === fields(T)
        new_cols = (widencolumns(columns(dest)[ind], i, getfieldindex(el, f, ind)) for (ind, f) in enumerate(fs))
        nt = NamedTuple{fs}(Tuple(new_cols))
        v = to_structarray(T, nt)
    else
        widenarray(dest, i, el)
    end
end

widencolumns(dest::AbstractArray, i, el) = widenarray(dest, i, el)

function widenarray(dest::AbstractArray{T}, i, el::S) where {S, T}
    S <: T && return dest
    new = Array{promote_type(S, T)}(undef, length(dest))
    copyto!(new, 1, dest, 1, i-1)
    new
end
