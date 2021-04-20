import StaticArrays: StaticArray, tuple_prod

"""
    StructArrays.staticschema(::Type{<:StaticArray{S, T}}) where {S, T}

The staticschema for a StaticArray is the underlying Tuple used to store the flattened array.
"""
@generated function StructArrays.staticschema(::Type{<:StaticArray{S, T}}) where {S, T}
    return quote
        Base.@_inline_meta
        return NTuple{$(tuple_prod(S)),T}
    end
end
StructArrays.createinstance(::Type{T}, args...) where {T<:StaticArray} = T(args)
StructArrays.component(s::StaticArray, i) = getindex(s, i)
