"""
A type that stores an array of structures as a structure of arrays.
# Fields:
- `fieldarrays`: a named tuple of arrays. Also `fieldarrays(x)`
"""
struct StructArray{T, N, C<:NamedTuple} <: AbstractArray{T, N}
    fieldarrays::C

    function StructArray{T, N, C}(c) where {T, N, C<:NamedTuple}
        if length(c) > 0
            ax = axes(c[1])
            length(ax) == N || error("wrong number of dimensions")
            for i = 2:length(c)
                axes(c[i]) == ax || error("all field arrays must have same shape")
            end
        end
        new{T, N, C}(c)
    end
end

_dims(c::NamedTuple) = length(axes(c[1]))
_dims(c::NamedTuple{(), Tuple{}}) = 1

StructArray{T}(c::C) where {T, C<:Tuple} = StructArray{T}(NamedTuple{fields(T)}(c))
StructArray{T}(c::C) where {T, C<:NamedTuple} = StructArray{T, _dims(c), C}(c)
StructArray{T}(c::C) where {T, C<:Pair} = StructArray{T}(Tuple(c))
StructArray(c::C) where {C<:NamedTuple} = StructArray{eltypes(C)}(c)
StructArray(c::Tuple; names = nothing) = _structarray(c, names)
StructArray(c::Pair{P, Q}) where {P, Q} = StructArray{Pair{eltype(P), eltype(Q)}}(c)

StructArray{T}(; kwargs...) where {T} = StructArray{T}(values(kwargs))
StructArray(; kwargs...) = StructArray(values(kwargs))

@deprecate(StructArray{T}(args...) where {T}, StructArray{T}(args))

_structarray(args::T, ::Nothing) where {T<:Tuple} = StructArray{eltypes(T)}(args)
_structarray(args::Tuple, names) = _structarray(args, Tuple(names))
_structarray(args::Tuple, ::Tuple) = _structarray(args, nothing)
_structarray(args::NTuple{N, Any}, names::NTuple{N, Symbol}) where {N} = StructArray(NamedTuple{names}(args))

const StructVector{T, C<:NamedTuple} = StructArray{T, 1, C}
StructVector{T}(args...; kwargs...) where {T} = StructArray{T}(args...; kwargs...)
StructVector(args...; kwargs...) = StructArray(args...; kwargs...)

Base.IndexStyle(::Type{StructArray{T, N, C}}) where {T, N, C} = Base.IndexStyle(tuple_type(C).parameters[1])

_undef_array(::Type{T}, sz; unwrap = t -> false) where {T} = unwrap(T) ? StructArray{T}(undef, sz; unwrap = unwrap) : Array{T}(undef, sz)

_similar(v::AbstractArray, ::Type{Z}; unwrap = t -> false) where {Z} =
    unwrap(Z) ? buildfromschema(typ -> _similar(v, typ; unwrap = unwrap), Z) : similar(v, Z)

function StructArray{T}(::Base.UndefInitializer, sz::Dims; unwrap = t -> false) where {T}
    buildfromschema(typ -> _undef_array(typ, sz; unwrap = unwrap), T)
end
StructArray{T}(u::Base.UndefInitializer, d::Integer...; unwrap = t -> false) where {T} = StructArray{T}(u, convert(Dims, d); unwrap = unwrap)

function similar_structarray(v::AbstractArray, ::Type{Z}; unwrap = t -> false) where {Z}
    buildfromschema(typ -> _similar(v, typ; unwrap = unwrap), Z)
end

StructArray(v; unwrap = t -> false) = collect_structarray(v; initializer = StructArrayInitializer(unwrap))
function StructArray(v::AbstractArray{T}; unwrap = t -> false) where {T}
    s = similar_structarray(v, T; unwrap = unwrap)
    for i in eachindex(v)
        @inbounds s[i] = v[i]
    end
    s
end
StructArray(s::StructArray) = copy(s)

Base.convert(::Type{StructArray}, v::AbstractArray) = StructArray(v)
Base.convert(::Type{StructArray}, v::StructArray) = v

Base.convert(::Type{StructVector}, v::AbstractVector) = StructVector(v)
Base.convert(::Type{StructVector}, v::StructVector) = v

function Base.similar(::Type{StructArray{T, N, C}}, sz::Dims) where {T, N, C}
    cols = map_params(typ -> similar(typ, sz), C)
    StructArray{T}(cols)
end

Base.similar(s::StructArray, sz::Base.DimOrInd...) = similar(s, Base.to_shape(sz))
Base.similar(s::StructArray) = similar(s, Base.to_shape(axes(s)))
function Base.similar(s::StructArray{T}, sz::Tuple) where {T}
    StructArray{T}(map(typ -> similar(typ, sz), fieldarrays(s)))
end

"""
`fieldarrays(s::StructArray)`

Return the field arrays corresponding to the various entry of the struct as a named tuple.
If the struct has no names (e.g. a tuple) automatic names are assigned (`:x1, :x2, ...`).

## Examples

```julia
julia> s = StructArray(rand(ComplexF64, 4));

julia> fieldarrays(s)
(re = [0.396526, 0.486036, 0.459595, 0.0323561], im = [0.147702, 0.81043, 0.00993469, 0.487091])
```
"""
fieldarrays(s::StructArray) = getfield(s, :fieldarrays)

Base.getproperty(s::StructArray, key::Symbol) = getfield(fieldarrays(s), key)
Base.getproperty(s::StructArray, key::Int) = getfield(fieldarrays(s), key)
Base.propertynames(s::StructArray) = fieldnames(typeof(fieldarrays(s)))
staticschema(::Type{<:StructArray{T}}) where {T} = staticschema(T)

Base.size(s::StructArray) = size(fieldarrays(s)[1])
Base.size(s::StructArray{<:Any, <:Any, <:NamedTuple{(), Tuple{}}}) = (0,)
Base.axes(s::StructArray) = axes(fieldarrays(s)[1])
Base.axes(s::StructArray{<:Any, <:Any, <:NamedTuple{(), Tuple{}}}) = (1:0,)

@generated function Base.getindex(x::StructArray{T, N, NamedTuple{names, types}}, I::Int...) where {T, N, names, types}
    args = [:(getfield(cols, $i)[I...]) for i in 1:length(names)]
    return quote
        cols = fieldarrays(x)
        @boundscheck checkbounds(x, I...)
        @inbounds $(Expr(:call, :createinstance, :T, args...))
    end
end

function Base.getindex(s::StructArray{T, N, C}, I::Union{Int, AbstractArray, Colon}...) where {T, N, C}
    StructArray{T}(map(v -> getindex(v, I...), fieldarrays(s)))
end

function Base.view(s::StructArray{T, N, C}, I...) where {T, N, C}
    StructArray{T}(map(v -> view(v, I...), fieldarrays(s)))
end

function Base.setindex!(s::StructArray, vals, I::Int...)
    @boundscheck checkbounds(s, I...)
    @inbounds foreachfield((col, val) -> (col[I...] = val), s, vals)
    s
end

@inline getfieldindex(v::Tuple, field::Symbol, index::Integer) = getfield(v, index)
@inline getfieldindex(v, field::Symbol, index::Integer) = getproperty(v, field)

function Base.push!(s::StructArray, vals)
    foreachfield(push!, s, vals)
    return s
end

function Base.append!(s::StructArray, vals)
    foreachfield(append!, s, vals)
    return s
end

Base.copyto!(I::StructArray, J::StructArray) = (foreachfield(copyto!, I, J); I)

function Base.cat(args::StructArray...; dims)
    f = key -> cat((getproperty(t, key) for t in args)...; dims=dims)
    T = mapreduce(eltype, promote_type, args)
    StructArray{T}(map(f, fields(eltype(args[1]))))
end

function Base.resize!(s::StructArray, i::Integer)
    for a in fieldarrays(s)
        resize!(a, i)
    end
    return s
end

function Base.empty!(s::StructArray)
    foreachfield(empty!, s)
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

Base.copy(s::StructArray{T,N,C}) where {T,N,C} = StructArray{T,N,C}(C(copy(x) for x in fieldarrays(s)))

function Base.reshape(s::StructArray{T}, d::Dims) where {T}
    StructArray{T}(map(x -> reshape(x, d), fieldarrays(s)))
end
