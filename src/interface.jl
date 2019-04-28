const Tup = Union{Tuple, NamedTuple}
const EmptyTup = Union{Tuple{}, NamedTuple{(), Tuple{}}}

staticschema(::Type{T}) where {T} = hasfields(T) ? _staticschema(T) : nothing

@generated function _staticschema(::Type{T}) where {T}
    name_tuple = Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)
    type_tuple = Expr(:curly, :Tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:curly, :NamedTuple, name_tuple, type_tuple)
end

_staticschema(::Type{T}) where {T<:Tup} = T

createinstance(::Type{T}, args...) where {T} = T(args...)
createinstance(::Type{T}, args...) where {T<:Union{Tuple, NamedTuple}} = T(args)
