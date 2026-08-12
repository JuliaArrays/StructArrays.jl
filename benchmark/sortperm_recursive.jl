using BenchmarkTools
using Random
using StructArrays

function nested_table(::Type{T}; n=100_000, width=6, cardinality=16, seed=1234) where {T}
    rng = MersenneTwister(seed)
    columns = ntuple(_ -> T.(rand(rng, 1:cardinality, n)), width)
    return StructArray(columns)
end

for T in (Float64, Int)
    table = nested_table(T)
    @assert issorted(table[sortperm(table)])

    trial = @benchmark sortperm($table) samples=20 evals=1 seconds=60
    estimate = minimum(trial)
    println(
        T, " keys: ",
        BenchmarkTools.prettytime(estimate.time), ", ",
        BenchmarkTools.prettymemory(estimate.memory), ", ",
        estimate.allocs, " allocations",
    )
end
