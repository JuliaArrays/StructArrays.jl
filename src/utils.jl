import Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail

eltypes(::Type{Tuple{}}) = Tuple{}
eltypes(::Type{T}) where {T<:Tuple} =
    tuple_type_cons(eltype(tuple_type_head(T)), eltypes(tuple_type_tail(T)))
eltypes(::Type{NamedTuple{K, V}}) where {K, V} = eltypes(V)

@generated function get_ith(s::StructArray{T}, I...) where {T}
    exprs = Expr[]
    names = fields(T)
    for key in names
        field = Expr(:., :s, Expr(:quote, key))
        push!(exprs, :($key = $field[I...]))
    end
    if isconcretetype(T)
        push!(exprs, Expr(:new, :T, names...))
    elseif T <: Union{Tuple, NamedTuple}
        push!(exprs, Expr(:call, :T, Expr(:tuple, names...)))
    else
        push!(exprs, Expr(:call, :T, names...))
    end
    return quote
        @boundscheck checkbounds(s, I...)
        @inbounds $(Expr(:block, exprs...))
    end
end

@generated function set_ith!(s::StructArray{T}, vals, I...) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        val = Expr(:., :vals, Expr(:quote, key))
        push!(args, :($field[I...] = $val))
    end
    push!(args, :s)
    return quote
        @boundscheck checkbounds(s, I...)
        @inbounds $(Expr(:block, args...))
    end
end

createtype(::Type{T}, ::Type{C}) where {T<:NamedTuple{N}, C} where {N} = NamedTuple{N, C}
createtype(::Type{T}, ::Type{C}) where {T, C} = T
