module StructArrays

using Base: tail

export StructArray, StructVector, LazyRow, LazyRows
export collect_structarray
export replace_storage

include("interface.jl")
include("structarray.jl")
include("utils.jl")
include("collect.jl")
include("sort.jl")
include("lazy.jl")
include("tables.jl")
include("staticarrays_support.jl")

# Implement refarray and refvalue to deal with pooled arrays and weakrefstrings effectively
import DataAPI: refarray, refvalue
using DataAPI: defaultarray

refarray(s::StructArray) = StructArray(map(refarray, components(s)))

function refvalue(s::StructArray{T}, v::Tup) where {T}
    createinstance(T, map(refvalue, components(s), v)...)
end

# Use Adapt allows for automatic conversion of CPU to GPU StructArrays
import Adapt
Adapt.adapt_structure(to, s::StructArray) = replace_storage(x->Adapt.adapt(to, x), s)

# for GPU broadcast
import GPUArraysCore
function GPUArraysCore.backend(::Type{T}) where {T<:StructArray}
    backs = map(GPUArraysCore.backend, fieldtypes(array_types(T)))
    all(Base.Fix2(===, backs[1]), tail(backs)) || error("backend mismatch!")
    return backs[1]
end

end # module
