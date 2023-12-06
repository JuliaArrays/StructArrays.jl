module StructArraysSparseArraysExt

using StructArrays: StructArray, components
import SparseArrays: sparse, issparse

function sparse(S::StructArray{T}) where {T}
	sparse_components = map(sparse, components(S))
	T.(sparse_components...)
end

issparse(S::StructArray) = all(issparse, components(S))

end
