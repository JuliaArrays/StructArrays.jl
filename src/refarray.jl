import DataAPI: refarray, refvalue

refarray(s::StructArray) = StructArray(map(refarray, fieldarrays(s)))

function refvalue(s::StructArray{T}, v::Tup) where {T}
    createinstance(T, map(refvalue, fieldarrays(s), v)...)
end
