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

end # module
