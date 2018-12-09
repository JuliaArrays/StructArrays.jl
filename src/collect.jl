_is_subtype(::Type{S}, ::Type{T}) where {S, T} = promote_type(S, T) == T

collect_columns(itr; unwrap = t -> false) = collect_columns(itr, Base.IteratorSize(itr), unwrap = unwrap)

function collect_empty_columns(itr::T; unwrap = t -> false) where {T}
    S = Core.Compiler.return_type(first, Tuple{T})
    _undef_array(S, 0, unwrap = unwrap)
end

function collect_columns(@nospecialize(itr), ::Union{Base.HasShape, Base.HasLength}; unwrap = t -> false)
    st = iterate(itr)
    st === nothing && return collect_empty_columns(itr)
    el, i = st
    dest = _undef_array(typeof(el), length(itr), unwrap = unwrap)
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
        if fieldwise_isa(el, T)
            @inbounds dest[i] = el
            i += 1
        else
            new = widencolumns(dest, i, el, T)
            @inbounds new[i] = el
            return collect_to_columns!(new, itr, i+1, st)
        end
    end
    return dest
end

function collect_columns(itr, ::Base.SizeUnknown; unwrap = t -> false)
    elem = iterate(itr)
    elem === nothing && return collect_empty_columns(itr; unwrap = unwrap)
    el, st = elem
    dest = _undef_array(typeof(el), 1, unwrap = unwrap)
    dest[1] = el
    grow_to_columns!(dest, itr, iterate(itr, st))
end

function grow_to_columns!(dest::AbstractArray{T}, itr, elem = iterate(itr)) where {T}
    # collect to dest array, checking the type of each result. if a result does not
    # match, widen the result type and re-dispatch.
    i = length(dest)+1
    while elem !== nothing
        el, st = elem
        if fieldwise_isa(el, T)
            push!(dest, el)
            elem = iterate(itr, st)
            i += 1
        else
            new = widencolumns(dest, i, el, T)
            push!(new, el)
            return grow_to_columns!(new, itr, iterate(itr, st))
        end
    end
    return dest
end

_is_subeltype(::Type{S}, ::Type{<:AbstractArray{T}}) where {S, T} = _is_subtype(S, T) 
function _is_subeltype(::Type{S}, ::Type{StructArray{T, N, C}}) where {S, T, N, C}
    same_fields = fields(S) == keys(C)
    compatible_types = all(_is_subeltype(s, t) for (s, t) in zip(fieldtypes(S), C))
    same_fields && compatible_types
end

function widencolumns(dest::A, i, ::Type{S}) where {A<:StructArray, S}
    new_cols = Any[columns(dest)...]
    for (col_num, typ) in enumerate(fieldtypes(S))
        new_cols[col_num] = widencolumns(new_cols[col_num], i, typ)
    end
    new_typ = promoted_eltype(S, A) 
    StructArray{new_typ}(new_cols...)
end

function widencolumns(dest::AbstractArray{T}, i, ::Type{S}) where {S, T}
    new = Array{promote_type(S, T)}(undef, length(dest))
    copyto!(new, 1, dest, 1, i-1)
    new
end
