module StructArrays

import Requires
export StructArray, StructVector
export collect_structarray

include("interface.jl")
include("structarray.jl")
include("utils.jl")
include("collect.jl")
include("sort.jl")
include("lazy.jl")

function __init__()
    Requires.@require Tables="bd369af6-aec1-5ad0-b16a-f7cc5008161c" include("tables.jl")
    Requires.@require PooledArrays="2dfb63ee-cc39-5dd5-95bd-886bf059d720" begin
        fastpermute!(v::PooledArrays.PooledArray, p::AbstractVector) = permute!(v, p)
        function fast_sortable(y::PooledArrays.PooledArray)
            if y.pool isa Dict # Compatibility for PooledArrays < v0.5
                pool = [y.revpool[i] for i=1:length(y.revpool)]
            else
                pool = y.pool
            end
            poolranks = invperm(sortperm(pool))
            newpool = Dict(j=>convert(eltype(y.refs), i) for (i,j) in enumerate(poolranks))
            PooledArrays.PooledArray(PooledArrays.RefArray(y.refs), newpool)
        end
    end
    Requires.@require WeakRefStrings="ea10d353-3f73-51f8-a26c-33c1cb351aa5" begin
        fastpermute!(v::WeakRefStrings.StringArray, p::AbstractVector) = permute!(v, p)
    end
end

end # module
