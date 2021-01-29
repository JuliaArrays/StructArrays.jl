"""
    StructArray{T,N,C,I} <: AbstractArray{T, N}

A type that stores an `N`-dimensional array of structures of type `T` as a structure of arrays.

- `getindex` and `setindex!` are overloaded to get/set values of type `T`.
- `getproperty` is overloaded to return individual field arrays.

# Fields

- `fieldarrays`: a `NamedTuple` or `Tuple` of the arrays used by each field. These can be accessed by [`fieldarrays(x)`](@ref).
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

# common type used for indexing
index_type(::Type{NamedTuple{names, types}}) where {names, types} = index_type(types)
index_type(::Type{Tuple{}}) = Int
function index_type(::Type{T}) where {T<:Tuple}
    S, U = tuple_type_head(T), tuple_type_tail(T)
    IndexStyle(S) isa IndexCartesian ? CartesianIndex{ndims(S)} : index_type(U)
end

index_type(::Type{StructArray{T, N, C, I}}) where {T, N, C, I} = I

array_types(::Type{StructArray{T, N, C, I}}) where {T, N, C, I} = array_types(C)
array_types(::Type{NamedTuple{names, types}}) where {names, types} = types
array_types(::Type{TT}) where {TT<:Tuple} = TT

"""
    StructArray{T}((fieldarrays...)::Union{Tuple, NamedTuple})
    StructArray{T}(name1=fieldarray1, name2=fieldarray2, ...)

Construct a `StructArray` of element type `T` from the specified field arrays.

    StructArray((fieldarrays...)::Union{Tuple, NamedTuple})
    StructArray(name1=fieldarray1, name2=fieldarray2, ...)

Construct a `StructArray` with a `Tuple` or `NamedTuple` element type from the
specified field arrays.

# Examples

```julia-repl
julia> StructArray{ComplexF64}(([1.0, 2.0], [3.0, 4.0]))
2-element StructArray(::Array{Float64,1}, ::Array{Float64,1}) with eltype Complex{Float64}:
 1.0 + 3.0im
 2.0 + 4.0im

julia> StructArray{ComplexF64}(re=[1.0, 2.0], im=[3.0, 4.0])
2-element StructArray(::Array{Float64,1}, ::Array{Float64,1}) with eltype Complex{Float64}:
 1.0 + 3.0im
 2.0 + 4.0im
```

Any `AbstractArray` can be used as a field array
```julia-repl
julia> StructArray{Complex{Int64}}(([1, 2], 3:4))
2-element StructArray(::Array{Int64,1}, ::UnitRange{Int64}) with eltype Complex{Int64}:
 1 + 3im
 2 + 4im
```

If no element type `T` is provided, a `Tuple` or `NamedTuple` is used:
```julia-repl
julia> StructArray((zeros(2,2), ones(2,2)))
2×2 StructArray(::Array{Float64,2}, ::Array{Float64,2}) with eltype Tuple{Float64,Float64}:
 (0.0, 1.0)  (0.0, 1.0)
 (0.0, 1.0)  (0.0, 1.0)

julia> StructArray(a=zeros(2,2), b=ones(2,2))
2×2 StructArray(::Array{Float64,2}, ::Array{Float64,2}) with eltype NamedTuple{(:a, :b),Tuple{Float64,Float64}}:
 (a = 0.0, b = 1.0)  (a = 0.0, b = 1.0)
 (a = 0.0, b = 1.0)  (a = 0.0, b = 1.0)
```
"""
StructArray(tup::Union{Tuple,NamedTuple})

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

function _undef_array(::Type{T}, sz; unwrap::F = alwaysfalse) where {T, F}
    if unwrap(T)
        return StructArray{T}(undef, sz; unwrap = unwrap)
    else
        return Array{T}(undef, sz)
    end
end

function _similar(v::AbstractArray, ::Type{Z}; unwrap::F = alwaysfalse) where {Z, F}
    if unwrap(Z)
        return buildfromschema(typ -> _similar(v, typ; unwrap = unwrap), Z)
    else
        return similar(v, Z)
    end
end

"""
    StructArray{T}(undef, dims; unwrap=T->false)

Construct an uninitialized `StructArray` with element type `T`, with `Array`
field arrays.

The `unwrap` keyword argument is a function that determines whether to
recursively convert arrays of element type `T` to `StructArray`s.

# Examples

```julia-repl
julia> StructArray{ComplexF64}(undef, (2,3))
2×3 StructArray(::Array{Float64,2}, ::Array{Float64,2}) with eltype Complex{Float64}:
  2.3166e-314+2.38405e-314im  2.39849e-314+2.38405e-314im  2.41529e-314+2.38405e-314im
 2.31596e-314+2.41529e-314im  2.31596e-314+2.41529e-314im  2.31596e-314+NaN*im
```
"""
StructArray(::Base.UndefInitializer, sz::Dims)

function StructArray{T}(::Base.UndefInitializer, sz::Dims; unwrap::F = alwaysfalse) where {T, F}
    buildfromschema(typ -> _undef_array(typ, sz; unwrap = unwrap), T)
end
StructArray{T}(u::Base.UndefInitializer, d::Integer...; unwrap::F = alwaysfalse) where {T, F} = StructArray{T}(u, convert(Dims, d); unwrap = unwrap)

function similar_structarray(v::AbstractArray, ::Type{Z}; unwrap::F = alwaysfalse) where {Z, F}
    buildfromschema(typ -> _similar(v, typ; unwrap = unwrap), Z)
end

"""
    StructArray(A; unwrap = T->false)

Construct a `StructArray` from an existing multidimensional array or iterator
`A`.

The `unwrap` keyword argument is a function that determines whether to
recursively convert arrays of element type `T` to `StructArray`s.

# Examples

## Basic usage

```julia-repl
julia> A = rand(ComplexF32, 2,2)
2×2 Array{Complex{Float32},2}:
 0.694399+0.94999im  0.422804+0.891131im
 0.101001+0.33644im  0.632468+0.811319im

julia> StructArray(A)
2×2 StructArray(::Array{Float32,2}, ::Array{Float32,2}) with eltype Complex{Float32}:
 0.694399+0.94999im  0.422804+0.891131im
 0.101001+0.33644im  0.632468+0.811319im
```

## From an iterator

```julia-repl
julia> StructArray((1, Complex(i, j)) for i = 1:3, j = 2:4)
3×3 StructArray(::Array{Int64,2}, ::Array{Complex{Int64},2}) with eltype Tuple{Int64,Complex{Int64}}:
 (1, 1+2im)  (1, 1+3im)  (1, 1+4im)
 (1, 2+2im)  (1, 2+3im)  (1, 2+4im)
 (1, 3+2im)  (1, 3+3im)  (1, 3+4im)
```

## Recursive unwrapping

```julia-repl
julia> StructArray((1, Complex(i, j)) for i = 1:3, j = 2:4; unwrap = T -> !(T<:Real))
3×3 StructArray(::Array{Int64,2}, StructArray(::Array{Int64,2}, ::Array{Int64,2})) with eltype Tuple{Int64,Complex{Int64}}:
 (1, 1+2im)  (1, 1+3im)  (1, 1+4im)
 (1, 2+2im)  (1, 2+3im)  (1, 2+4im)
 (1, 3+2im)  (1, 3+3im)  (1, 3+4im)
```
"""
function StructArray(v; unwrap::F = alwaysfalse)::StructArray where {F}
    collect_structarray(v; initializer = StructArrayInitializer(unwrap))
end

function StructArray(v::AbstractArray{T}; unwrap::F = alwaysfalse) where {T, F}
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
    fieldarrays(s::StructArray)

Return the field arrays corresponding to the various entry of the struct as a `NamedTuple`, or a `Tuple` if the struct has no names.

# Examples

```julia-repl
julia> s = StructArray(rand(ComplexF64, 4));

julia> fieldarrays(s)
(re = [0.396526, 0.486036, 0.459595, 0.0323561], im = [0.147702, 0.81043, 0.00993469, 0.487091])
```
"""
fieldarrays(s::StructArray) = getfield(s, :fieldarrays)

_getfield(s::StructArray, key) = getfield(fieldarrays(s), key)

Base.getproperty(s::StructArray, key::Symbol) = _getfield(s::StructArray, key)
Base.getproperty(s::StructArray, key::Int) = _getfield(s::StructArray, key)
Base.propertynames(s::StructArray) = propertynames(fieldarrays(s))


Base.size(s::StructArray) = size(fieldarrays(s)[1])
Base.size(s::StructArray{<:Any, <:Any, <:EmptyTup}) = (0,)
Base.axes(s::StructArray) = axes(fieldarrays(s)[1])
Base.axes(s::StructArray{<:Any, <:Any, <:EmptyTup}) = (1:0,)

"""
    StructArrays.get_ith(cols::Union{Tuple,NamedTuple}, I...)

Form a `Tuple` of the `I`th index of each element of `cols`, i.e. is equivalent
to
```julia
map(c -> c[I...], Tuple(cols))
```
"""
get_ith(cols::NamedTuple, I...) = get_ith(Tuple(cols), I...)
function get_ith(cols::Tuple, I...)
    @inbounds r = first(cols)[I...]
    return (r, get_ith(Base.tail(cols), I...)...)
end
get_ith(::Tuple{}, I...) = ()

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

# broadcast
import Base.Broadcast: BroadcastStyle, ArrayStyle, AbstractArrayStyle, Broadcasted, DefaultArrayStyle

struct StructArrayStyle{Style} <: AbstractArrayStyle{Any} end

@inline combine_style_types(::Type{A}, args...) where A<:AbstractArray =
    combine_style_types(BroadcastStyle(A), args...)
@inline combine_style_types(s::BroadcastStyle, ::Type{A}, args...) where A<:AbstractArray =
    combine_style_types(Broadcast.result_style(s, BroadcastStyle(A)), args...)
combine_style_types(s::BroadcastStyle) = s

Base.@pure cst(::Type{SA}) where SA = combine_style_types(array_types(SA).parameters...)

BroadcastStyle(::Type{SA}) where SA<:StructArray = StructArrayStyle{typeof(cst(SA))}()

Base.similar(bc::Broadcasted{StructArrayStyle{S}}, ::Type{ElType}) where {S<:DefaultArrayStyle,N,ElType} =
    isstructtype(ElType) ? similar(StructArray{ElType}, axes(bc)) : similar(Array{ElType}, axes(bc))
