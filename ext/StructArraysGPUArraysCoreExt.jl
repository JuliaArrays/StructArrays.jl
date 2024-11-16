module StructArraysGPUArraysCoreExt

using StructArrays
using StructArrays: map_params, array_types

using Base: tail

import GPUArraysCore
import KernelAbstractions as KA

function KA.get_backend(x::T) where {T<:StructArray}
    components = StructArrays.components(x)
    array_components = filter(
        fn -> getfield(components, fn) isa AbstractArray,
        fieldnames(typeof(components)))
    backends = map(
        fn -> KA.get_backend(getfield(components, fn)),
        array_components)

    backend, others = backends[1], tail(backends)
    isconsistent = mapfoldl(isequal(backend), &, others; init=true)
    isconsistent || throw(ArgumentError("all component arrays must have the same GPU backend"))
    return backend
end

StructArrays.always_struct_broadcast(::GPUArraysCore.AbstractGPUArrayStyle) = true

end # module
