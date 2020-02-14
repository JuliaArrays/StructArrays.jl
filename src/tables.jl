Tables.isrowtable(::Type{<:StructArray}) = true

Tables.columnaccess(::Type{<:StructArray}) = true
Tables.columns(s::StructArray) = fieldarrays(s)
Tables.getcolumn(s::StructArray, i::Int) = getproperty(s, i)
Tables.schema(s::StructArray) = Tables.Schema(staticschema(eltype(s)))

function Base.append!(s::StructVector, rows)
    if Tables.isrowtable(rows) && Tables.columnaccess(rows)
        # Input `rows` is a container of rows _and_ satisfies column
        # table interface.  Thus, we can add the input column-by-column.
        table = Tables.columns(rows)
        isempty(_setdiff(propertynames(s), Tables.columnnames(rows))) ||
            _invalid_columns_error(s, rows)
        foreachfield(append!, s, table)
        return s
    else
        # Otherwise, fallback to a generic implementation expecting
        # that `rows` is an iterator:
        return foldl(push!, rows; init = s)
    end
end

@noinline function _invalid_columns_error(s, rows)
    missingnames = setdiff!(collect(Tables.columnnames(rows)), propertynames(s))
    throw(ArgumentError(string(
        "Cannot append rows from `$(typeof(rows))` to `$(typeof(s))` due to ",
        "missing column(s):\n",
        join(missingnames, ", "),
    )))
end
