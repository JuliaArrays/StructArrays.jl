using Tables: Tables

Tables.isrowtable(::Type{<:StructVector}) = true

Tables.columnaccess(::Type{<:StructVector}) = true
Tables.columns(s::StructVector) = fieldarrays(s)

Tables.schema(s::StructVector) = Tables.Schema(staticschema(eltype(s)))
