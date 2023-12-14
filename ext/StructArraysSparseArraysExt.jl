module StructArraysSparseArraysExt

using StructArrays: StructArray, components, createinstance
import SparseArrays: sparse, issparse

function sparse(S::StructArray{T}) where {T}
    sparse_components = map(sparse, components(S))
    return createinstance.(T, sparse_components...)
end

issparse(S::StructArray) = all(issparse, components(S))

end
