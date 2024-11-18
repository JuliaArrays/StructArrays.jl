module StructArrays

using Base: tail
using ConstructionBase: constructorof

export StructArray, StructVector, LazyRow, LazyRows
export collect_structarray
export replace_storage

include("interface.jl")
include("structarray.jl")
include("utils.jl")
include("collect.jl")
include("sort.jl")
include("lazy.jl")
include("constructionbase.jl")
include("tables.jl")

# Implement refarray and refvalue to deal with pooled arrays and weakrefstrings effectively
import DataAPI: refarray, refvalue
using DataAPI: defaultarray

refarray(s::StructArray) = StructArray(map(refarray, components(s)))

function refvalue(s::StructArray{T}, v::Tup) where {T}
    createinstance(T, map(refvalue, components(s), v)...)
end

# implement colmetadata for StructArray based on metadata of individual columns
import DataAPI: metadata, metadatasupport, colmetadata, colmetadatasupport

colmetadatasupport(::Type{T}) where {T<:StructArray} = (
    read=any(col -> metadatasupport(col).read, array_types(T).parameters),
    write=false,  # not implemented
)
colmetadata(sa::StructArray, col::Symbol) = metadata(getproperty(sa, col))
colmetadata(sa::StructArray) =
    map(Tables.columns(sa)) do col
        metadatasupport(typeof(col)).read ? metadata(col) : nothing
    end

@static if !isdefined(Base, :get_extension)
    include("../ext/StructArraysAdaptExt.jl")
    include("../ext/StructArraysGPUArraysCoreExt.jl")
    include("../ext/StructArraysSparseArraysExt.jl")
    include("../ext/StructArraysStaticArraysExt.jl")
    include("../ext/StructArraysLinearAlgebraExt.jl")
end

end # module
