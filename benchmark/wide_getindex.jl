using BenchmarkTools
using StructArrays

table = StructArray(ntuple(_ -> rand(100), 128))
probe = table[50]
@assert probe == ntuple(i -> components(table)[i][50], 128)

trial = @benchmark $table[50]
estimate = minimum(trial)
println(
    "128-column getindex: ",
    BenchmarkTools.prettytime(estimate.time), ", ",
    BenchmarkTools.prettymemory(estimate.memory), ", ",
    estimate.allocs, " allocations",
)
