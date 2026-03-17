using Test

include("../src/Rational64s.jl")
using .Rational64s

@testset "Rational64 rational-valued functions" begin
    x = Rational64(7, 3)
    y = Rational64(2, 3)
    int64max = typemax(Int64)

    @test copysign(x, -1.0) == Rational64(-7, 3)
    @test copysign(Rational64(-7, 3), 2.0) == Rational64(7, 3)
    @test flipsign(x, -1.0) == Rational64(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == Rational64(1, 3)
    @test mod(Rational64(-7, 3), y) == Rational64(1, 3)
    @test_throws DivideError rem(x, Rational64(0, 1))
    @test_throws DivideError mod(x, Rational64(0, 1))

    @test muladd(Rational64(2, 3), Rational64(3, 4), Rational64(1, 2)) == Rational64(1, 1)
    @test fma(Rational64(2, 3), Rational64(3, 4), Rational64(1, 2)) == Rational64(1, 1)
    @test fma(Rational64(1, int64max), Rational64(1, int64max), Rational64(0, 1)) == Rational64(0, 1)
    @test fma(Rational64(int64max, 1), Rational64(2, 1), Rational64(0, 1)) == Rational64(int64max, 1)
    @test fma(Rational64(int64max, 1), Rational64(1, 1), Rational64(-1, 2)) == Rational64(int64max - 1, 1)

    @test Rational64(2, 3)^3 == Rational64(8, 27)
    @test Rational64(2, 3)^(-2) == Rational64(9, 4)
    @test Rational64(0, 1)^0 == Rational64(1, 1)
    @test_throws DivideError Rational64(0, 1)^(-1)

    @test rem(Rational64(7, 3), 2) == Rational64(1, 3)
    @test mod(-2, Rational64(3, 4)) == Rational64(1, 4)

    @test isinteger(Rational64(4, 1))
    @test !isinteger(Rational64(7, 3))

    @test trunc(Int, Rational64(7, 3)) == 2
    @test floor(Int, Rational64(-7, 3)) == -3
    @test ceil(Int, Rational64(-7, 3)) == -2

    @test trunc(Rational64(7, 3)) == Rational64(2, 1)
    @test floor(Rational64(-7, 3)) == Rational64(-3, 1)
    @test ceil(Rational64(-7, 3)) == Rational64(-2, 1)

    @test fld(Rational64(7, 3), Rational64(2, 3)) == Rational64(3, 1)
    @test cld(Rational64(7, 3), Rational64(2, 3)) == Rational64(4, 1)
    @test divrem(Rational64(7, 3), Rational64(2, 3)) == (3, Rational64(1, 3))
    @test fldmod(Rational64(-7, 3), Rational64(2, 3)) == (-4, Rational64(1, 3))
    @test fldmod1(Rational64(2, 1), Rational64(1, 1)) == (2, Rational64(1, 1))
end

println("Rational64 tests passed.")