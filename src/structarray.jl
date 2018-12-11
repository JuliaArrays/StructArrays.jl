"""
A type that stores an array of structures as a structure of arrays.
# Fields:
- `columns`: a named tuple of arrays. Also `columns(x)`
"""
struct StructArray{T, N, C<:NamedTuple} <: AbstractArray{T, N}
    columns::C

    function StructArray{T, N, C}(c) where {T, N, C<:NamedTuple}
        length(c) > 0 || error("must have at least one column")
        n = size(c[1])
        length(n) == N || error("wrong number of dimensions")
        for i = 2:length(c)
            size(c[i]) == n || error("all columns must have same size")
        end
        new{T, N, C}(c)
    end
end

StructArray{T}(c::C) where {T, C<:Tuple} = StructArray{T}(NamedTuple{fields(T)}(c))
StructArray{T}(c::C) where {T, C<:NamedTuple} = StructArray{T, length(size(c[1])), C}(c)
StructArray(c::C) where {C<:NamedTuple} = StructArray{eltypes(C)}(c)
StructArray(c::C) where {C<:Tuple} = StructArray{eltypes(C)}(c)

StructArray{T}(; kwargs...) where {T} = StructArray{T}(values(kwargs))
StructArray(; kwargs...) = StructArray(values(kwargs))

StructArray{T}(args...) where {T} = StructArray{T}(NamedTuple{fields(T)}(args))

_undef_array(::Type{T}, sz; unwrap = t -> false) where {T} = unwrap(T) ? StructArray{T}(undef, sz; unwrap = unwrap) : Array{T}(undef, sz)
function StructArray{T}(::Base.UndefInitializer, sz::Dims; unwrap = t -> false) where {T}
    buildfromschema(T, _undef_array, sz; unwrap = unwrap)
end
StructArray{T}(u::Base.UndefInitializer, d::Integer...; unwrap = t -> false) where {T} = StructArray{T}(u, convert(Dims, d); unwrap = unwrap)

_similar(::Type{Z}, v::AbstractArray; unwrap = t -> false) where {Z} =
    unwrap(Z) ? _similar(Z, staticschema(Z), v; unwrap = unwrap) : similar(v, Z)

function _similar(::Type{Z}, ::Type{NT}, v::AbstractArray; unwrap = t -> false) where {Z, NT<:NamedTuple}
    nt = map_params(typ -> _similar(typ, v; unwrap = unwrap), NT)
    StructArray{Z}(nt)
end

function similar_structarray(v::AbstractArray{T}; unwrap = t -> false) where {T}
    buildfromschema(T, _similar, v; unwrap = unwrap)
end

function StructArray(v::AbstractArray{T}; unwrap = t -> false) where {T}
    s = similar_structarray(v; unwrap = unwrap)
    for i in eachindex(v)
        @inbounds s[i] = v[i]
    end
    s
end
StructArray(s::StructArray) = copy(s)

Base.convert(::Type{StructArray}, v::AbstractArray) = StructArray(v)

columns(s::StructArray) = getfield(s, :columns)
Base.getproperty(s::StructArray, key::Symbol) = getfield(columns(s), key)
Base.getproperty(s::StructArray, key::Int) = getfield(columns(s), key)
Base.propertynames(s::StructArray) = fieldnames(typeof(columns(s)))

Base.size(s::StructArray) = size(columns(s)[1])

@generated function Base.getindex(x::StructArray{T, N, NamedTuple{names, types}}, I::Int...) where {T, N, names, types}
    args = [:(getfield(cols, $i)[I...]) for i in 1:length(names)]
    return quote
        cols = columns(x)
        @boundscheck checkbounds(x, I...)
        @inbounds $(Expr(:call, :createinstance, :T, args...))
    end
end

function Base.getindex(s::StructArray{T, N, C}, I::Union{Int, AbstractArray, Colon}...) where {T, N, C}
    StructArray{T}(map(v -> getindex(v, I...), columns(s)))
end

function Base.view(s::StructArray{T, N, C}, I...) where {T, N, C}
    StructArray{T}(map(v -> view(v, I...), columns(s)))
end

function Base.setindex!(s::StructArray, vals, I::Int...)
    @boundscheck checkbounds(s, I...)
    @inbounds foreachcolumn((col, val) -> (col[I...] = val), s, vals)
    s
end

@inline getfieldindex(v::Tuple, field::Symbol, index::Integer) = getfield(v, index)
@inline getfieldindex(v, field::Symbol, index::Integer) = getproperty(v, field)

function Base.push!(s::StructArray, vals)
    foreachcolumn(push!, s, vals)
end

function Base.append!(s::StructArray, vals)
    foreachcolumn(append!, s, vals)
end

function Base.cat(args::StructArray...; dims)
    f = key -> cat((getproperty(t, key) for t in args)...; dims=dims)
    T = mapreduce(eltype, promote_type, args)
    StructArray{T}(map(f, fields(eltype(args[1]))))
end

function Base.resize!(s::StructArray, i::Integer)
    for a in columns(s)
        resize!(a, i)
    end
    return s
end

for op in [:hcat, :vcat]
    @eval begin
        function Base.$op(args::StructArray...)
            f = key -> $op((getproperty(t, key) for t in args)...)
            T = mapreduce(eltype, promote_type, args)
            StructArray{T}(map(f, fields(eltype(args[1]))))
        end
    end
end

Base.copy(s::StructArray{T,N,C}) where {T,N,C} = StructArray{T,N,C}(C(copy(x) for x in columns(s)))

function Base.reshape(s::StructArray{T}, d::Dims) where {T}
    StructArray{T}(map(x -> reshape(x, d), columns(s)))
end
