refs(v::PooledArray) = v.refs
refs(v::AbstractArray) = v
refs(v::StructArray) = StructArray(map(refs, fieldarrays(v)))

# simple wrapper to signal that we are using refs
struct RefsArray{T, N, C} <: AbstractArray{T, N}
    columns::StructArray{T, N, C}
end
Base.parent(r::RefsArray) = getfield(r, 1)
Base.size(v::RefsArray) = size(parent(v))
@inline Base.@propagate_inbounds function Base.getindex(v::RefsArray, i...)
    @boundscheck checkbounds(v, i...)
    @inbounds ret = parent(v)[i...]
    return ret
end
@inline Base.@propagate_inbounds function Base.setindex!(v::RefsArray, val, i...)
    @boundscheck checkbounds(v, i...)
    @inbounds parent(v)[i...] = val
    return val
end
Base.IndexStyle(::Type{RefsArray{T, N, C}}) where {T, N, C} = IndexStyle(StructArray{T, N, C})
refsarray(v::StructArray) = RefsArray(refs(v))
