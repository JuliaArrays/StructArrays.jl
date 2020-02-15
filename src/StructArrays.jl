module StructArrays

using Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail

export StructArray, StructVector, LazyRow, LazyRows
export collect_structarray, fieldarrays
export replace_storage

include("interface.jl")
include("structarray.jl")
include("utils.jl")
include("collect.jl")
include("sort.jl")
include("groupjoin.jl")
include("lazy.jl")
include("tables.jl")

# Implement refarray and refvalue to deal with pooled arrays and weakrefstrings effectively
import DataAPI: refarray, refvalue

refarray(s::StructArray) = StructArray(map(refarray, fieldarrays(s)))

function refvalue(s::StructArray{T}, v::Tup) where {T}
    createinstance(T, map(refvalue, fieldarrays(s), v)...)
end

# Use Adapt allows for automatic conversion of CPU to GPU StructArrays
import Adapt
Adapt.adapt_structure(to, s::StructArray) = replace_storage(x->Adapt.adapt(to, x), s)

end # module
