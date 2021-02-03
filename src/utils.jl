eltypes(::Type{T}) where {T} = map_params(eltype, T)

alwaysfalse(t) = false

"""
    StructArrays.map_params(f, T)

Apply `f` to each field type of `Tuple` or `NamedTuple` type `T`, returning a
new `Tuple` or `NamedTuple` type.

```julia-repl
julia> StructArrays.map_params(T -> Complex{T}, Tuple{Int32,Float64})
Tuple{Complex{Int32},Complex{Float64}}
```
"""
map_params(f, ::Type{Tuple{}}) = Tuple{}
function map_params(f, ::Type{T}) where {T<:Tuple}
    tuple_type_cons(f(tuple_type_head(T)), map_params(f, tuple_type_tail(T)))
end
map_params(f, ::Type{NamedTuple{names, types}}) where {names, types} =
    NamedTuple{names, map_params(f, types)}

"""
    StructArrays._map_params(f, T)

Apply `f` to each field type of `Tuple` or `NamedTuple` type `T`, returning a
new `Tuple` or `NamedTuple` object.

```julia-repl
julia> StructArrays._map_params(T -> Complex{T}, Tuple{Int32,Float64})
(Complex{Int32}, Complex{Float64})
```
"""
_map_params(f, ::Type{Tuple{}}) = ()
function _map_params(f, ::Type{T}) where {T<:Tuple}
    (f(tuple_type_head(T)), _map_params(f, tuple_type_tail(T))...)
end
_map_params(f::F, ::Type{NamedTuple{names, types}}) where {names, types, F} =
    NamedTuple{names}(_map_params(f, types))

buildfromschema(initializer::F, ::Type{T}) where {T, F} = buildfromschema(initializer, T, staticschema(T))

"""
    StructArrays.buildfromschema(initializer, T[, S])

Construct a [`StructArray{T}`](@ref) with a function `initializer`, using a schema `S`.

`initializer(T)` is a function applied to each field type of `S`, and should return an `AbstractArray{S}`

`S` is a `Tuple` or `NamedTuple` type. The default value is [`staticschema(T)`](@ref).
"""
function buildfromschema(initializer::F, ::Type{T}, ::Type{NT}) where {T, NT<:Tup, F}
    nt = _map_params(initializer, NT)
    StructArray{T}(nt)
end

array_names_types(::Type{StructArray{T, N, C, I}}) where {T, N, C, I} = array_names_types(C)
array_names_types(::Type{NamedTuple{names, types}}) where {names, types} = zip(names, types.parameters)
array_names_types(::Type{T}) where {T<:Tuple} = enumerate(T.parameters)

function apply_f_to_vars_fields(names_types, vars)
    exprs = Expr[]
    for (name, type) in names_types
        sym = QuoteNode(name)
        args = [Expr(:call, :_getfield, var, sym) for var in vars]
        expr = if type <: StructArray
            apply_f_to_vars_fields(array_names_types(type), args)
        else
            Expr(:call, :f, args...)
        end
        push!(exprs, expr)
    end
    return Expr(:block, exprs...)
end

function _foreachfield(names_types, L)
    vars = ntuple(i -> gensym(), L)
    exprs = Expr[]
    for (i, v) in enumerate(vars)
        push!(exprs, Expr(:(=), v, Expr(:call, :getfield, :xs, i)))
    end
    push!(exprs, apply_f_to_vars_fields(names_types, vars))
    push!(exprs, :(return nothing))
    return Expr(:block, exprs...)
end

@generated foreachfield_gen(::S, f, xs::Vararg{Any, L}) where {S<:StructArray, L} =
    _foreachfield(array_names_types(S), L)

foreachfield(f, x::StructArray, xs...) = foreachfield_gen(x, f, x, xs...)

"""
    StructArrays.iscompatible(::Type{S}, ::Type{V}) where {S, V<:AbstractArray}

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
    StructArrays.replace_storage(f, s::StructArray)

Change storage type for fieldarrays: each array `v` is replaced by `f(v)`. `f(v) is expected to have the same
`eltype` and `size` as `v`.

## Examples

If PooledArrays is loaded, we can pool all columns of non `isbitstype`:

```jldoctest
julia> using StructArrays, PooledArrays

julia> s = StructArray(a=1:3, b = fill("string", 3));

julia> s_pooled = StructArrays.replace_storage(s) do v
           isbitstype(eltype(v)) ? v : convert(PooledArray, v)
       end
$(if VERSION < v"1.6-" 
    "3-element StructArray(::UnitRange{Int64}, ::PooledArray{String,UInt32,1,Array{UInt32,1}}) with eltype NamedTuple{(:a, :b),Tuple{Int64,String}}:"
else
        "3-element StructArray(::UnitRange{Int64}, ::PooledVector{String, UInt32, Vector{UInt32}}) with eltype NamedTuple{(:a, :b), Tuple{Int64, String}}:"
end)
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

"""
    StructArrays.bypass_constructor(T, args)

Create an instance of type `T` from a tuple of field values `args`, bypassing
possible internal constructors. `T` should be a concrete type.
"""
@generated function bypass_constructor(::Type{T}, args) where {T}
    vars = ntuple(_ -> gensym(), fieldcount(T))
    assign = [:($var::$(fieldtype(T, i)) = getfield(args, $i)) for (i, var) in enumerate(vars)]
    construct = Expr(:new, :T, vars...)
    Expr(:block, assign..., construct)
end
