const Tup = Union{Tuple, NamedTuple}
const EmptyTup = Union{Tuple{}, NamedTuple{(), Tuple{}}}

@generated function staticschema(::Type{T}) where {T}
    name_tuple = Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)
    type_tuple = Expr(:curly, :Tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:curly, :NamedTuple, name_tuple, type_tuple)
end

staticschema(::Type{T}) where {T<:Tup} = T

astuple(::Type{NamedTuple{names, types}}) where {names, types} = types
astuple(::Type{T}) where {T<:Tuple} = T

strip_params(::Type{<:Tuple}) = Tuple
strip_params(::Type{<:NamedTuple{names}}) where {names} = NamedTuple{names}
