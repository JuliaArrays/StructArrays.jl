import Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail

eltypes(::Type{Tuple{}}) = Tuple{}
eltypes(::Type{T}) where {T<:Tuple} =
    tuple_type_cons(eltype(tuple_type_head(T)), eltypes(tuple_type_tail(T)))
eltypes(::Type{NamedTuple{K, V}}) where {K, V} = NamedTuple{K, eltypes(V)}

arraytypes(::Type{Tuple{}}, ::Tuple{Vararg{Any, N}}; unwrap = t -> false) where N = Tuple{}

function arraytypes(::Type{T}, sz::Tuple{Vararg{Any, N}}; unwrap = t -> false) where {N, T<:Tuple}
    T1 = tuple_type_head(T)
    AT = unwrap(T1) ? StructArray{T1, N, arraytypes(staticschema(T1), sz; unwrap = unwrap)} : Array{T1, N}
    tuple_type_cons(AT, arraytypes(tuple_type_tail(T), sz; unwrap = unwrap))
end

function arraytypes(::Type{NamedTuple{K, V}}, sz::Tuple{Vararg{Any, N}}; unwrap = t-> false) where {N, K, V}
    NamedTuple{K, arraytypes(V, sz; unwrap = unwrap)}
end

Base.@pure SkipConstructor(::Type) = false

@generated function foreachcolumn(f, x::StructArray{T, N, NamedTuple{names, types}}, v) where {T, N, names, types}
    exprs = Expr[]
    for (i, field) in enumerate(names)
        sym = QuoteNode(field)
        push!(exprs, Expr(:call, :f, Expr(:., :x, sym), Expr(:call, :getfieldindex, :v, sym, i)))
    end
    Expr(:block, exprs...)
end

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

function set_ith!(s::StructArray, vals, I...)
    @boundscheck checkbounds(s, I...)
    @inbounds foreachcolumn((col, val) -> (col[I...] = val), s, vals)
    s
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

createtype(::Type{T}, ::Type{NamedTuple{names, types}}) where {T, names, types} = createtype(T, names, eltypes(types))

createtype(::Type{T}, names, types) where {T} = T
createtype(::Type{T}, names, types) where {T<:Tuple} = types
createtype(::Type{<:NamedTuple{T}}, names, types) where {T} = NamedTuple{T, types}
function createtype(::Type{<:Pair}, names, types)
    tp = types.parameters
    Pair{tp[1], tp[2]}
end
