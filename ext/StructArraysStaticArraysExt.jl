module StructArraysStaticArraysExt

using StructArrays
using StaticArrays: StaticArray, FieldArray, tuple_prod

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
StructArrays.createinstance(T::Type{<:FieldArray}, args...) = invoke(StructArrays.createinstance, Tuple{Type{<:Any}, Vararg}, T, args...)

# Broadcast overload
using StaticArrays: StaticArrayStyle, similar_type, Size, SOneTo
using StaticArrays: broadcast_flatten, broadcast_sizes, first_statictype, __broadcast
using StructArrays: isnonemptystructtype
using Base.Broadcast: Broadcasted

# StaticArrayStyle has no similar defined.
# Overload `try_struct_copy` instead.
@inline function StructArrays.try_struct_copy(bc::Broadcasted{StaticArrayStyle{M}}) where {M}
    flat = broadcast_flatten(bc); as = flat.args; f = flat.f
    argsizes = broadcast_sizes(as...)
    ax = axes(bc)
    ax isa Tuple{Vararg{SOneTo}} || error("Dimension is not static. Please file a bug at `StaticArrays.jl`.")
    return _broadcast(f, Size(map(length, ax)), argsizes, as...)
end

@inline function _broadcast(f, sz::Size{newsize}, s::Tuple{Vararg{Size}}, a...) where {newsize}
    first_staticarray = first_statictype(a...)
    elements, ET = if prod(newsize) == 0
        # Use inference to get eltype in empty case (see also comments in _map)
        eltys = Tuple{map(eltype, a)...}
        (), Core.Compiler.return_type(f, eltys)
    else
        temp = __broadcast(f, sz, s, a...)
        temp, eltype(temp)
    end
    if isnonemptystructtype(ET)
        @static if VERSION >= v"1.7"
            arrs = ntuple(Val(fieldcount(ET))) do i
                @inbounds similar_type(first_staticarray, fieldtype(ET, i), sz)(_getfields(elements, i))
            end
        else
            similarET(::Type{SA}, ::Type{T}) where {SA, T} = i -> @inbounds similar_type(SA, fieldtype(T, i), sz)(_getfields(elements, i))
            arrs = ntuple(similarET(first_staticarray, ET), Val(fieldcount(ET)))
        end
        return StructArray{ET}(arrs)
    end
    @inbounds return similar_type(first_staticarray, ET, sz)(elements)
end

@inline function _getfields(x::Tuple, i::Int)
    if @generated
        return Expr(:tuple, (:(getfield(x[$j], i)) for j in 1:fieldcount(x))...)
    else
        return map(Base.Fix2(getfield, i), x)
    end
end

end
