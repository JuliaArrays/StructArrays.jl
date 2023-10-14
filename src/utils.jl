argtail(_, args...) = args

split_tuple_type(T) = fieldtype(T, 1), Tuple{argtail(T.parameters...)...}

eltypes(nt::NamedTuple{names}) where {names} = NamedTuple{names, eltypes(values(nt))}
eltypes(t::Tuple) = Tuple{map(eltype, t)...}

alwaysfalse(t) = false

"""
    StructArrays.map_params(f, T)

Apply `f` to each field type of `Tuple` or `NamedTuple` type `T`, returning a
new `Tuple` or `NamedTuple` object.

```julia-repl
julia> StructArrays.map_params(T -> Complex{T}, Tuple{Int32,Float64})
(Complex{Int32}, Complex{Float64})
```
"""
map_params(f::F, ::Type{T}) where {F, T<:Tup} = strip_params(T)(map_params_as_tuple(f, T))

function map_params_as_tuple(f::F, ::Type{T}) where {F, T<:Tup}
    if @generated
        types = fieldtypes(T)
        args = map(t -> :(f($t)), types)
        Expr(:tuple, args...)
    else
        map_params_as_tuple_fallback(f, T)
    end
end

map_params_as_tuple_fallback(f, ::Type{T}) where {T<:Tup} = map(f, fieldtypes(T))

buildfromschema(initializer::F, ::Type{T}) where {F, T} = buildfromschema(initializer, T, staticschema(T))

"""
    StructArrays.buildfromschema(initializer, T[, S])

Construct a [`StructArray{T}`](@ref) with a function `initializer`, using a schema `S`.

`initializer(T)` is a function applied to each field type of `S`, and should return an `AbstractArray{S}`

`S` is a `Tuple` or `NamedTuple` type. The default value is [`staticschema(T)`](@ref).
"""
function buildfromschema(initializer::F, ::Type{T}, ::Type{NT}) where {F, T, NT<:Tup}
    nt = map_params(initializer, NT)
    StructArray{T}(nt)
end

array_names_types(::Type{StructArray{T, N, C, I}}) where {T, N, C, I} = array_names_types(C)
array_names_types(::Type{NamedTuple{names, types}}) where {names, types} = zip(names, types.parameters)
array_names_types(::Type{T}) where {T<:Tuple} = enumerate(T.parameters)

function apply_f_to_vars_fields(names_types, vars)
    exprs = Expr[]
    for (name, type) in names_types
        sym = QuoteNode(name)
        args = [Expr(:call, :component, var, sym) for var in vars]
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

foreachfield(f::F, x::StructArray, xs::Vararg{Any, N}) where {F, N} = foreachfield_gen(x, f, x, xs...)

"""
    StructArrays.iscompatible(::Type{S}, ::Type{V}) where {S, V<:AbstractArray}

Check whether element type `S` can be pushed to a container of type `V`.
"""
iscompatible(::Type{S}, ::Type{<:AbstractArray{T}}) where {S, T} = S<:T
iscompatible(::Type{S}, ::Type{<:StructArray{<:Any, <:Any, C}}) where {S, C} = iscompatible(astuple(staticschema(S)), astuple(C))

iscompatible(::Type{Tuple{}}, ::Type{T}) where {T<:Tuple} = false
iscompatible(::Type{T}, ::Type{Tuple{}}) where {T<:Tuple} = false
iscompatible(::Type{Tuple{}}, ::Type{Tuple{}}) = true

function iscompatible(::Type{T}, ::Type{T′}) where {T<:Tuple, T′<:Tuple}
    (f, ls), (f′, ls′) = split_tuple_type(T), split_tuple_type(T′)
    iscompatible(f, f′) && iscompatible(ls, ls′)
end

iscompatible(::S, ::V) where {S, V<:AbstractArray} = iscompatible(S, V)

function _promote_typejoin(::Type{T}, ::Type{T′}) where {T<:NTuple{N, Any}, T′<:NTuple{N, Any}} where N
    (f, ls), (f′, ls′) = split_tuple_type(T), split_tuple_type(T′)
    return Tuple{_promote_typejoin(f, f′), _promote_typejoin(ls, ls′).parameters...}
end

_promote_typejoin(::Type{Tuple{}}, ::Type{Tuple{}}) = Tuple{}
function _promote_typejoin(::Type{NamedTuple{names, types}}, ::Type{NamedTuple{names, types′}}) where {names, types, types′}
    T = _promote_typejoin(types, types′)
    return NamedTuple{names, T}
end

_promote_typejoin(::Type{T}, ::Type{T′}) where {T, T′} = Base.promote_typejoin(T, T′)

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

Change storage type for components: each array `v` is replaced by `f(v)`. `f(v)` is expected to have the same
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
    "3-element StructArray(::UnitRange{Int64}, ::PooledArray{String,UInt32,1,Array{UInt32,1}}) with eltype $(NamedTuple{(:a, :b),Tuple{Int64,String}}):"
else
        "3-element StructArray(::UnitRange{Int64}, ::PooledVector{String, UInt32, Vector{UInt32}}) with eltype $(NamedTuple{(:a, :b), Tuple{Int64, String}}):"
end)
 (a = 1, b = "string")
 (a = 2, b = "string")
 (a = 3, b = "string")
```
"""
function replace_storage(f, s::StructArray{T}) where T
    cols = components(s)
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

isnonemptystructtype(::Type{T}) where {T} = isstructtype(T) && fieldcount(T) != 0

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

# Specialize this for types like LazyRow that shouldn't convert
"""
    StructArrays.maybe_convert_elt(T, x)

Element conversion before assignment in a StructArray.
By default, this calls `convert(T, x)`; however, you can specialize it for other types.
"""
maybe_convert_elt(::Type{T}, vals) where T = convert(T, vals)
maybe_convert_elt(::Type{T}, vals::Tuple) where T = T <: Tuple ? convert(T, vals) : vals  # assignment of fields by position
maybe_convert_elt(::Type{T}, vals::NamedTuple) where T = T<:NamedTuple ? convert(T, vals) : vals # assignment of fields by name

"""
    findconsistentvalue(f, componenents::Union{Tuple, NamedTuple})

Compute the unique value that `f` takes on each `component ∈ componenents`.
If not all values are equal, return `nothing`. Otherwise, return the unique value.
"""
function findconsistentvalue(f::F, cols::Tup) where F
    val = f(first(cols))
    isconsistent = all(map(isequal(val) ∘ f, values(cols)))
    return ifelse(isconsistent, val, nothing)
end
