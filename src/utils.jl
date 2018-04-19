import Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail

eltypes(::Type{Tuple{}}) = Tuple{}
eltypes(::Type{T}) where {T<:Tuple} =
    tuple_type_cons(eltype(tuple_type_head(T)), eltypes(tuple_type_tail(T)))
eltypes(::Type{NamedTuple{K, V}}) where {K, V} = eltypes(V)

@generated function get_ith(s::StructureArray{T}, I...) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        push!(args, :($field[I...]))
    end
    Expr(:call, :createinstance, :T, args...)
end

@generated function set_ith!(s::StructureArray{T}, vals, I...) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        val = Expr(:., :vals, Expr(:quote, key))
        push!(args, :($field[I...] = $val))
    end
    push!(args, :s)
    Expr(:block, args...)
end

createinstance(::Type{T}, args...) where {T} = T(args...)
createinstance(::Type{T}, args...) where {T<:Tup} = T(args)

createtype(::Type{T}, ::Type{C}) where {T<:NamedTuple{N}, C} where {N} = NamedTuple{N, C}
createtype(::Type{T}, ::Type{C}) where {T, C} = T
