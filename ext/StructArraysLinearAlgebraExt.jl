module StructArraysLinearAlgebraExt

using StructArrays
using LinearAlgebra
import LinearAlgebra: mul!

const StructMatrixC{T, A<:AbstractMatrix{T}} = StructArrays.StructMatrix{Complex{T}, @NamedTuple{re::A, im::A}}

function mul!(C::StructMatrixC, A::StructMatrixC, B::StructMatrixC, alpha::Number, beta::Number)
	mul!(C.re, A.re, B.re, alpha, beta)
	mul!(C.re, A.im, B.im, -alpha, oneunit(beta))
	mul!(C.im, A.re, B.im, alpha, beta)
	mul!(C.im, A.im, B.re, alpha, oneunit(beta))
	C
end

end
