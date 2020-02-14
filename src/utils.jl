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

@static if VERSION < v"1.2.0"
    @inline _getproperty(v::Tuple, field) = getfield(v, field)
    @inline _getproperty(v, field) = getproperty(v, field)
else
    const _getproperty = getproperty
end

function _foreachfield(names, xs)
    exprs = Expr[]
    for field in names
        sym = QuoteNode(field)
        args = [Expr(:call, :_getproperty, :(getfield(xs, $j)), sym) for j in 1:length(xs)]
        push!(exprs, Expr(:call, :f, args...))
    end
    push!(exprs, :(return nothing))
    return Expr(:block, exprs...)
end

@generated foreachfield(::Type{<:NamedTuple{names}}, f, xs...) where {names} = _foreachfield(names, xs)
@generated foreachfield(::Type{<:NTuple{N, Any}}, f, xs...) where {N} = _foreachfield(Base.OneTo(N), xs)

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

to_tup(c::T) where {T} = to_tup(c, fieldnames(staticschema(T)))
function to_tup(c, fields::NTuple{N, Symbol}) where N
    t = ntuple(i -> getproperty(c, fields[i]), N)
    return NamedTuple{fields}(t)
end
to_tup(c, fields::NTuple{N, Int}) where {N} = ntuple(i -> _getproperty(c, fields[i]), N)

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

# _foreach(f, xs) = foreach(f, xs)
_foreach(f, xs::Tuple) = foldl((_, x) -> (f(x); nothing), xs; init = nothing)
# Note `foreach` is not optimized for tuples yet.
# See: https://github.com/JuliaLang/julia/pull/31901
