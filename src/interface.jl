const Tup = Union{Tuple, NamedTuple}
const EmptyTup = Union{Tuple{}, NamedTuple{(), Tuple{}}}

"""
    StructArrays.component(x, i)

Default to `getfield`. It should be overloaded for custom types with a custom
schema. See [`StructArrays.staticschema`](@ref).
"""
component(x, i) = getfield(x, i)

"""
    StructArrays.staticschema(T)

The default schema for an element type `T`. A schema is a `Tuple` or
`NamedTuple` type containing the necessary fields to construct `T`. By default,
this will have fields with the same names and types as `T`.

This can be overloaded for custom types if required, in which case
[`StructArrays.component`](@ref) and [`StructArrays.createinstance`](@ref)
should also be defined.
    
```julia-repl
julia> StructArrays.staticschema(Complex{Float64})
NamedTuple{(:re, :im),Tuple{Float64,Float64}}
```
"""
@generated function staticschema(::Type{T}) where {T}
    name_tuple = Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)
    type_tuple = Expr(:curly, :Tuple, [Expr(:call, :fieldtype, :T, i) for i in 1:fieldcount(T)]...)
    Expr(:curly, :NamedTuple, name_tuple, type_tuple)
end

staticschema(::Type{T}) where {T<:Tup} = T

"""
    StructArrays.createinstance(T, args...)

Construct an instance of type `T` from its backing representation. `args` here
are the elements of the `Tuple` or `NamedTuple` type specified
[`staticschema(T)`](@ref).

```julia-repl
julia> StructArrays.createinstance(Complex{Float64}, (re=1.0, im=2.0)...)
1.0 + 2.0im
```
"""
function createinstance(::Type{T}, args...)::T where {T}
    isconcretetype(T) ? bypass_constructor(T, args) : constructorof(T)(args...)
end

createinstance(::Type{T}, args...) where {T<:Tup} = T(args)

struct Instantiator{T} end

Instantiator(::Type{T}) where {T} = Instantiator{T}()

(::Instantiator{T})(args...) where {T} = createinstance(T, args...)
