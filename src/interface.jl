const Tup = Union{Tuple, NamedTuple}
const EmptyTup = Union{Tuple{}, NamedTuple{(), Tuple{}}}

@generated function staticschema(::Type{T}) where {T}
    name_tuple = Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)
    type_tuple = Expr(:curly, :Tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:curly, :NamedTuple, name_tuple, type_tuple)
end

staticschema(::Type{T}) where {T<:Tup} = T

@generated function bypass_constructor(type, args)
    vars = ntuple(_ -> gensym(), fieldcount(args))
    assign = [:($var = getfield(args, $i)) for (i, var) in enumerate(vars)]
    constructor = isconcretetype(type) ? :new : :call
    construct = Expr(constructor, :type, vars...)
    return Expr(:block, assign..., construct)
end

createinstance(::Type{T}, args...) where {T} = bypass_constructor(T, args)
createinstance(::Type{T}, args...) where {T<:Tup} = T(args)