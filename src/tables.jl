Tables.istable(::Type{<:StructArray}) = true
Tables.rowaccess(::Type{<:StructArray}) = true
Tables.columnaccess(::Type{<:StructArray}) = true

Tables.rows(s::StructArray) = s
Tables.columns(s::StructArray) = fieldarrays(s)

function Tables.schema(s::StructArray{T}) where {T}
    NT = staticschema(T)
    names = fieldnames(NT)
    types = tuple_type(NT).parameters
    Tables.Schema(names, types)
end
