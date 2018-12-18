Tables.istable(::Type{<:StructVector}) = true
Tables.istable(::Type{<:StructVector{<:Tuple}}) = false
Tables.rowaccess(::Type{<:StructVector}) = true
Tables.columnaccess(::Type{<:StructVector}) = true

Tables.rows(s::StructVector) = s
Tables.columns(s::StructVector) = fieldarrays(s)

function Tables.schema(s::StructVector)
    cols = fieldarrays(s)
    names = propertynames(cols)
    types = map(eltype, cols) 
    Tables.Schema(names, types)
end
