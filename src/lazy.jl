struct LazyRow{T, N, C, I}
    columns::StructArray{T, N, C} # a `Columns` object
    index::I
end

Base.getproperty(c::LazyRow, nm::Symbol) = getproperty(getfield(c, 1), nm)[getfield(c, 2)]
Base.setproperty!(c::LazyRow, nm::Symbol, val) = (getproperty(getfield(c, 1), nm)[getfield(c, 2)] = val; nothing)
Base.propertynames(c::LazyRow) = propertynames(getfield(c, 1))

staticschema(::Type{<:LazyRow{T}}) where {T} = staticschema(T)
buildfromschema(f, ::Type{<:LazyRow{T}}) where {T} = buildfromschema(f, T)

iscompatible(::Type{<:LazyRow{S}}, ::Type{StructArray{T, N, C}}) where {S, T, N, C} =
    iscompatible(S, StructArray{T, N, C})

(s::ArrayInitializer)(::Type{<:LazyRow{T}}, d) where {T} = buildfromschema(typ -> s(typ, d), T)

struct LazyRows{T, N, C, I} <: AbstractArray{LazyRow{T, N, C, I}, N}
    columns::StructArray{T, N, C}
end
LazyRows(s::S) where {S<:StructArray} = LazyRows(IndexStyle(S), s)
LazyRows(::IndexLinear, s::StructArray{T, N, C}) where {T, N, C} = LazyRows{T, N, C, Int}(s)
LazyRows(::IndexCartesian, s::StructArray{T, N, C}) where {T, N, C} = LazyRows{T, N, C, CartesianIndex{N}}(s)
Base.parent(v::LazyRows) = getfield(v, 1)

Base.size(v::LazyRows) = size(parent(v))
Base.getindex(v::LazyRows{<:Any, <:Any, <:Any, <:Integer}, i::Integer) = LazyRow(parent(v), i)
Base.getindex(v::LazyRows{<:Any, <:Any, <:Any, <:CartesianIndex}, i::Integer...) = LazyRow(parent(v), CartesianIndex(i))

Base.IndexStyle(::Type{<:LazyRows{<:Any, <:Any, <:Any, <:Integer}}) = IndexLinear()
