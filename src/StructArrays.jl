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
include("groupjoin.jl")
include("lazy.jl")

function __init__()
    Requires.@require Tables="bd369af6-aec1-5ad0-b16a-f7cc5008161c" include("tables.jl")
    Requires.@require WeakRefStrings="ea10d353-3f73-51f8-a26c-33c1cb351aa5" begin
        fastpermute!(v::WeakRefStrings.StringArray, p::AbstractVector) = permute!(v, p)
        function to_weakrefs(a::WeakRefStrings.StringArray{String})
            convert(WeakRefStrings.StringArray{WeakRefStrings.WeakRefString{UInt8}}, a)
        end
        @inline function roweq(a::WeakRefStrings.StringArray{String}, i, j)
            weaksa = to_weakrefs(a)
            @inbounds isequal(weaksa[i], weaksa[j])
        end
        function pool(v::WeakRefStrings.StringArray{String}, condition = !isbitstype∘eltype)
            condition(v) ? map(String, PooledArray(to_weakrefs(v))) : v
        end
    end
end

end # module
