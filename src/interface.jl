@generated function staticschema(::Type{T}) where {T}
    name_tuple = Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)
    type_tuple = Expr(:curly, :Tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:curly, :NamedTuple, name_tuple, type_tuple)
end

@generated function staticschema(::Type{T}) where {T<:Tuple}
    name_tuple = Expr(:tuple, [QuoteNode(Symbol("x$f")) for f in fieldnames(T)]...)
    type_tuple = Expr(:curly, :Tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:curly, :NamedTuple, name_tuple, type_tuple)
end

getnames(::Type{NamedTuple{names, types}}) where {names, types} = names
gettypes(::Type{NamedTuple{names, types}}) where {names, types} = types

function fields(::Type{T}) where {T}
    getnames(staticschema(T))
end

