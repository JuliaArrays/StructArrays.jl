module StructArraysSparseArraysExt

using StructArrays
import SparseArrays: sparse

function sparse(S::StructArray{T}) where {T}
	sp = StructArrays.replace_storage(sparse, S)
	T.(sp)
end

end
