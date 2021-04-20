import StaticArrays: StaticArray, tuple_prod

@generated function StructArrays.staticschema(::Type{<:StaticArray{S, T}}) where {S, T}
    return quote
        Base.@_inline_meta
        return NTuple{$(tuple_prod(S)),T}
    end
end
StructArrays.createinstance(::Type{T}, args...) where {T<:StaticArray} = T(args...)
StructArrays.component(s::T, i) where {T <: StaticArray} = getindex(s, i)
