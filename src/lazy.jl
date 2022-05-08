"""
    LazyRow(s::StructArray, i)

A lazy representation of `s[i]`. `LazyRow(s, i)` does not materialize the `i`th
row but returns a lazy wrapper around it on which `getproperty` does the correct
thing. This is useful when the row has many fields only some of which are
necessary. It also allows changing columns in place.

See [`LazyRows`](@ref) to get an iterator of `LazyRow`s.

# Examples

```julia-repl
julia> t = StructArray((a = [1, 2], b = ["x", "y"]));

julia> LazyRow(t, 2).a
2

julia> LazyRow(t, 2).a = 123
123

julia> t
2-element StructArray(::Array{Int64,1}, ::Array{String,1}) with eltype NamedTuple{(:a, :b),Tuple{Int64,String}}:
 (a = 1, b = "x")
 (a = 123, b = "y")
```
"""
struct LazyRow{T, N, C, I}
    columns::StructArray{T, N, C, I} # a `Columns` object
    index::I
end

for typ in [:Symbol, :Int]
    @eval begin
        @inline Base.@propagate_inbounds function Base.getproperty(c::LazyRow, nm::$typ)
            return getproperty(getfield(c, 1), nm)[getfield(c, 2)]
        end
        @inline Base.@propagate_inbounds function Base.setproperty!(c::LazyRow, nm::$typ, val)
            getproperty(getfield(c, 1), nm)[getfield(c, 2)] = val
        end
    end
end
Base.propertynames(c::LazyRow) = propertynames(getfield(c, 1))

function Base.show(io::IO, c::LazyRow)
    print(io, "LazyRow")
    columns, index = getfield(c, 1), getfield(c, 2)
    tup = StructArray(components(columns))[index]
    show(io, tup)
end

@inline Base.@propagate_inbounds component(l::LazyRow, key) = getproperty(l, key)

staticschema(::Type{<:LazyRow{T}}) where {T} = staticschema(T)
buildfromschema(f, ::Type{<:LazyRow{T}}) where {T} = buildfromschema(f, T)
iscompatible(::Type{<:LazyRow{R}}, ::Type{S}) where {R, S<:StructArray} = iscompatible(R, S)

(s::ArrayInitializer)(::Type{<:LazyRow{T}}, d) where {T} = buildfromschema(typ -> s(typ, d), T)

maybe_convert_elt(::Type{T}, vals::LazyRow) where T = vals

"""
    LazyRows(s::StructArray)

An iterator of [`LazyRow`](@ref)s of `s`.

# Examples

```julia-repl
julia> map(t -> t.b ^ t.a, LazyRows(t))
2-element Array{String,1}:
 "x"
 "yy"
```
"""
struct LazyRows{T, N, C, I} <: AbstractArray{LazyRow{T, N, C, I}, N}
    columns::StructArray{T, N, C, I}
end
Base.parent(v::LazyRows) = getfield(v, 1)
components(v::LazyRows) = components(parent(v))

component(v::LazyRows, key) = component(parent(v), key)

staticschema(::Type{LazyRows{T, N, C, I}}) where {T, N, C, I} = staticschema(C)
createinstance(::Type{<:LazyRows{T}}, args...) where {T} = LazyRows(StructArray{T}(args))

Base.getproperty(v::LazyRows, key::Symbol) = component(v, key)
Base.getproperty(v::LazyRows, key::Int) = component(v, key)
Base.propertynames(v::LazyRows) = propertynames(parent(v))

Base.size(v::LazyRows) = size(parent(v))
Base.getindex(v::LazyRows{<:Any, <:Any, <:Any, Int}, i::Int) = LazyRow(parent(v), i)
Base.getindex(v::LazyRows{<:Any, <:Any, <:Any, CartesianIndex{N}}, i::Vararg{Int, N}) where {N} = LazyRow(parent(v), CartesianIndex(i))

index_type(::Type{LazyRows{T, N, C, I}}) where {T, N, C, I} = I
function Base.IndexStyle(::Type{L}) where {L<:LazyRows}
    index_type(L) === Int ? IndexLinear() : IndexCartesian()
end

function Base.showarg(io::IO, s::LazyRows{T}, toplevel) where T
    print(io, "LazyRows")
    showfields(io, Tuple(components(s)))
    toplevel && print(io, " with eltype LazyRow{", T, "}")
end
