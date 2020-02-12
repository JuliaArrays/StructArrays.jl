using Tables: Tables

Tables.isrowtable(::Type{<:StructVector}) = true

Tables.columnaccess(::Type{<:StructVector}) = true
Tables.columns(s::StructVector) = fieldarrays(s)

Tables.schema(s::StructVector) = Tables.Schema(staticschema(eltype(s)))

function Base.append!(s::StructVector, rows)
    if Tables.isrowtable(rows) && Tables.columnaccess(rows)
        # Input `rows` is a container of rows _and_ satisfies column
        # table interface.  Thus, we can add the input column-by-column.
        table = Tables.columns(rows)
        nt = foldl(Tables.columnnames(table); init = NamedTuple()) do nt, name
            (; nt..., name => Tables.getcolumn(table, name))
        end
        return append!(s, StructArray(nt))
    else
        # Otherwise, fallback to a generic implementation expecting
        # that `rows` is an iterator:
        return foldl(push!, rows; init=s)
    end
end
