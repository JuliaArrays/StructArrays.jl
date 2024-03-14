using Aqua
using Test
@testset "project quality" begin
	Aqua.test_all(StructArrays, ambiguities=(; broken=true))
end
