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
        function refs(a::WeakRefStrings.StringArray{String})
            convert(WeakRefStrings.StringArray{WeakRefStrings.WeakRefString{UInt8}}, a)
        end
        function pool(v::WeakRefStrings.StringArray{String}, condition = !isbitstype∘eltype)
            condition(v) ? map(String, PooledArray(refs(v))) : v
        end
    end
end

end # module
