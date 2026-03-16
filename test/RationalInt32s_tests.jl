using Test

include("RationalInt32s.jl")
using .RationalInt32s

@testset "Rational32 rational-valued functions" begin
    x = Rational32(7, 3)
    y = Rational32(2, 3)
    int32max = typemax(Int32)

    @test copysign(x, -1.0) == Rational32(-7, 3)
    @test copysign(Rational32(-7, 3), 2.0) == Rational32(7, 3)
    @test flipsign(x, -1.0) == Rational32(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == Rational32(1, 3)
    @test mod(Rational32(-7, 3), y) == Rational32(1, 3)
    @test_throws DivideError rem(x, Rational32(0, 1))
    @test_throws DivideError mod(x, Rational32(0, 1))

    @test muladd(Rational32(2, 3), Rational32(3, 4), Rational32(1, 2)) == Rational32(1, 1)
    @test fma(Rational32(2, 3), Rational32(3, 4), Rational32(1, 2)) == Rational32(1, 1)
    @test fma(Rational32(1, int32max), Rational32(1, int32max), Rational32(0, 1)) == Rational32(0, 1)
    @test fma(Rational32(int32max, 1), Rational32(2, 1), Rational32(0, 1)) == Rational32(int32max, 1)
    @test fma(Rational32(int32max, 1), Rational32(1, 1), Rational32(-1, 2)) == Rational32(int32max - 1, 1)

    @test Rational32(2, 3)^3 == Rational32(8, 27)
    @test Rational32(2, 3)^(-2) == Rational32(9, 4)
    @test Rational32(0, 1)^0 == Rational32(1, 1)
    @test_throws DivideError Rational32(0, 1)^(-1)

    @test rem(Rational32(7, 3), 2) == Rational32(1, 3)
    @test mod(-2, Rational32(3, 4)) == Rational32(1, 4)

    @test isinteger(Rational32(4, 1))
    @test !isinteger(Rational32(7, 3))

    @test trunc(Int, Rational32(7, 3)) == 2
    @test floor(Int, Rational32(-7, 3)) == -3
    @test ceil(Int, Rational32(-7, 3)) == -2

    @test trunc(Rational32(7, 3)) == Rational32(2, 1)
    @test floor(Rational32(-7, 3)) == Rational32(-3, 1)
    @test ceil(Rational32(-7, 3)) == Rational32(-2, 1)

    @test fld(Rational32(7, 3), Rational32(2, 3)) == Rational32(3, 1)
    @test cld(Rational32(7, 3), Rational32(2, 3)) == Rational32(4, 1)
    @test divrem(Rational32(7, 3), Rational32(2, 3)) == (3, Rational32(1, 3))
    @test fldmod(Rational32(-7, 3), Rational32(2, 3)) == (-4, Rational32(1, 3))
    @test fldmod1(Rational32(2, 1), Rational32(1, 1)) == (2, Rational32(1, 1))
end

println("Rational32 tests passed.")
