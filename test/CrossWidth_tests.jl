using XRationals
using Test

@testset "Cross-width extended rational constructors" begin
    @test Qx32(Qx64(3, 2)) == Qx32(3, 2)
    @test Qx32(Qx64(1, typemax(Int64))) == Qx32(0, 1)
    @test Qx32(Qx64(typemax(Int32) + 1, 1)) == Qx32(1, 0)
    @test Qx32(Qx64(typemin(Int32) - 1, 1)) == Qx32(-1, 0)
    @test Qx32(Qx64(2 * typemax(Int32) + 1, 2)) == Qx32(1, 0)
    @test Qx32(Qx64(1, 0)) == Qx32(1, 0)
    @test Qx32(Qx64(-1, 0)) == Qx32(-1, 0)
    @test isnan(Qx32(Qx64(0, 0)))
    @test convert(Qx32, Qx64(7, 3)) == Qx32(7, 3)
end