module StructArraysGPUArraysCoreExt

using StructArrays
using StructArrays: map_params, array_types

using Base: tail

import GPUArraysCore

# for GPU broadcast
import GPUArraysCore
function GPUArraysCore.backend(::Type{T}) where {T<:StructArray}
    backends = map_params(GPUArraysCore.backend, array_types(T))
    backend, others = backends[1], tail(backends)
    isconsistent = mapfoldl(isequal(backend), &, others; init=true)
    isconsistent || throw(ArgumentError("all component arrays must have the same GPU backend"))
    return backend
end
StructArrays.always_struct_broadcast(::GPUArraysCore.AbstractGPUArrayStyle) = true

end # module
