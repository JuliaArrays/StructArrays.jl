module StructArraysAdaptExt
# Use Adapt allows for automatic conversion of CPU to GPU StructArrays
using Adapt, StructArrays

function Adapt.adapt_structure(to, s::StructArray)
    replace_storage(adapt(to), s)
end
end
