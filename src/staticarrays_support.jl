import StaticArrays: SArray, tuple_prod

"""
    StructArrays.staticschema(::Type{<:SArray{S, T}}) where {S, T}

The `staticschema` of an `SArray` element type is the `staticschema` of the underlying `Tuple`.
```julia
julia> StructArrays.staticschema(SVector{2, Float64})
Tuple{Float64, Float64}
```
"""
@generated function StructArrays.staticschema(::Type{<:SArray{S, T}}) where {S, T}
    return quote
        Base.@_inline_meta
        return NTuple{$(tuple_prod(S)), T}
    end
end
StructArrays.createinstance(::Type{T}, args...) where {T<:SArray} = T(args)
StructArrays.component(s::SArray, i) = getindex(s, i)
