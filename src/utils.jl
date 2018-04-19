import Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail

eltypes(::Type{Tuple{}}) = Tuple{}
eltypes(::Type{T}) where {T<:Tuple} =
    tuple_type_cons(eltype(tuple_type_head(T)), eltypes(tuple_type_tail(T)))
eltypes(::Type{NamedTuple{K, V}}) where {K, V} = eltypes(V)
fields(T) = fieldnames(T)
fields(::Type{<:NamedTuple{K}}) where {K} = K
#@inline ith_all(i, ::Tuple{}) = ()
#@inline ith_all(i, as) = (as[1][i], ith_all(i, tail(as))...)

@generated function ith_all(s::StructureArray{T}, I...) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        push!(args, :($field[I...]))
    end
    Expr(:call, :createinstance, :T, args...)
end

createinstance(::Type{T}, args...) where {T} = T(args...)
createinstance(::Type{T}, args...) where {T<:Tup} = T(args)

createtype(::Type{T}, ::Type{C}) where {T<:NamedTuple{N}, C} where {N} = NamedTuple{N, C}
createtype(::Type{T}, ::Type{C}) where {T, C} = T
