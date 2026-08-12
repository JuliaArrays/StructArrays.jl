using BenchmarkTools
using Random
using StructArrays

function countgroups(keys, permutation)
    count = 0
    for _ in StructArrays.GroupPerm(keys, permutation)
        count += 1
    end
    return count
end

rng = MersenneTwister(42)
columns = ntuple(_ -> rand(rng, 1:16, 100_000), 64)
table = StructArray(columns)
permutation = sortperm(table)
@assert countgroups(table, permutation) == length(unique(table))

trial = @benchmark countgroups($table, $permutation) samples=10 evals=1 seconds=60
estimate = minimum(trial)
println(
    "64-column grouping: ",
    BenchmarkTools.prettytime(estimate.time), ", ",
    BenchmarkTools.prettymemory(estimate.memory), ", ",
    estimate.allocs, " allocations",
)
