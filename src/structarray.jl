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

StructArray{T}(u::Base.UndefInitializer, d::Integer...; unwrap = t -> false) where {T} = StructArray{T}(u, convert(Dims, d); unwrap = unwrap)
function StructArray{T}(::Base.UndefInitializer, sz::Tuple{Vararg{Int, N}}; unwrap = t -> false) where {T, N}
    NT = staticschema(T)
    names = getnames(NT)
    types = gettypes(NT).parameters
    C = arraytypes(NT, sz; unwrap = unwrap)
    cols = map(typ -> _undef_array(typ, sz; unwrap = unwrap), NamedTuple{names}(types))
    return StructArray{T, N, C}(cols)
end

similar_from_tuple(::Type{Tuple{}}, sz::AbstractArray, simvec::Tuple = (); unwrap = t -> false) = ()

function similar_from_tuple(::Type{T}, v::AbstractArray{<:Any, N}; unwrap = t -> false) where {N, T<:Tuple}
    T1 = tuple_type_head(T)
    if unwrap(T1)
        NT1 = staticschema(T1)
        nt = similar_from_tuple(NT1, v; unwrap = unwrap)
        firstvec = StructArray{T1}(nt)
    else
        firstvec = similar(v, T1)
    end
    lastvecs = similar_from_tuple(tuple_type_tail(T), v; unwrap = unwrap)
    (firstvec, lastvecs...)
end

function similar_from_tuple(::Type{NamedTuple{K, V}}, v::AbstractArray; unwrap = t-> false) where {K, V}
    vecs = similar_from_tuple(V, v; unwrap = unwrap)
    NamedTuple{K}(vecs)
end

function similar_structarray(v::AbstractArray{T}; unwrap = t -> false) where {T}
    NT = staticschema(T)
    vecs = similar_from_tuple(NT, v; unwrap = unwrap)
    StructArray{T}(vecs)
end

function StructArray(v::AbstractArray; unwrap = t -> false)
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

Base.@propagate_inbounds Base.getindex(s::StructArray, I::Int...) = get_ith(s, I...)
function Base.getindex(s::StructArray{T, N, C}, I::Union{Int, AbstractArray, Colon}...) where {T, N, C}
    StructArray{T}(map(v -> getindex(v, I...), columns(s)))
end

function Base.view(s::StructArray{T, N, C}, I...) where {T, N, C}
    StructArray{T}(map(v -> view(v, I...), columns(s)))
end

Base.@propagate_inbounds Base.setindex!(s::StructArray, val, I::Int...) = set_ith!(s, val, I...)

@inline getfieldindex(v::Tuple, field::Symbol, index::Integer) = getfield(v, index)
@inline getfieldindex(v, field::Symbol, index::Integer) = getproperty(v, field)

@generated function Base.push!(s::StructArray{T, 1}, vals) where {T}
    exprs = foreach_expr((args...) -> Expr(:call, :push!, args...), T, :s, :vals)
    push!(exprs, :s)
    Expr(:block, exprs...)
end

@generated function Base.append!(s::StructArray{T, 1}, vals) where {T}
    exprs = foreach_expr((args...) -> Expr(:call, :append!, args...), T, :s, :vals)
    push!(exprs, :s)
    Expr(:block, exprs...)
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
