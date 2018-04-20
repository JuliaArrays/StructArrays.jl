module StructArrays

import Base:
    getindex, setindex!, size, push!, view, getproperty, append!, cat, vcat, hcat
#     linearindexing, push!, size, sort, sort!, permute!, issorted, sortperm,
#     summary, resize!, vcat, serialize, deserialize, append!, copy!, view

export StructArray

const Tup = Union{Tuple, NamedTuple}

include("structarray.jl")
include("utils.jl")

end # module
