using BenchmarkTools
using StructArrays

n = 1_000_000
rows = [(a=i, b=2i, c=3.0i, d=4.0i) for i in 1:n]
base = StructArray((a=Int[], b=Int[], c=Float64[], d=Float64[]))

probe = copy(base)
append!(probe, rows)
@assert probe == rows

trial = @benchmark append!(dest, $rows) setup=(dest=copy($base)) samples=10 evals=1 seconds=60
estimate = minimum(trial)
println(
    "append! rows: ",
    BenchmarkTools.prettytime(estimate.time), ", ",
    BenchmarkTools.prettymemory(estimate.memory), ", ",
    estimate.allocs, " allocations",
)
