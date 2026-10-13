module KernelAbstractionsExt

using StructArrays

using Base: tail

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

end # module
