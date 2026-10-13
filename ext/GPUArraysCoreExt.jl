module GPUArraysCoreExt

using StructArrays
import GPUArraysCore

StructArrays.always_struct_broadcast(::GPUArraysCore.AbstractGPUArrayStyle) = true

end # module
