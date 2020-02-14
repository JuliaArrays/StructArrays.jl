eltypes(::Type{T}) where {T} = map_params(eltype, T)

map_params(f, ::Type{Tuple{}}) = Tuple{}
function map_params(f, ::Type{T}) where {T<:Tuple}
    tuple_type_cons(f(tuple_type_head(T)), map_params(f, tuple_type_tail(T)))
end
map_params(f, ::Type{NamedTuple{names, types}}) where {names, types} =
    NamedTuple{names, map_params(f, types)}

_map_params(f, ::Type{Tuple{}}) = ()
function _map_params(f, ::Type{T}) where {T<:Tuple}
    (f(tuple_type_head(T)), _map_params(f, tuple_type_tail(T))...)
end
_map_params(f, ::Type{NamedTuple{names, types}}) where {names, types} =
    NamedTuple{names}(_map_params(f, types))

buildfromschema(initializer, ::Type{T}) where {T} = buildfromschema(initializer, T, staticschema(T))

function buildfromschema(initializer, ::Type{T}, ::Type{NT}) where {T, NT<:Tup}
    nt = _map_params(initializer, NT)
    StructArray{T}(nt)
end

function _foreachfield(names, L)
    vars = ntuple(i -> gensym(), L)
    exprs = Expr[]
    for (i, v) in enumerate(vars)
        push!(exprs, Expr(:(=), v, Expr(:call, :getfield, :xs, i)))
    end
    for field in names
        sym = QuoteNode(field)
        args = [Expr(:call, :getcolumn, var, sym) for var in vars]
        push!(exprs, Expr(:call, :f, args...))
    end
    push!(exprs, :(return nothing))
    return Expr(:block, exprs...)
end

@generated foreachfield(::Type{<:NamedTuple{names}}, f, xs::Vararg{Any, L}) where {names, L} =
    _foreachfield(names, L)
@generated foreachfield(::Type{<:NTuple{N, Any}}, f, xs::Vararg{Any, L}) where {N, L} =
    _foreachfield(Base.OneTo(N), L)

foreachfield(f, x::T, xs...) where {T} = foreachfield(staticschema(T), f, x, xs...)

"""
`iscompatible(::Type{S}, ::Type{V}) where {S, V<:AbstractArray}`

Check whether element type `S` can be pushed to a container of type `V`.
"""
iscompatible(::Type{S}, ::Type{<:AbstractArray{T}}) where {S, T} = S<:T
iscompatible(::Type{S}, ::Type{<:StructArray{<:Any, <:Any, C}}) where {S, C} = iscompatible(astuple(staticschema(S)), astuple(C))

iscompatible(::Type{Tuple{}}, ::Type{T}) where {T<:Tuple} = false
iscompatible(::Type{T}, ::Type{Tuple{}}) where {T<:Tuple} = false
iscompatible(::Type{Tuple{}}, ::Type{Tuple{}}) = true

function iscompatible(::Type{S}, ::Type{T}) where {S<:Tuple, T<:Tuple}
    iscompatible(tuple_type_head(S), tuple_type_head(T)) && iscompatible(tuple_type_tail(S), tuple_type_tail(T))
end

iscompatible(::S, ::T) where {S, T<:AbstractArray} = iscompatible(S, T)

function _promote_typejoin(::Type{S}, ::Type{T}) where {S<:NTuple{N, Any}, T<:NTuple{N, Any}} where N
    head = _promote_typejoin(Base.tuple_type_head(S), Base.tuple_type_head(T))
    tail = _promote_typejoin(Base.tuple_type_tail(S), Base.tuple_type_tail(T))
    return Base.tuple_type_cons(head, tail)
end

_promote_typejoin(::Type{Tuple{}}, ::Type{Tuple{}}) = Tuple{}
function _promote_typejoin(::Type{NamedTuple{names, types}}, ::Type{NamedTuple{names, types′}}) where {names, types, types′}
    T = _promote_typejoin(types, types′)
    return NamedTuple{names, T}
end

_promote_typejoin(::Type{S}, ::Type{T}) where {S, T} = Base.promote_typejoin(S, T)

function _promote_typejoin(::Type{Pair{A, B}}, ::Type{Pair{A′, B′}}) where {A, A′, B, B′}
    C = _promote_typejoin(A, A′)
    D = _promote_typejoin(B, B′)
    return Pair{C, D}
end

function replace_storage(f, v::AbstractArray{T, N})::AbstractArray{T, N} where {T, N}
    f(v)
end

"""
`replace_storage(f, s::StructArray)`

Change storage type for fieldarrays: each array `v` is replaced by `f(v)`. `f(v) is expected to have the same
`eltype` and `size` as `v`.

## Examples

If PooledArrays is loaded, we can pool all columns of non `isbitstype`:

```jldoctest
julia> using PooledArrays

julia> s = StructArray(a=1:3, b = fill("string", 3));

julia> s_pooled = StructArrays.replace_storage(s) do v
           isbitstype(eltype(v)) ? v : convert(PooledArray, v)
       end
3-element StructArray(::UnitRange{Int64}, ::PooledArray{String,UInt8,1,Array{UInt8,1}}) with eltype NamedTuple{(:a, :b),Tuple{Int64,String}}:
 (a = 1, b = "string")
 (a = 2, b = "string")
 (a = 3, b = "string")
```
"""
function replace_storage(f, s::StructArray{T}) where T
    cols = fieldarrays(s)
    newcols = map(t -> replace_storage(f, t), cols)
    StructArray{T}(newcols)
end

astuple(::Type{NamedTuple{names, types}}) where {names, types} = types
astuple(::Type{T}) where {T<:Tuple} = T

strip_params(::Type{<:Tuple}) = Tuple
strip_params(::Type{<:NamedTuple{names}}) where {names} = NamedTuple{names}

hasfields(::Type{<:Tup}) = false
hasfields(::Type{<:NTuple{N, Any}}) where {N} = true
hasfields(::Type{<:NamedTuple{names}}) where {names} = true
hasfields(::Type{T}) where {T} = !isabstracttype(T)
hasfields(::Union) = false

_setdiff(a, b) = setdiff(a, b)

@inline _setdiff(::Tuple{}, ::Tuple{}) = ()
@inline _setdiff(::Tuple{}, ::Tuple) = ()
@inline _setdiff(a::Tuple, ::Tuple{}) = a
@inline _setdiff(a::Tuple, b::Tuple) = _setdiff(_exclude(a, b[1]), Base.tail(b))
@inline _exclude(a, b) = foldl((ys, x) -> x == b ? ys : (ys..., x), a; init = ())
