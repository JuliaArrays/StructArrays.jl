"""
    StructArray{T,N,C,I} <: AbstractArray{T, N}

A type that stores an `N`-dimensional array of structures of type `T` as a structure of arrays.

- `getindex` and `setindex!` are overloaded to get/set values of type `T`.
- `getproperty` is overloaded to return individual field arrays.

# Fields

- `components`: a `NamedTuple` or `Tuple` of the arrays used by each field. These can be accessed by [`components(x)`](@ref).
"""
struct StructArray{T, N, C<:Tup, I} <: AbstractArray{T, N}
    components::C

    function StructArray{T, N, C}(c) where {T, N, C<:Tup}
        isempty(c) && throw(ArgumentError("only eltypes with fields are supported"))
        ax = findconsistentvalue(axes, c)
        (ax === nothing) && throw(ArgumentError("all component arrays must have the same shape"))
        length(ax) == N || throw(ArgumentError("wrong number of dimensions"))
        new{T, N, C, index_type(c)}(c)
    end
end

# compute optimal type to use for indexing as a function of components
index_type(components::NamedTuple) = index_type(values(components))
index_type(::Tuple{}) = Int
function index_type(components::Tuple)
    f, ls = first(components), tail(components)
    return IndexStyle(f) isa IndexCartesian ? CartesianIndex{ndims(f)} : index_type(ls)
end
# Only check first component if the all the component types match
index_type(components::NTuple) = invoke(index_type, Tuple{Tuple}, (first(components),))
# Return the index type parameter as a function of the StructArray type or instance
index_type(s::StructArray) = index_type(typeof(s))
index_type(::Type{StructArray{T, N, C, I}}) where {T, N, C, I} = I

array_types(::Type{StructArray{T, N, C, I}}) where {T, N, C, I} = array_types(C)
array_types(::Type{NamedTuple{names, types}}) where {names, types} = types
array_types(::Type{TT}) where {TT<:Tuple} = TT

"""
    StructArray{T}((components...)::Union{Tuple, NamedTuple})
    StructArray{T}(name1=component1, name2=component2, ...)

Construct a `StructArray` of element type `T` from the specified field arrays.

    StructArray((components...)::Union{Tuple, NamedTuple})
    StructArray(name1=component1, name2=component2, ...)

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

StructArray(c::NamedTuple) = StructArray{eltypes(c)}(c)
StructArray(c::Tuple; names = nothing) = _structarray(c, names)

StructArray{T}(; kwargs...) where {T} = StructArray{T}(values(kwargs))
StructArray(; kwargs...) = StructArray(values(kwargs))

_structarray(args::Tuple, ::Nothing) = StructArray{eltypes(args)}(args)
_structarray(args::Tuple, names) = _structarray(args, Tuple(names))
_structarray(args::Tuple, ::Tuple) = _structarray(args, nothing)
_structarray(args::NTuple{N, Any}, names::NTuple{N, Symbol}) where {N} = StructArray(NamedTuple{names}(args))

const StructVector{T, C<:Tup, I} = StructArray{T, 1, C, I}
StructVector{T}(args...; kwargs...) where {T} = StructArray{T}(args...; kwargs...)
StructVector(args...; kwargs...) = StructArray(args...; kwargs...)

"""
    StructArray{T}(A::AbstractArray; dims, unwrap=FT->FT!=eltype(A))

Construct a `StructArray` from slices of `A` along `dims`.

The `unwrap` keyword argument is a function that determines whether to
recursively convert fields of type `FT` to `StructArray`s.

```julia-repl
julia> X = [1.0 2.0; 3.0 4.0]
2×2 Array{Float64,2}:
 1.0  2.0
 3.0  4.0

julia> StructArray{Complex{Float64}}(X; dims=1)
2-element StructArray(view(::Array{Float64,2}, 1, :), view(::Array{Float64,2}, 2, :)) with eltype Complex{Float64}:
 1.0 + 3.0im
 2.0 + 4.0im

julia> StructArray{Complex{Float64}}(X; dims=2)
2-element StructArray(view(::Array{Float64,2}, :, 1), view(::Array{Float64,2}, :, 2)) with eltype Complex{Float64}:
 1.0 + 2.0im
 3.0 + 4.0im
```

By default, fields will be unwrapped until they match the element type of the array:
```
julia> StructArray{Tuple{Float64,Complex{Float64}}}(rand(3,2); dims=1)
2-element StructArray(view(::Array{Float64,2}, 1, :), StructArray(view(::Array{Float64,2}, 2, :), view(::Array{Float64,2}, 3, :))) with eltype Tuple{Float64,Complex{Float64}}:
 (0.004767505234193781, 0.27949621887414566 + 0.9039320635041561im)
 (0.41853472213051335, 0.5760165160827859 + 0.9782723869433818im)
```
"""
StructArray(A::AbstractArray; dims, unwrap)
function StructArray{T}(A::AbstractArray; dims, unwrap=FT->FT!=eltype(A)) where {T}
    slices = Iterators.Stateful(eachslice(A; dims=dims))
    buildfromslices(T, unwrap, slices)
end
function buildfromslices(::Type{T}, unwrap::F, slices) where {T,F}
    if unwrap(T)
        buildfromschema(T) do FT
            buildfromslices(FT, unwrap, slices)
        end
    else
        return popfirst!(slices)
    end
end

function Base.IndexStyle(::Type{S}) where {S<:StructArray}
    index_type(S) === Int ? IndexLinear() : IndexCartesian()
end

function undef_array(::Type{T}, sz; unwrap::F = alwaysfalse) where {T, F}
    if unwrap(T)
        return StructArray{T}(undef, sz; unwrap = unwrap)
    else
        return Array{T}(undef, sz)
    end
end

function similar_array(v::AbstractArray, ::Type{Z}; unwrap::F = alwaysfalse) where {Z, F}
    if unwrap(Z)
        return buildfromschema(typ -> similar_array(v, typ; unwrap = unwrap), Z)
    else
        return similar(v, Z)
    end
end

function similar_structarray(v::AbstractArray, ::Type{Z}; unwrap::F = alwaysfalse) where {Z, F}
    buildfromschema(typ -> similar_array(v, typ; unwrap = unwrap), Z)
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
    buildfromschema(typ -> undef_array(typ, sz; unwrap = unwrap), T)
end
StructArray{T}(u::Base.UndefInitializer, d::Integer...; unwrap::F = alwaysfalse) where {T, F} = StructArray{T}(u, convert(Dims, d); unwrap = unwrap)

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

# Helper function to avoid adding too many dispatches to `Base.similar`
function _similar(s::StructArray{T}, ::Type{T}, sz) where {T}
    return StructArray{T}(map(typ -> similar(typ, sz), components(s)))
end

function _similar(s::StructArray{T}, S::Type, sz) where {T}
    # If not specified, we don't really know what kind of array to use for each
    # interior type, so we just pick the first one arbitrarily. If users need
    # something else, they need to be more specific.
    c1 = first(components(s))
    return isnonemptystructtype(S) ? buildfromschema(typ -> similar(c1, typ, sz), S) : similar(c1, S, sz)
end

for type in (
        :Dims,
        # mimic OffsetArrays signature
        :(Tuple{Union{Integer, AbstractUnitRange}, Vararg{Union{Integer, AbstractUnitRange}}}),
        # disambiguation with Base
        :(Tuple{Union{Integer, Base.OneTo}, Vararg{Union{Integer, Base.OneTo}}}),
    )
    @eval function Base.similar(::Type{<:StructArray{T, N, C}}, sz::$(type)) where {T, N, C}
        return buildfromschema(typ -> similar(typ, sz), T, C)
    end

    @eval function Base.similar(s::StructArray, S::Type, sz::$(type))
        return _similar(s, S, sz)
    end
end

@deprecate fieldarrays(x) StructArrays.components(x)

"""
    components(s::StructArray)

Return the field arrays corresponding to the various entry of the struct as a `NamedTuple`, or a `Tuple` if the struct has no names.

# Examples

```julia-repl
julia> s = StructArray(rand(ComplexF64, 4));

julia> components(s)
(re = [0.396526, 0.486036, 0.459595, 0.0323561], im = [0.147702, 0.81043, 0.00993469, 0.487091])
```
"""
components(s::StructArray) = getfield(s, :components)

component(s::StructArray, key) = getfield(components(s), key)

Base.getproperty(s::StructArray, key::Symbol) = component(s, key)
Base.getproperty(s::StructArray, key::Int) = component(s, key)
Base.propertynames(s::StructArray) = propertynames(components(s))

staticschema(::Type{StructArray{T, N, C, I}}) where {T, N, C, I} = staticschema(C)
createinstance(::Type{<:StructArray{T}}, args...) where {T} = StructArray{T}(args)

Base.size(s::StructArray) = size(components(s)[1])
Base.axes(s::StructArray) = axes(components(s)[1])

"""
    StructArrays.get_ith(cols::Union{Tuple,NamedTuple}, I...)

Form a `Tuple` of the `I`th index of each element of `cols`, i.e. is equivalent
to
```julia
map(c -> c[I...], Tuple(cols))
```
"""
@inline @generated get_ith(cols::Tup, I...) = :(Base.Cartesian.@ntuple $(fieldcount(cols)) i -> @inbounds cols[i][I...])

Base.@propagate_inbounds Base.getindex(x::StructArray, I...) = _getindex(x, to_indices(x, I)...)

Base.@propagate_inbounds function _getindex(x::StructArray{T}, I::Vararg{Int}) where {T}
    cols = components(x)
    @boundscheck checkbounds(x, I...)
    return createinstance(T, get_ith(cols, I...)...)
end

@inline function _getindex(s::StructArray{T}, I...) where {T}
    @boundscheck checkbounds(s, I...)
    StructArray{T}(map(v -> @inbounds(getindex(v, I...)), components(s)))
end

@inline function Base.view(s::StructArray{T, N, C}, I...) where {T, N, C}
    @boundscheck checkbounds(s, I...)
    StructArray{T}(map(v -> @inbounds(view(v, I...)), components(s)))
end

function Base.parentindices(s::StructArray)
    res = findconsistentvalue(parentindices, components(s))
    (res === nothing) && throw(ArgumentError("inconsistent parentindices of components"))
    return res
end

Base.@propagate_inbounds function Base.setindex!(s::StructArray{T, <:Any, <:Any, CartesianIndex{N}}, vals, I::Vararg{Int, N}) where {T,N}
    @boundscheck checkbounds(s, I...)
    valsT = maybe_convert_elt(T, vals)
    foreachfield((col, val) -> (@inbounds col[I...] = val), s, valsT)
    return s
end

Base.@propagate_inbounds function Base.setindex!(s::StructArray{T, <:Any, <:Any, Int}, vals, I::Int) where T
    @boundscheck checkbounds(s, I)
    valsT = maybe_convert_elt(T, vals)
    foreachfield((col, val) -> (@inbounds col[I] = val), s, valsT)
    return s
end

for f in (:push!, :pushfirst!)
    @eval function Base.$f(s::StructVector{T}, vals) where T
        valsT = maybe_convert_elt(T, vals)
        foreachfield($f, s, valsT)
        return s
    end
end

for f in (:append!, :prepend!)
    @eval function Base.$f(s::StructVector{T}, vals::StructVector{T}) where T
        # If these aren't the same type, there's no guarantee that x.a "means" the same thing as y.a,
        # even when all the field names match.
        foreachfield($f, s, vals)
        return s
    end
end

function Base.insert!(s::StructVector{T}, i::Integer, vals) where T
    valsT = maybe_convert_elt(T, vals)
    foreachfield((v, val) -> insert!(v, i, val), s, valsT)
    return s
end

for f in (:pop!, :popfirst!)
    @eval function Base.$f(s::StructVector{T}) where T
        t = map($f, components(s))
        return createinstance(T, t...)
    end
end

function Base.deleteat!(s::StructVector{T}, idxs) where T
    t = map(Base.Fix2(deleteat!, idxs), components(s))
    return StructVector{T}(t)
end

Base.copyto!(I::StructArray, J::StructArray) = (foreachfield(copyto!, I, J); I)

function Base.copyto!(I::StructArray, doffs::Integer, J::StructArray, soffs::Integer, n::Integer)
    foreachfield((dest, src) -> copyto!(dest, doffs, src, soffs, n), I, J)
    return I
end

function Base.fill!(s::StructArray{T}, x) where {T}
    xT = maybe_convert_elt(T, x)
    foreachfield(fill!, s, xT)
    return s
end

function Base.resize!(s::StructArray, i::Integer)
    for a in components(s)
        resize!(a, i)
    end
    return s
end

function Base.empty!(s::StructArray)
    foreachfield(empty!, s)
end

function Base.sizehint!(s::StructArray, i::Integer)
    for a in components(s)
        sizehint!(a, i)
    end
    return s
end

for op in [:cat, :hcat, :vcat]
    curried_op = Symbol(:curried, op)
    @eval begin
        function Base.$op(arg::StructArray, others::StructArray...; kwargs...)
            $curried_op(A...) = $op(A...; kwargs...)
            args = (arg, others...)
            T = mapreduce(eltype, promote_type, args)
            StructArray{T}(map($curried_op, map(components, args)...))
        end
    end
end

Base.copy(s::StructArray{T}) where {T} = StructArray{T}(map(copy, components(s)))

for type in (
        :Dims,
        # mimic OffsetArrays signature
        :(Tuple{Union{Integer, AbstractUnitRange, Colon}, Vararg{Union{Integer, AbstractUnitRange, Colon}}}),
        # disambiguation with Base
        :(Tuple{Union{Integer, Base.OneTo}, Vararg{Union{Integer, Base.OneTo}}}),
        :(Tuple{Vararg{Union{Colon, Integer}}}),
        :(Tuple{Vararg{Union{Colon, Int}}}),
        :(Tuple{Colon}),
    )
    @eval function Base.reshape(s::StructArray{T}, d::$(type)) where {T}
        StructArray{T}(map(x -> reshape(x, d), components(s)))
    end
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
    showfields(io, Tuple(components(s)))
    toplevel && print(io, " with eltype ", T)
end

# broadcast
import Base.Broadcast: BroadcastStyle, AbstractArrayStyle, Broadcasted, DefaultArrayStyle, Unknown, ArrayConflict
using Base.Broadcast: combine_styles

struct StructArrayStyle{S, N} <: AbstractArrayStyle{N} end

# Here we define the dimension tracking behavior of StructArrayStyle
function StructArrayStyle{S, M}(::Val{N}) where {S, M, N}
    T = S <: AbstractArrayStyle{M} ? typeof(S(Val{N}())) : S
    return StructArrayStyle{T, N}()
end

# StructArrayStyle is a wrapped style.
# Here we try our best to resolve style conflict.
function BroadcastStyle(b::AbstractArrayStyle{M}, a::StructArrayStyle{S, N}) where {S, N, M}
    N′ = M === Any || N === Any ? Any : max(M, N)
    S′ = Broadcast.result_style(S(), b)
    return S′ isa StructArrayStyle ? typeof(S′)(Val{N′}()) : StructArrayStyle{typeof(S′), N′}()
end
BroadcastStyle(::StructArrayStyle, ::DefaultArrayStyle) = Unknown()

@inline combine_style_types(::Type{A}, args...) where {A<:AbstractArray} =
    combine_style_types(BroadcastStyle(A), args...)
@inline combine_style_types(s::BroadcastStyle, ::Type{A}, args...) where {A<:AbstractArray} =
    combine_style_types(Broadcast.result_style(s, BroadcastStyle(A)), args...)
combine_style_types(::StructArrayStyle{S}) where {S} = S() # avoid nested StructArrayStyle
combine_style_types(s::BroadcastStyle) = s

Base.@pure cst(::Type{SA}) where {SA} = combine_style_types(array_types(SA).parameters...)

BroadcastStyle(::Type{SA}) where {SA<:StructArray} = StructArrayStyle{typeof(cst(SA)), ndims(SA)}()

"""
    always_struct_broadcast(style::BroadcastStyle)

Check if `style` supports struct-broadcast natively, which means:
1) `Base.copy` is not overloaded.
2) `Base.similar` is defined.
3) `Base.copyto!` supports `StructArray`s as broadcasted arguments.

If any of the above conditions are not met, then this function should
not be overloaded.
In that case, try to overload [`try_struct_copy`](@ref) to support out-of-place
struct-broadcast.
"""
always_struct_broadcast(::Any) = false
always_struct_broadcast(::DefaultArrayStyle) = true
always_struct_broadcast(::ArrayConflict) = true

"""
    try_struct_copy(bc::Broadcasted)

Entry for non-native outplace struct-broadcast.

See also [`always_struct_broadcast`](@ref).
"""
try_struct_copy(bc::Broadcasted) = copy(bc)

@inline function Base.copy(bc::Broadcasted{StructArrayStyle{S, N}}) where {S, N}
    if always_struct_broadcast(S())
        return invoke(copy, Tuple{Broadcasted}, bc)
    else
        return try_struct_copy(replace_structarray(bc))
    end
end

"""
    replace_structarray(bc::Broadcasted)

An internal function transforms the `Broadcasted` with `StructArray` into
an equivalent one without it. This is not a must if the root `BroadcastStyle`
supports `AbstractArray`. But some `BroadcastStyle` limits the input array types, 
e.g. `StaticArrayStyle`, thus we have to omit all `StructArray`.
"""
function replace_structarray(bc::Broadcasted{Style}) where {Style}
    args = replace_structarray_args(bc.args)
    Style′ = parent_style(Style())
    return Broadcasted{Style′}(bc.f, args, bc.axes)
end
function replace_structarray(A::StructArray)
    f = Instantiator(eltype(A))
    args = Tuple(components(A))
    Style = typeof(combine_styles(args...))
    return Broadcasted{Style}(f, args, axes(A))
end
replace_structarray(@nospecialize(A)) = A

replace_structarray_args(args::Tuple) = (replace_structarray(args[1]), replace_structarray_args(tail(args))...)
replace_structarray_args(::Tuple{}) = ()

parent_style(@nospecialize(x)) = typeof(x)
parent_style(::StructArrayStyle{S, N}) where {S, N} = S
parent_style(::StructArrayStyle{S, N}) where {N, S<:AbstractArrayStyle{N}} = S
parent_style(::StructArrayStyle{S, N}) where {S<:AbstractArrayStyle{Any}, N} = S
parent_style(::StructArrayStyle{S, N}) where {S<:AbstractArrayStyle, N} = typeof(S(Val(N)))

# `instantiate` and `_axes` might be overloaded for static axes.
function Broadcast.instantiate(bc::Broadcasted{Style}) where {Style <: StructArrayStyle}
    Style′ = parent_style(Style())
    bc′ = Broadcast.instantiate(convert(Broadcasted{Style′}, bc))
    return convert(Broadcasted{Style}, bc′)
end

function Broadcast._axes(bc::Broadcasted{Style}, ::Nothing) where {Style <: StructArrayStyle}
    Style′ = parent_style(Style())
    return Broadcast._axes(convert(Broadcasted{Style′}, bc), nothing)
end

# Here we use `similar` defined for `S` to build the dest Array.
function Base.similar(bc::Broadcasted{StructArrayStyle{S, N}}, ::Type{ElType}) where {S, N, ElType}
    bc′ = convert(Broadcasted{S}, bc)
    return isnonemptystructtype(ElType) ? buildfromschema(T -> similar(bc′, T), ElType) : similar(bc′, ElType)
end

# Unwrapper to recover the behaviour defined by parent style.
@inline function Base.copyto!(dest::AbstractArray, bc::Broadcasted{StructArrayStyle{S, N}}) where {S, N}
    bc′ = always_struct_broadcast(S()) ? convert(Broadcasted{S}, bc) : replace_structarray(bc)
    return copyto!(dest, bc′)
end

@inline function Broadcast.materialize!(::StructArrayStyle{S}, dest, bc::Broadcasted) where {S}
    bc′ = always_struct_broadcast(S()) ? bc : replace_structarray(bc)
    return Broadcast.materialize!(S(), dest, bc′)
end

# for aliasing analysis during broadcast
function Broadcast.broadcast_unalias(dest::StructArray, src::AbstractArray)
    if dest === src || any(Base.Fix2(===, src), components(dest))
        return src
    else
        return Base.unalias(dest, src)
    end
end

Base.dataids(u::StructArray) = mapreduce(Base.dataids, (a, b) -> (a..., b...), values(components(u)), init=())

# Since all the components have the same axes, we choose the type of the first one to
# define IteratorSize for a StructArray
Base.IteratorSize(::Type{<:StructArray{<:Any,<:Any,C}}) where {C} = Base.IteratorSize(fieldtype(C, 1))
