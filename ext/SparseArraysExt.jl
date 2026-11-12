module SparseArraysExt

using StructArrays: StructArray, components, createinstance
import StructArrays
import SparseArrays: sparse, issparse

function sparse(S::StructArray{T}) where {T}
    sparse_components = StructArrays._mapcols(sparse, components(S))
    return createinstance.(T, sparse_components...)
end

issparse(S::StructArray) = all(issparse, components(S))

end
