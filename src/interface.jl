const Tup = Union{Tuple, NamedTuple}

@generated function staticschema(::Type{T}) where {T}
    name_tuple = Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)
    type_tuple = Expr(:curly, :Tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:curly, :NamedTuple, name_tuple, type_tuple)
end

staticschema(::Type{T}) where {T<:Tup} = T

tuple_type(::Type{NamedTuple{names, types}}) where {names, types} = types
tuple_type(::Type{T}) where {T<:Tuple} = T

function fields(::Type{T}) where {T}
    fieldnames(staticschema(T))
end

drop_types(::Type{<:Tuple}) = Tuple
drop_types(::Type{<:NamedTuple{names}}) where {names} = NamedTuple{names}
