using ExtendedRationals
using Test
using Aqua

@testset "ExtendedRationals.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(ExtendedRationals)
    end
end
