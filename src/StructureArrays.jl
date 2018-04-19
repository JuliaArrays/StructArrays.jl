module StructureArrays

import Base:
    getindex, setindex!, size, push!, view, getproperty, append!, cat
#     linearindexing, push!, size, sort, sort!, permute!, issorted, sortperm,
#     summary, resize!, vcat, serialize, deserialize, append!, copy!, view

export StructureArray

const Tup = Union{Tuple, NamedTuple}

include("structurearray.jl")
include("utils.jl")

end # module
