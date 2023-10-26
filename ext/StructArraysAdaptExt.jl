module StructArraysAdaptExt
# Use Adapt allows for automatic conversion of CPU to GPU StructArrays
using Adapt, StructArrays
@static if !applicable(Adapt.adapt, Int)
    # Adapt.jl has curried support, implement it ourself
    adpat(to) = Base.Fix1(Adapt.adapt, to)
    if VERSION < v"1.9.0-DEV.857"
        @eval function adapt(to::Type{T}) where {T}
            (@isdefined T) || return Base.Fix1(Adapt.adapt, to)
            AT = Base.Fix1{typeof(Adapt.adapt),Type{T}}
            return $(Expr(:new, :AT, :(Adapt.adapt), :to))
        end
    end
end
Adapt.adapt_structure(to, s::StructArray) = replace_storage(adapt(to), s)
end
