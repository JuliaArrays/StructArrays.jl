struct LazyRow{T, N, C, I}
    columns::StructArray{T, N, C, I} # a `Columns` object
    index::I
end

for typ in [:Symbol, :Int]
    @eval begin
        Base.@propagate_inbounds function Base.getproperty(c::LazyRow, nm::$typ)
            return getproperty(getfield(c, 1), nm)[getfield(c, 2)]
        end
        Base.@propagate_inbounds function Base.setproperty!(c::LazyRow, nm::$typ, val)
            getproperty(getfield(c, 1), nm)[getfield(c, 2)] = val
            return
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

iscompatible(::Type{<:LazyRow{R}}, ::Type{S}) where {R, S<:StructArray} = iscompatible(R, S)

(s::ArrayInitializer)(::Type{<:LazyRow{T}}, d) where {T} = buildfromschema(typ -> s(typ, d), T)

struct LazyRows{T, N, C, I} <: AbstractArray{LazyRow{T, N, C, I}, N}
    columns::StructArray{T, N, C, I}
end
Base.parent(v::LazyRows) = getfield(v, 1)
fieldarrays(v::LazyRows) = fieldarrays(parent(v))

Base.getproperty(s::LazyRows, key::Symbol) = getproperty(parent(s), key)
Base.getproperty(s::LazyRows, key::Int) = getproperty(parent(s), key)
Base.propertynames(c::LazyRows) = propertynames(parent(c))

staticschema(::Type{LazyRows{T, N, C, I}}) where {T, N, C, I} = staticschema(StructArray{T, N, C, I})

Base.size(v::LazyRows) = size(parent(v))
Base.getindex(v::LazyRows{<:Any, <:Any, <:Any, Int}, i::Int) = LazyRow(parent(v), i)
Base.getindex(v::LazyRows{<:Any, <:Any, <:Any, CartesianIndex{N}}, i::Vararg{Int, N}) where {N} = LazyRow(parent(v), CartesianIndex(i))

best_index(::Type{LazyRows{T, N, C, I}}) where {T, N, C, I} = I
Base.IndexStyle(::Type{L}) where {L<:LazyRows} = _indexstyle(best_index(L))

function Base.showarg(io::IO, s::LazyRows{T}, toplevel) where T
    print(io, "LazyRows")
    showfields(io, Tuple(fieldarrays(s)))
    toplevel && print(io, " with eltype LazyRow{", T, "}")
end
