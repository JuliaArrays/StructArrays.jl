import Tables

Tables.isrowtable(::Type{<:StructArray}) = true

Tables.columnaccess(::Type{<:StructArray}) = true
Tables.columns(s::StructArray) = components(s)
Tables.schema(s::StructArray) = _schema(staticschema(eltype(s)))

_schema(::Type{NT}) where {NT<:NamedTuple} = Tables.Schema(NT)
# make schema for unnamed case
function _schema(::Type{T}) where {T<:NTuple{N, Any}} where N
    return Tables.Schema{ntuple(identity, N), T}
end

StructArray(cols::Tables.AbstractColumns) = StructArray(Tables.columntable(cols))
StructArray{T}(cols::Tables.AbstractColumns) where {T} = StructArray{T}(Tables.columntable(cols))

# convert from any Tables-compliant object
fromtable(cols) = StructArray(Tables.columntable(cols))
Tables.materializer(::Type{<:StructArray}) = fromtable
Tables.materializer(::StructArray) = fromtable  # Tables documentation says it's not needed, but actually it is

function try_compatible_columns(rows::R, s::StructArray) where {R}
    Tables.isrowtable(rows) && Tables.columnaccess(rows) || return nothing
    T = eltype(rows)
    hasfields(T) || return nothing
    NT = staticschema(T)
    _schema(NT) == Tables.schema(rows) || return nothing
    return Tables.columntable(rows)
end
try_compatible_columns(rows::StructArray{T}, s::StructArray{T}) where {T} = Tables.columntable(rows)
try_compatible_columns(rows::StructArray{R}, s::StructArray{S}) where {R,S} = nothing

for (f, g) in zip((:append!, :prepend!), (:push!, :pushfirst!))
    @eval function Base.$f(s::StructVector, rows)
        table = try_compatible_columns(rows, s)
        if table !== nothing
            # Input `rows` is a container of rows _and_ satisfies column
            # table interface.  Thus, we can add the input column-by-column.
            foreachfield($f, s, table)
            return s
        else
            # Otherwise, fallback to a generic implementation expecting
            # that `rows` is an iterator:
            return foldl($g, rows; init = s)
        end
    end
end
