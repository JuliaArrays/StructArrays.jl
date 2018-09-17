Tables.istable(::Type{<:StructArray}) = true
Tables.rowaccess(::Type{<:StructArray}) = true
Tables.columnaccess(::Type{<:StructArray}) = true

Tables.rows(s::StructArray) = s
Tables.columns(s::StructArray) = columns(s)

@generated function Tables.schema(s::StructArray{T}) where {T}
    names = fieldnames(T)
    types = map(sym -> fieldtype(T, sym), names)
    :(Tables.Schema($names, $types))
end
