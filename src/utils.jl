import Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail

eltypes(::Type{T}) where {T} = map_types(eltype, T)

map_types(f, ::Type{Tuple{}}) = Tuple{}
function map_types(f, ::Type{T}) where {T<:Tuple}
    tuple_type_cons(f(tuple_type_head(T)), map_types(f, tuple_type_tail(T)))
end
map_types(f, ::Type{NamedTuple{names, types}}) where {names, types} =
    NamedTuple{names, map_types(f, types)}

all_types(f, ::Type{Tuple{}}, ::Type{T}) where {T<:Tuple} = false
all_types(f, ::Type{T}, ::Type{Tuple{}}) where {T<:Tuple} = false
all_types(f, ::Type{Tuple{}}, ::Type{Tuple{}}) = true

function all_types(f, ::Type{S}, ::Type{T}) where {S<:Tuple, T<:Tuple}
    f(tuple_type_head(S), tuple_type_head(T)) && all_types(f, tuple_type_tail(S), tuple_type_tail(T))
end

all_types(f, ::Type{NamedTuple{n1, t1}}, ::Type{NamedTuple{n2, t2}}) where {n1, t1, n2, t2} =
    all_types(f, t1, t2)

map_params(f, ::Type{Tuple{}}) = ()
function map_params(f, ::Type{T}) where {T<:Tuple}
    (f(tuple_type_head(T)), map_params(f, tuple_type_tail(T))...)
end
map_params(f, ::Type{NamedTuple{names, types}}) where {names, types} =
    NamedTuple{names}(map_params(f, types))

buildfromschema(initializer, ::Type{T}) where {T} = buildfromschema(initializer, T, staticschema(T))

function buildfromschema(initializer, ::Type{T}, ::Type{NT}) where {T, NT<:NamedTuple}
    nt = map_params(initializer, NT)
    StructArray{T}(nt)
end

Base.@pure SkipConstructor(::Type) = false

@generated function foreachfield(::Type{<:NamedTuple{names}}, f, xs...) where {names}
    exprs = Expr[]
    for (i, field) in enumerate(names)
        sym = QuoteNode(field)
        args = [Expr(:call, :getfieldindex, :(getfield(xs, $j)), sym, i) for j in 1:length(xs)]
        push!(exprs, Expr(:call, :f, args...))
    end
    push!(exprs, :(return nothing))
    Expr(:block, exprs...)
end
foreachfield(f, x::T, xs...) where {T} = foreachfield(staticschema(T), f, x, xs...)

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

iseltype(::S, ::T) where {S, T<:AbstractArray} = iscompatible(S, T)

iscompatible(::Type{S}, ::Type{<:AbstractArray{T}}) where {S, T} = S<:T

function iscompatible(::Type{S}, ::Type{StructArray{T, N, C}}) where {S, T, N, C}
    all_types(iscompatible, staticschema(S), C)
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
10-element StructArray{NamedTuple{(:a, :b),Tuple{Int64,String}},1,NamedTuple{(:a, :b),Tuple{UnitRange{Int64},PooledArray{String,UInt8,1,Array{UInt8,1}}}}}:
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

