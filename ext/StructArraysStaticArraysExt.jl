module StructArraysStaticArraysExt

using StructArrays
using StaticArrays: StaticArray, FieldArray, tuple_prod, SVector, MVector

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
StructArrays.component(s::StaticArray, i::Integer) = getindex(s, i)

function StructArrays.component(s::StructArray{<:Union{SVector,MVector}}, key::Symbol)
    i = key == :x ? 1 : 
        key == :y ? 2 : 
        key == :z ? 3 : 
        key == :w ? 4 : 
        throw(ArgumentError("invalid key $key"))
    StructArrays.component(s, i)
end

# invoke general fallbacks for a `FieldArray` type.
@inline function StructArrays.staticschema(T::Type{<:FieldArray})
    invoke(StructArrays.staticschema, Tuple{Type{<:Any}}, T)
end
StructArrays.component(s::FieldArray, i) = invoke(StructArrays.component, Tuple{Any, Any}, s, i)
StructArrays.createinstance(T::Type{<:FieldArray}, args...) = invoke(StructArrays.createinstance, Tuple{Type{<:Any}, Vararg}, T, args...)

# Broadcast overload
using StaticArrays: StaticArrayStyle, similar_type, Size, SOneTo
using StaticArrays: broadcast_flatten, broadcast_sizes, first_statictype
using StructArrays: isnonemptystructtype
using Base.Broadcast: Broadcasted, _broadcast_getindex

# StaticArrayStyle has no similar defined.
# Overload `try_struct_copy` instead.
@inline function StructArrays.try_struct_copy(bc::Broadcasted{StaticArrayStyle{M}}) where {M}
    flat = broadcast_flatten(bc); as = flat.args; f = flat.f
    argsizes = broadcast_sizes(as...)
    ax = axes(bc)
    ax isa Tuple{Vararg{SOneTo}} || error("Dimension is not static. Please file a bug at `StaticArrays.jl`.")
    return _broadcast(f, Size(map(length, ax)), argsizes, as...)
end

# A functor generates the ith component of StructStaticBroadcast.
struct Similar_ith{SA, E<:Tuple}
    elements::E
    Similar_ith{SA}(elements::Tuple) where {SA} = new{SA, typeof(elements)}(elements)
end
function (s::Similar_ith{SA})(i::Int) where {SA}
    ith_elements = ntuple(Val(length(s.elements))) do j
        getfield(s.elements[j], i)
    end
    ith_SA = similar_type(SA, fieldtype(eltype(SA), i))
    return @inbounds ith_SA(ith_elements)
end

@inline function _broadcast(f, sz::Size{newsize}, s::Tuple{Vararg{Size}}, a...) where {newsize}
    first_staticarray = first_statictype(a...)
    elements, ET = if prod(newsize) == 0
        # Use inference to get eltype in empty case (following StaticBroadcast defined in StaticArrays.jl)
        eltys = Tuple{map(eltype, a)...}
        (), Core.Compiler.return_type(f, eltys)
    else
        temp = __broadcast(f, sz, s, a...)
        temp, eltype(temp)
    end
    if isnonemptystructtype(ET)
        SA = similar_type(first_staticarray, ET, sz)
        arrs = ntuple(Similar_ith{SA}(elements), Val(fieldcount(ET)))
        return StructArray{ET}(arrs)
    else
        @inbounds return similar_type(first_staticarray, ET, sz)(elements)
    end
end

# The `__broadcast` kernal is copied from `StaticArrays.jl`.
# see https://github.com/JuliaArrays/StaticArrays.jl/blob/master/src/broadcast.jl
@generated function __broadcast(f, ::Size{newsize}, s::Tuple{Vararg{Size}}, a...) where newsize
    sizes = [sz.parameters[1] for sz ∈ s.parameters]

    indices = CartesianIndices(newsize)
    exprs = similar(indices, Expr)
    for (j, current_ind) ∈ enumerate(indices)
        exprs_vals = (broadcast_getindex(sz, i, current_ind) for (i, sz) in enumerate(sizes))
        exprs[j] = :(f($(exprs_vals...)))
    end

    return quote
        Base.@_inline_meta
        return tuple($(exprs...))
    end
end

broadcast_getindex(::Tuple{}, i::Int, I::CartesianIndex) = return :(_broadcast_getindex(a[$i], $I))
function broadcast_getindex(oldsize::Tuple, i::Int, newindex::CartesianIndex)
    li = LinearIndices(oldsize)
    ind = _broadcast_getindex(li, newindex)
    return :(a[$i][$ind])
end

end
