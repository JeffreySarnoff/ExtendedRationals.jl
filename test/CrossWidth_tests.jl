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
    @test widen(Qx32) === Qx64

    raw32 = Qx32(6, 8)
    widened64 = Qx64(raw32)
    @test widened64 == Qx64(3, 4)
    @test widened64.num == Int64(6)
    @test widened64.den == Int64(8)
    @test widen(raw32) == widened64
    @test Qx64(Qx32(1, 0)) == Qx64(1, 0)
    @test Qx64(Qx32(-1, 0)) == Qx64(-1, 0)
    @test isnan(Qx64(Qx32(0, 0)))
    @test convert(Qx64, raw32) == widened64

    widened128_from32 = Qx128(raw32)
    @test widened128_from32 == Qx128(3, 4)
    @test widened128_from32.num == Int128(6)
    @test widened128_from32.den == Int128(8)
    @test convert(Qx128, Qx32(7, 3)) == Qx128(7, 3)
    @test Qx128(Qx32(1, 0)) == Qx128(1, 0)
    @test Qx128(Qx32(-1, 0)) == Qx128(-1, 0)
    @test isnan(Qx128(Qx32(0, 0)))
    @test convert(Qx128, Qx64(typemax(Int64), typemax(Int64) - 2)) == Qx128(typemax(Int64), typemax(Int64) - 2)
    raw64 = Qx64(10, 14)
    widened128_from64 = Qx128(raw64)
    @test widened128_from64 == Qx128(5, 7)
    @test widened128_from64.num == Int128(10)
    @test widened128_from64.den == Int128(14)
    @test widen(Qx64) === Qx128
    @test widen(raw64) == widened128_from64
    @test convert(Qx128, Qx64(1, 0)) == Qx128(1, 0)
    @test Qx128(Qx64(-1, 0)) == Qx128(-1, 0)
    @test isnan(Qx128(Qx64(0, 0)))
    @test isnan(convert(Qx128, Qx64(0, 0)))

    @test Qx64(Qx128(7, 3)) == Qx64(7, 3)
    @test Qx64(Qx128(1, Int128(typemax(Int64)) + 1)) == Qx64(1, typemax(Int64))
    @test Qx64(Qx128(1, Int128(2) * Int128(typemax(Int64)) + 1)) == Qx64(0, 1)
    @test Qx64(Qx128(Int128(typemax(Int64)) + 1, 1)) == Qx64(1, 0)
    @test Qx64(Qx128(Int128(typemin(Int64)) - 1, 1)) == Qx64(-1, 0)
    @test Qx64(Qx128(1, 0)) == Qx64(1, 0)
    @test isnan(Qx64(Qx128(0, 0)))
    @test convert(Qx64, Qx128(7, 3)) == Qx64(7, 3)

    @test Qx32(Qx128(7, 3)) == Qx32(7, 3)
    @test Qx32(Qx128(1, Int128(typemax(Int32)) + 1)) == Qx32(1, typemax(Int32))
    @test Qx32(Qx128(1, Int128(2) * Int128(typemax(Int32)) + 1)) == Qx32(0, 1)
    @test Qx32(Qx128(Int128(typemax(Int32)) + 1, 1)) == Qx32(1, 0)
    @test Qx32(Qx128(Int128(typemin(Int32)) - 1, 1)) == Qx32(-1, 0)
    @test Qx32(Qx128(1, 0)) == Qx32(1, 0)
    @test isnan(Qx32(Qx128(0, 0)))
    @test convert(Qx32, Qx128(7, 3)) == Qx32(7, 3)
end