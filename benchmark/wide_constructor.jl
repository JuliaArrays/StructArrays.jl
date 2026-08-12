using BenchmarkTools
using StructArrays

construct_wide(columns) = StructArray(columns)

columns = ntuple(_ -> rand(1), 128)
probe = construct_wide(columns)
@assert size(probe) == (1,)

trial = @benchmark construct_wide($columns)
estimate = minimum(trial)
println(
    "128-column constructor: ",
    BenchmarkTools.prettytime(estimate.time), ", ",
    BenchmarkTools.prettymemory(estimate.memory), ", ",
    estimate.allocs, " allocations",
)
