module StructArrays

import Requires
using PooledArrays: PooledArray

export StructArray, StructVector, LazyRow, LazyRows
export collect_structarray, fieldarrays

include("interface.jl")
include("structarray.jl")
include("utils.jl")
include("collect.jl")
include("sort.jl")
include("lazy.jl")

function __init__()
    Requires.@require Tables="bd369af6-aec1-5ad0-b16a-f7cc5008161c" include("tables.jl")
    Requires.@require WeakRefStrings="ea10d353-3f73-51f8-a26c-33c1cb351aa5" begin
        fastpermute!(v::WeakRefStrings.StringArray, p::AbstractVector) = permute!(v, p)
        @inline function roweq(a::WeakRefStrings.StringArray{String}, i, j)
            weaksa = convert(WeakRefStrings.StringArray{WeakRefStrings.WeakRefString{UInt8}}, a)
            @inbounds isequal(weaksa[i], weaksa[j])
        end
    end
end

end # module
