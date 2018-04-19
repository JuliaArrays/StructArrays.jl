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

StructureArray{T}(c::C) where {T, C<:NamedTuple} =
    StructureArray{createtype(T, eltypes(C)), length(size(c[1])), C}(c)
StructureArray(c::C) where {C<:NamedTuple} = StructureArray{C}(c)

StructureArray{T}(args...) where {T} = StructureArray{T}(NamedTuple{fields(T)}(args))



columns(s::StructureArray) = getfield(s, :columns)
getproperty(s::StructureArray, key::Symbol) = getfield(columns(s), key)
getproperty(s::StructureArray, key::Int) = getfield(columns(s), key)

size(s::StructureArray) = size(columns(s)[1])

getindex(s::StructureArray, I...) = ith_all(s, I...)
