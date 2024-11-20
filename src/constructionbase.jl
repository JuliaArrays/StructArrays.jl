using ConstructionBase

# (named)tuple eltypes: components/fields are all that's needed for the StructArray() constructor
ConstructionBase.constructorof(::Type{<:StructArray{<:Union{Tuple, NamedTuple}}}) = StructArray

# other eltypes: need to pass eltype to the constructor in addition to components
ConstructionBase.constructorof(::Type{<:StructArray{T}}) where {T} = function(comps::CT) where {CT}
    # the resulting eltype is like T, but potentially with different type parameters, eg Complex{Int} -> Complex{Float64}
    # probe its constructorof to get the right concrete type
    ET = Base.promote_op(constructorof(T), map(eltype, fieldtypes(CT))...)
    StructArray{ET}(comps)
end

# two methods with the same body, required to avoid ambiguities
# just redirect setproperties to constructorof
ConstructionBase.setproperties(x::StructArray, patch::NamedTuple) = constructorof(typeof(x))(setproperties(getproperties(x), patch))
ConstructionBase.setproperties(x::StructArray, patch::Tuple) = constructorof(typeof(x))(setproperties(getproperties(x), patch))
