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
# This looks costy, but compiler should be able to optimize them away
Broadcast._axes(bc::Broadcasted{<:StructStaticArrayStyle}, ::Nothing) = axes(replace_structarray(bc))

to_staticstyle(@nospecialize(x::Type)) = x
to_staticstyle(::Type{StructStaticArrayStyle{N}}) where {N} = StaticArrayStyle{N}
function replace_structarray(bc::Broadcasted{Style}) where {Style}
    args = replace_structarray_args(bc.args)
    return Broadcasted{to_staticstyle(Style)}(bc.f, args, nothing)
end
function replace_structarray(A::StructArray)
    f = createinstance(eltype(A))
    args = Tuple(components(A))
    return Broadcasted{StaticArrayStyle{ndims(A)}}(f, args, nothing)
end
replace_structarray(@nospecialize(A)) = A

replace_structarray_args(args::Tuple) = (replace_structarray(args[1]), replace_structarray_args(Base.tail(args))...)
replace_structarray_args(::Tuple{}) = ()

# StaticArrayStyle has no similar defined.
# Overload `Base.copy` instead.
@inline function Base.copy(bc::Broadcasted{StructStaticArrayStyle{M}}) where {M}
    sa = copy(convert(Broadcasted{StaticArrayStyle{M}}, bc))
    ET = eltype(sa)
    isnonemptystructtype(ET) || return sa
    elements = Tuple(sa)
    arrs = ntuple(Val(fieldcount(ET))) do i
        similar_type(sa, fieldtype(ET, i))(_getfields(elements, i))
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
