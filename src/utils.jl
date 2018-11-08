import Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail

eltypes(::Type{Tuple{}}) = Tuple{}
eltypes(::Type{T}) where {T<:Tuple} =
    tuple_type_cons(eltype(tuple_type_head(T)), eltypes(tuple_type_tail(T)))
eltypes(::Type{NamedTuple{K, V}}) where {K, V} = eltypes(V)

Base.@pure SkipConstructor(::Type) = false

function foreach_expr(f, T, args...)
    exprs = []
    for (ind, key) in enumerate(fields(T))
        new_args = (Expr(:call, :getfieldindex, arg, Expr(:quote, key), ind) for arg in args)
        push!(exprs, f(new_args...))
    end
    exprs
end

@generated function get_ith(s::StructArray{T}, I...) where {T}
    exprs = foreach_expr(field -> :($field[I...]), T, :s)
    return quote
        @boundscheck checkbounds(s, I...)
        @inbounds $(Expr(:call, :createinstance, :T, exprs...))
    end
end

@generated function set_ith!(s::StructArray{T}, vals, I...) where {T}
    exprs = foreach_expr((field, val) -> :($field[I...] = $val), T, :s, :vals)
    push!(exprs, :s)
    return quote
        @boundscheck checkbounds(s, I...)
        @inbounds $(Expr(:block, exprs...))
    end
end

function createinstance(::Type{T}, args...) where {T}
    SkipConstructor(T) ? unsafe_createinstance(T, args...) : T(args...)
end

createinstance(::Type{T}, args...) where {T<:Union{Tuple, NamedTuple}} = T(args)

@generated function unsafe_createinstance(::Type{T}, args...) where {T}
    v = fieldnames(T)
    new_tup = Expr(:(=), Expr(:tuple, v...), :args)
    construct = Expr(:new, :T, (:(convert(fieldtype(T, $(Expr(:quote, sym))), $sym)) for sym in v)...)
    Expr(:block, new_tup, construct)
end

createtype(::Type{T}, ::Type{C}) where {T<:NamedTuple{N}, C} where {N} = NamedTuple{N, C}
createtype(::Type{T}, ::Type{C}) where {T, C} = T
