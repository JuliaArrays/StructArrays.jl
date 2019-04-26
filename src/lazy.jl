struct LazyRow{T, N, C, I}
    columns::StructArray{T, N, C} # a `Columns` object
    index::I
end

for typ in [:Symbol, :Int]
    @eval begin
        Base.@propagate_inbounds function Base.getproperty(c::LazyRow, nm::$typ)
            return getproperty(getfield(c, 1), nm)[getfield(c, 2)]
        end
        Base.@propagate_inbounds function Base.setproperty!(c::LazyRow, nm::$typ, val)
            getproperty(getfield(c, 1), nm)[getfield(c, 2)] = val
            return nothing
        end
    end
end
Base.propertynames(c::LazyRow) = propertynames(getfield(c, 1))

function Base.show(io::IO, c::LazyRow)
    print(io, "LazyRow")
    show(io, to_tup(c))
end

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
fieldarrays(v::LazyRows) = fieldarrays(parent(v))

Base.size(v::LazyRows) = size(parent(v))
Base.getindex(v::LazyRows{<:Any, <:Any, <:Any, <:Integer}, i::Integer) = LazyRow(parent(v), i)
Base.getindex(v::LazyRows{<:Any, <:Any, <:Any, <:CartesianIndex}, i::Integer...) = LazyRow(parent(v), CartesianIndex(i))

Base.IndexStyle(::Type{<:LazyRows{<:Any, <:Any, <:Any, <:Integer}}) = IndexLinear()

function Base.showarg(io::IO, s::LazyRows{T}, toplevel) where T
    print(io, "LazyRows")
    showfields(io, Tuple(fieldarrays(s)))
    toplevel && print(io, " with eltype LazyRow{", T, "}")
end
