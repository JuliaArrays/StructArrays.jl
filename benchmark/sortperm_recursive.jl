using BenchmarkTools
using Random
using StructArrays

function nested_table(::Type{T}; n=100_000, width=6, cardinality=16, seed=1234) where {T}
    rng = MersenneTwister(seed)
    columns = ntuple(_ -> T.(rand(rng, 1:cardinality, n)), width)
    return StructArray(columns)
end

table = nested_table(Float64)
@assert issorted(table[sortperm(table)])

trial = @benchmark sortperm($table) samples=20 evals=1 seconds=60
estimate = minimum(trial)
println(
    "Float64 keys: ",
    BenchmarkTools.prettytime(estimate.time), ", ",
    BenchmarkTools.prettymemory(estimate.memory), ", ",
    estimate.allocs, " allocations",
)
