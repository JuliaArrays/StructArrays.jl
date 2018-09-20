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
StructArray{T}(c::C) where {T, C<:NamedTuple} =
    StructArray{createtype(T, eltypes(C)), length(size(c[1])), C}(c)
StructArray(c::C) where {C<:NamedTuple} = StructArray{C}(c)
StructArray(c::C) where {C<:Tuple} = StructArray{eltypes(C)}(c)

StructArray{T}(; kwargs...) where {T} = StructArray{T}(values(kwargs))
StructArray(; kwargs...) = StructArray(values(kwargs))

StructArray{T}(args...) where {T} = StructArray{T}(NamedTuple{fields(T)}(args))

_array(::Type{T}, sz; unwrap = t -> false) where {T} = unwrap(T) ? StructArray{T}(undef, sz; unwrap = unwrap) : Array{T}(undef, sz)
function _similar(v::S, ::Type{Z}; unwrap = t -> false) where {S <: AbstractArray{T, N}, Z} where {T, N}
    unwrap(Z) ? StructArray{Z}(map(t -> _similar(v, fieldtype(Z, t); unwrap = unwrap), fields(Z))) : similar(v, Z)
end


StructArray{T}(u::Base.UndefInitializer, d::Integer...; unwrap = t -> false) where {T} = StructArray{T}(u, convert(Dims, d); unwrap = unwrap)
@generated function StructArray{T}(::Base.UndefInitializer, sz::Dims; unwrap = t -> false) where {T}
    ex = Expr(:tuple, [:(_array($(fieldtype(T, i)), sz; unwrap = unwrap)) for i in 1:fieldcount(T)]...)
    return quote
        StructArray{T}(NamedTuple{fields(T)}($ex))
    end
end

@generated function StructArray(v::AbstractArray{T, N}; unwrap = t -> false) where {T, N}
    syms = [gensym() for i in 1:fieldcount(T)]
    init = Expr(:block, [:($(syms[i]) = _similar(v, $(fieldtype(T, i)); unwrap = unwrap)) for i in 1:fieldcount(T)]...)
    push = Expr(:block, [:($(syms[i])[j] = f.$(fieldname(T, i))) for i in 1:fieldcount(T)]...)
    quote
        $init
        for (j, f) in enumerate(v)
            @inbounds $push
        end
        return StructArray{T}($(syms...))
    end
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

fields(::Type{<:NamedTuple{K}}) where {K} = K
@generated function fields(t::Type{T}) where {T}
   return :($(Expr(:tuple, [QuoteNode(f) for f in fieldnames(T)]...)))
end
@generated function fields(t::Type{T}) where {T<:Tuple}
    return :($(Expr(:tuple, [QuoteNode(Symbol("x$f")) for f in fieldnames(T)]...)))
end


@generated function Base.push!(s::StructArray{T, 1}, vals) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        val = Expr(:., :vals, Expr(:quote, key))
        push!(args, :(push!($field, $val)))
    end
    push!(args, :s)
    Expr(:block, args...)
end

@generated function Base.append!(s::StructArray{T, 1}, vals) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        val = Expr(:., :vals, Expr(:quote, key))
        push!(args, :(append!($field, $val)))
    end
    push!(args, :s)
    Expr(:block, args...)
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
