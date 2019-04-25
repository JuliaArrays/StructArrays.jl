Tables.istable(::Type{<:StructVector}) = true
Tables.rowaccess(::Type{<:StructVector}) = true
Tables.columnaccess(::Type{<:StructVector}) = true

Tables.rows(s::StructVector) = s
Tables.columns(s::StructVector) = fieldarrays(s)

Tables.schema(s::StructVector) = Tables.Schema(staticschema(eltype(s)))
