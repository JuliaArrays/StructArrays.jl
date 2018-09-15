module StructArrays

import Requires
export StructArray

include("structarray.jl")
include("utils.jl")

Requires.@require Tables="bd369af6-aec1-5ad0-b16a-f7cc5008161c" include("tables.jl")

end # module
