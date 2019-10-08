module StructArrays

using Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail
using PooledArrays: PooledArray

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
using Tables, WeakRefStrings
include("tables.jl")
function refs(a::WeakRefStrings.StringArray{T}) where {T}
    S = Union{WeakRefStrings.WeakRefString{UInt8}, typeintersect(T, Missing)}
    convert(WeakRefStrings.StringArray{S}, a)
end

end # module
