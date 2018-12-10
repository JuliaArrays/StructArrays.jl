@generated function staticschema(::Type{T}) where {T}
    name_tuple = Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)
    type_tuple = Expr(:tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:tuple, name_tuple, type_tuple)
end

@generated function staticschema(::Type{T}) where {T <: Tuple}
    name_tuple = Expr(:tuple, [QuoteNode(Symbol("x$f")) for f in fieldnames(T)]...)
    type_tuple = Expr(:tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:tuple, name_tuple, type_tuple)
end

function fields(t::Type{T}) where {T}
    names, _ = staticschema(T)
    names
end
