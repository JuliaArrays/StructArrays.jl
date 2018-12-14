module StructArrays

import Requires
export StructArray, StructVector

include("interface.jl")
include("structarray.jl")
include("utils.jl")
include("collect.jl")
include("sort.jl")

function __init__()
    Requires.@require Tables="bd369af6-aec1-5ad0-b16a-f7cc5008161c" include("tables.jl")
    Requires.@require PooledArrays="2dfb63ee-cc39-5dd5-95bd-886bf059d720" begin
        ispooled(::PooledArrays.PooledArray) = true
    end
    Requires.@require WeakRefStrings="ea10d353-3f73-51f8-a26c-33c1cb351aa5" begin
        isstringarray(::WeakRefStrings.StringArray) = true
    end
end

end # module
