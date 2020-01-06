# GPU storage
import Adapt
Adapt.adapt_structure(to, s::StructArray) = replace_storage(x->Adapt.adapt(to, x), s)

# Table interface
import Tables

Tables.istable(::Type{<:StructVector}) = true
Tables.rowaccess(::Type{<:StructVector}) = true
Tables.columnaccess(::Type{<:StructVector}) = true

Tables.rows(s::StructVector) = s
Tables.columns(s::StructVector) = fieldarrays(s)

Tables.schema(s::StructVector) = Tables.Schema(staticschema(eltype(s)))

# refarray interface
import DataAPI: refarray, refvalue

refarray(s::StructArray) = StructArray(map(refarray, fieldarrays(s)))

function refvalue(s::StructArray{T}, v::Tup) where {T}
    createinstance(T, map(refvalue, fieldarrays(s), v)...)
end
