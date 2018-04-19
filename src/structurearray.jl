"""
A type that stores an array of structures as a structure of arrays.
# Fields:
- `columns`: a tuple of arrays. Also `columns(x)`
"""
struct StructureArray{T, N, C<:Tup} <: AbstractArray{T, N}
    columns::C

    function StructureArray{T, N, C}(c) where {T, N, C<:Tup}
        length(c) > 0 || error("must have at least one column")
        n = size(c[1])
        length(n) == N || error("wrong number of dimensions")
        for i = 2:length(c)
            size(c[i]) == n || error("all columns must have same size")
        end
        new{T, N, C}(c)
    end
end

StructureArray{T}(c::C) where {T, C<:Tuple} = StructureArray{T}(NamedTuple{fields(T)}(c))
StructureArray{T}(c::C) where {T, C<:NamedTuple} =
    StructureArray{createtype(T, eltypes(C)), length(size(c[1])), C}(c)
StructureArray(c::C) where {C<:NamedTuple} = StructureArray{C}(c)

StructureArray{T}(args...) where {T} = StructureArray{T}(NamedTuple{fields(T)}(args))

columns(s::StructureArray) = getfield(s, :columns)
getproperty(s::StructureArray, key::Symbol) = getfield(columns(s), key)
getproperty(s::StructureArray, key::Int) = getfield(columns(s), key)

size(s::StructureArray) = size(columns(s)[1])

getindex(s::StructureArray, I::Int...) = get_ith(s, I...)
function getindex(s::StructureArray{T, N, C}, I::Union{Int, AbstractArray, Colon}...) where {T, N, C}
    StructureArray{T}(map(v -> getindex(v, I...), columns(s)))
end

function view(s::StructureArray{T, N, C}, I...) where {T, N, C}
    StructureArray{T}(map(v -> view(v, I...), columns(s)))
end

setindex!(s::StructureArray, val, I::Int...) = set_ith!(s, val, I...)

fields(T) = fieldnames(T)
fields(::Type{<:NamedTuple{K}}) where {K} = K
fields(::Type{<:StructureArray{T}}) where {T} = fields(T)

@generated function push!(s::StructureArray{T, 1}, vals) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        val = Expr(:., :vals, Expr(:quote, key))
        push!(args, :(push!($field, $val)))
    end
    push!(args, :s)
    Expr(:block, args...)
end

@generated function append!(s::StructureArray{T, 1}, vals) where {T}
    args = []
    for key in fields(T)
        field = Expr(:., :s, Expr(:quote, key))
        val = Expr(:., :vals, Expr(:quote, key))
        push!(args, :(append!($field, $val)))
    end
    push!(args, :s)
    Expr(:block, args...)
end

function cat(dims, args::StructureArray...)
    f = key -> cat(dims, (getproperty(t, key) for t in args)...)
    T = mapreduce(eltype, promote_type, args)
    StructureArray{T}(map(f, fields(eltype(args[1]))))
end

for op in [:hcat, :vcat]
    @eval begin
        function $op(args::StructureArray...)
            f = key -> $op((getproperty(t, key) for t in args)...)
            T = mapreduce(eltype, promote_type, args)
            StructureArray{T}(map(f, fields(eltype(args[1]))))
        end
    end
end
