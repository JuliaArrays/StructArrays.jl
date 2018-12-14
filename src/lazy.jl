struct LazyRow{T, N, C, I}
    columns::StructArray{T, N, C} # a `Columns` object
    index::I
end

Base.getproperty(c::LazyRow, nm::Symbol) = getproperty(getfield(c, 1), nm)[getfield(c, 2)]
Base.setproperty!(c::LazyRow, nm::Symbol, val) = (getproperty(getfield(c, 1), nm)[getfield(c, 2)] = val; nothing)
Base.propertynames(c::LazyRow) = propertynames(getfield(c, 1))

staticschema(::Type{<:LazyRow{T}}) where {T} = staticschema(T)
buildfromschema(f, ::Type{<:LazyRow{T}}) where {T} = buildfromschema(f, T)

iscompatible(::Type{<:LazyRow{S}}, ::Type{StructArray{T, N, C}}) where {S, T, N, C} =
    iscompatible(S, StructArray{T, N, C})

(s::ArrayInitializer)(::Type{<:LazyRow{T}}, d) where {T} = buildfromschema(typ -> s(typ, d), T)
