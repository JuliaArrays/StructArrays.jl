import StaticArrays: StaticArray, FieldArray, tuple_prod

"""
    StructArrays.staticschema(::Type{<:StaticArray{S, T}}) where {S, T}

The `staticschema` of a `StaticArray` element type is the `staticschema` of the underlying `Tuple`.
```julia
julia> StructArrays.staticschema(SVector{2, Float64})
Tuple{Float64, Float64}
```
The one exception to this rule is `<:StaticArrays.FieldArray`, since `FieldArray` is based on a 
struct. In this case, `staticschema(<:FieldArray)` returns the `staticschema` for the struct 
which subtypes `FieldArray`. 
"""
@generated function StructArrays.staticschema(::Type{<:StaticArray{S, T}}) where {S, T}
    return quote
        Base.@_inline_meta
        return NTuple{$(tuple_prod(S)), T}
    end
end
# invoke the general fallback for a `FieldArray` type.
@inline function StructArrays.staticschema(T::Type{<:FieldArray})
    invoke(StructArrays.staticschema, Tuple{Type{<:Any}}, T)
end
StructArrays.createinstance(::Type{T}, args...) where {T<:StaticArray} = T(args)
StructArrays.component(s::StaticArray, i) = getindex(s, i)
