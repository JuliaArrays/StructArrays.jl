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

staticschema(::Type{T}) where {T<:NamedTuple} = T

tuple_type(::Type{NamedTuple{names, types}}) where {names, types} = types

function fields(::Type{T}) where {T}
    fieldnames(staticschema(T))
end

@generated function to_namedtuple(::Type{NT}, s::S) where {NT, S}
    names = fieldnames(NT)
    exprs = [Expr(:call, :getfieldindex, :s, QuoteNode(field), i) for (i, field) in enumerate(names)]
    tup = Expr(:call, :tuple, exprs...)
    :(NT($tup))
end

function to_namedtuple(s::S) where S
    to_namedtuple(staticschema(S), s)
end
