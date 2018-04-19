using StructureArrays
using Test

# write your own tests here
t = StructureArray{typeof((a=1.2, b =2.2))}(rand(2,3), rand(2,3));
t[2,2]
# s = t
# T = typeof(t)
# i = 1
# args = []
# for key in fieldnames(T)
#     field = Expr(:., :n, Expr(:quote, key))
#     push!(args, :($field[i]))
# end
# Expr(:createinstance, :T, args...)
StructureArrays.createtype(NamedTuple{(:a, :b)}, Tuple{Float64, Float64})
s = StructureArray{NamedTuple{(:a, :b)}}([1,2], rand(2));
s = StructureArray((a = rand(2), b = [1,2]))
