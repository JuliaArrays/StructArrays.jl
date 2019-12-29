module StructArrays

using Base: tuple_type_cons, tuple_type_head, tuple_type_tail, tail

export StructArray, StructVector, LazyRow, LazyRows
export collect_structarray, fieldarrays
export replace_storage

include("interface.jl")
include("structarray.jl")
include("utils.jl")
include("refarray.jl")
include("collect.jl")
include("sort.jl")
include("groupjoin.jl")
include("lazy.jl")
include("tables.jl")

end # module
