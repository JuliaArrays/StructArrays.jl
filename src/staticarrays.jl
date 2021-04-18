# These definitions allow `StructArray` and `StaticArrays.SArray` to play nicely together.
StructArrays.staticschema(::Type{SArray{S,T,N,L}}) where {S,T,N,L} = NTuple{L,T}
StructArrays.createinstance(::Type{SArray{S,T,N,L}}, args...) where {S,T,N,L} =
    SArray{S,T,N,L}(args...)
StructArrays.component(s::SArray, i) = getindex(s, i)
