module StructArraysStaticArraysCoreExt

using StructArrays
using StructArrays: StructArrayStyle, createinstance, replace_structarray, isnonemptystructtype

using Base.Broadcast: Broadcasted

using StaticArraysCore: StaticArray, FieldArray, tuple_prod

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
StructArrays.createinstance(::Type{T}, args...) where {T<:StaticArray} = T(args)
StructArrays.component(s::StaticArray, i) = getindex(s, i)

# invoke general fallbacks for a `FieldArray` type.
@inline function StructArrays.staticschema(T::Type{<:FieldArray})
    invoke(StructArrays.staticschema, Tuple{Type{<:Any}}, T)
end
StructArrays.component(s::FieldArray, i) = invoke(StructArrays.component, Tuple{Any, Any}, s, i)
StructArrays.createinstance(T::Type{<:FieldArray}, args...) = invoke(createinstance, Tuple{Type{<:Any}, Vararg}, T, args...)

# Broadcast overload
using StaticArraysCore: StaticArrayStyle, similar_type
StructStaticArrayStyle{N} = StructArrayStyle{StaticArrayStyle{N}, N}
function Broadcast.instantiate(bc::Broadcasted{StructStaticArrayStyle{M}}) where {M}
    bc′ = Broadcast.instantiate(replace_structarray(bc))
    return convert(Broadcasted{StructStaticArrayStyle{M}}, bc′)
end
# This looks costly, but the compiler should be able to optimize them away
Broadcast._axes(bc::Broadcasted{<:StructStaticArrayStyle}, ::Nothing) = axes(replace_structarray(bc))

# StaticArrayStyle has no similar defined.
# Overload `Base.copy` instead.
@inline function StructArrays.try_struct_copy(bc::Broadcasted{StaticArrayStyle{M}}) where {M}
    sa = copy(bc)
    ET = eltype(sa)
    isnonemptystructtype(ET) || return sa
    elements = Tuple(sa)
    @static if VERSION >= v"1.7"
        arrs = ntuple(Val(fieldcount(ET))) do i
            similar_type(sa, fieldtype(ET, i))(_getfields(elements, i))
        end
    else
        _fieldtype(::Type{T}) where {T} = i -> fieldtype(T, i)
        __fieldtype = _fieldtype(ET)
        arrs = ntuple(Val(fieldcount(ET))) do i
            similar_type(sa, __fieldtype(i))(_getfields(elements, i))
        end 
    end
    return StructArray{ET}(arrs)
end

@inline function _getfields(x::Tuple, i::Int)
    if @generated
        return Expr(:tuple, (:(getfield(x[$j], i)) for j in 1:fieldcount(x))...)
    else
        return map(Base.Fix2(getfield, i), x)
    end
end

end # module
