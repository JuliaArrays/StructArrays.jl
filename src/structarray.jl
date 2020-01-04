"""
A type that stores an array of structures as a structure of arrays.
# Fields:
- `fieldarrays`: a (named) tuple of arrays. Also `fieldarrays(x)`
"""
struct StructArray{T, N, C<:Tup, I} <: AbstractArray{T, N}
    fieldarrays::C

    function StructArray{T, N, C}(c) where {T, N, C<:Tup}
        if length(c) > 0
            ax = axes(c[1])
            length(ax) == N || error("wrong number of dimensions")
            for i = 2:length(c)
                axes(c[i]) == ax || error("all field arrays must have same shape")
            end
        end
        new{T, N, C, index_type(C)}(c)
    end
end

index_type(::Type{NamedTuple{names, types}}) where {names, types} = index_type(types)
index_type(::Type{Tuple{}}) = Int
function index_type(::Type{T}) where {T<:Tuple}
    S, U = tuple_type_head(T), tuple_type_tail(T)
    IndexStyle(S) isa IndexCartesian ? CartesianIndex{ndims(S)} : index_type(U) 
end

index_type(::Type{StructArray{T, N, C, I}}) where {T, N, C, I} = I

function StructArray{T}(c::C) where {T, C<:Tup}
    cols = strip_params(staticschema(T))(c)
    N = isempty(cols) ? 1 : ndims(cols[1]) 
    StructArray{T, N, typeof(cols)}(cols)
end

StructArray(c::C) where {C<:NamedTuple} = StructArray{eltypes(C)}(c)
StructArray(c::Tuple; names = nothing) = _structarray(c, names)

StructArray{T}(; kwargs...) where {T} = StructArray{T}(values(kwargs))
StructArray(; kwargs...) = StructArray(values(kwargs))

_structarray(args::T, ::Nothing) where {T<:Tuple} = StructArray{eltypes(T)}(args)
_structarray(args::Tuple, names) = _structarray(args, Tuple(names))
_structarray(args::Tuple, ::Tuple) = _structarray(args, nothing)
_structarray(args::NTuple{N, Any}, names::NTuple{N, Symbol}) where {N} = StructArray(NamedTuple{names}(args))

const StructVector{T, C<:Tup, I} = StructArray{T, 1, C, I}
StructVector{T}(args...; kwargs...) where {T} = StructArray{T}(args...; kwargs...)
StructVector(args...; kwargs...) = StructArray(args...; kwargs...)

function Base.IndexStyle(::Type{S}) where {S<:StructArray}
    index_type(S) === Int ? IndexLinear() : IndexCartesian()
end

function _undef_array(::Type{T}, sz; unwrap = t -> false) where {T}
    if unwrap(T)
        return StructArray{T}(undef, sz; unwrap = unwrap)
    else
        return Array{T}(undef, sz)
    end
end

function _similar(v::AbstractArray, ::Type{Z}; unwrap = t -> false) where {Z}
    if unwrap(Z)
        return buildfromschema(typ -> _similar(v, typ; unwrap = unwrap), Z)
    else
        return similar(v, Z)
    end
end

function StructArray{T}(::Base.UndefInitializer, sz::Dims; unwrap = t -> false) where {T}
    buildfromschema(typ -> _undef_array(typ, sz; unwrap = unwrap), T)
end
StructArray{T}(u::Base.UndefInitializer, d::Integer...; unwrap = t -> false) where {T} = StructArray{T}(u, convert(Dims, d); unwrap = unwrap)

function similar_structarray(v::AbstractArray, ::Type{Z}; unwrap = t -> false) where {Z}
    buildfromschema(typ -> _similar(v, typ; unwrap = unwrap), Z)
end

function StructArray(v; unwrap = t -> false)::StructArray
    collect_structarray(v; initializer = StructArrayInitializer(unwrap))
end

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

function Base.similar(::Type{<:StructArray{T, <:Any, C}}, sz::Dims) where {T, C}
    buildfromschema(typ -> similar(typ, sz), T, C)
end

Base.similar(s::StructArray, sz::Base.DimOrInd...) = similar(s, Base.to_shape(sz))
Base.similar(s::StructArray) = similar(s, Base.to_shape(axes(s)))
function Base.similar(s::StructArray{T}, sz::Tuple) where {T}
    StructArray{T}(map(typ -> similar(typ, sz), fieldarrays(s)))
end

"""
`fieldarrays(s::StructArray)`

Return the field arrays corresponding to the various entry of the struct as a named tuple.
If the struct has no names (e.g. a tuple), return the arrays as a tuple.

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
Base.propertynames(s::StructArray) = propertynames(fieldarrays(s))
staticschema(::Type{<:StructArray{T}}) where {T} = staticschema(T)

Base.size(s::StructArray) = size(fieldarrays(s)[1])
Base.size(s::StructArray{<:Any, <:Any, <:EmptyTup}) = (0,)
Base.axes(s::StructArray) = axes(fieldarrays(s)[1])
Base.axes(s::StructArray{<:Any, <:Any, <:EmptyTup}) = (1:0,)

get_ith(cols::NamedTuple, I...) = get_ith(Tuple(cols), I...)
@generated function get_ith(cols::NTuple{N, Any}, I...) where N
    args = [:(getfield(cols, $i)[I...]) for i in 1:N]
    tup = Expr(:tuple, args...)
    return :(@inbounds $tup)
end

Base.@propagate_inbounds function Base.getindex(x::StructArray{T, <:Any, <:Any, CartesianIndex{N}}, I::Vararg{Int, N}) where {T, N}
    cols = fieldarrays(x)
    @boundscheck checkbounds(x, I...)
    return createinstance(T, get_ith(cols, I...)...)
end

Base.@propagate_inbounds function Base.getindex(x::StructArray{T, <:Any, <:Any, Int}, I::Int) where {T}
    cols = fieldarrays(x)
    @boundscheck checkbounds(x, I)
    return createinstance(T, get_ith(cols, I)...)
end

function Base.view(s::StructArray{T, N, C}, I...) where {T, N, C}
    StructArray{T}(map(v -> view(v, I...), fieldarrays(s)))
end

Base.@propagate_inbounds function Base.setindex!(s::StructArray{<:Any, <:Any, <:Any, CartesianIndex{N}}, vals, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(s, I...)
    foreachfield((col, val) -> (@inbounds col[I...] = val), s, vals)
    s
end

Base.@propagate_inbounds function Base.setindex!(s::StructArray{<:Any, <:Any, <:Any, Int}, vals, I::Int)
    @boundscheck checkbounds(s, I)
    foreachfield((col, val) -> (@inbounds col[I] = val), s, vals)
    s
end

function Base.push!(s::StructVector, vals)
    foreachfield(push!, s, vals)
    return s
end

function Base.append!(s::StructVector, vals::StructVector)
    foreachfield(append!, s, vals)
    return s
end

Base.copyto!(I::StructArray, J::StructArray) = (foreachfield(copyto!, I, J); I)

function Base.copyto!(I::StructArray, doffs::Integer, J::StructArray, soffs::Integer, n::Integer)
    foreachfield((dest, src) -> copyto!(dest, doffs, src, soffs, n), I, J)
    return I
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

for op in [:cat, :hcat, :vcat]
    @eval begin
        function Base.$op(args::StructArray...; kwargs...)
            f = key -> $op((getproperty(t, key) for t in args)...; kwargs...)
            T = mapreduce(eltype, promote_type, args)
            StructArray{T}(map(f, propertynames(args[1])))
        end
    end
end

Base.copy(s::StructArray{T,N,C}) where {T,N,C} = StructArray{T,N,C}(C(copy(x) for x in fieldarrays(s)))

function Base.reshape(s::StructArray{T}, d::Dims) where {T}
    StructArray{T}(map(x -> reshape(x, d), fieldarrays(s)))
end

function showfields(io::IO, fields::NTuple{N, Any}) where N
    print(io, "(")
    for (i, field) in enumerate(fields)
        Base.showarg(io, fields[i], false)
        i < N && print(io, ", ")
    end
    print(io, ")")
end

function Base.showarg(io::IO, s::StructArray{T}, toplevel) where T
    print(io, "StructArray")
    showfields(io, Tuple(fieldarrays(s)))
    toplevel && print(io, " with eltype ", T)
end
