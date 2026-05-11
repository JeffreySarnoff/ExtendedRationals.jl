using Test

include("../src/Rational128s.jl")
using .Rational128s

@testset "Rational128 rational-valued functions" begin
    x = Rational128(7, 3)
    y = Rational128(2, 3)
    int128max = typemax(Int128)

    @test Rational128(14, -6) == Rational128(-7, 3)
    @test Rational128(0, -11) == Rational128(0, 1)
    @test_throws OverflowError Rational128(typemin(Int128), 1)
    @test_throws OverflowError Rational128(1, typemin(Int128))

    @test copysign(x, -1.0) == Rational128(-7, 3)
    @test copysign(Rational128(-7, 3), 2.0) == Rational128(7, 3)
    @test flipsign(x, -1.0) == Rational128(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == Rational128(1, 3)
    @test mod(Rational128(-7, 3), y) == Rational128(1, 3)
    @test_throws DivideError rem(x, Rational128(0, 1))
    @test_throws DivideError mod(x, Rational128(0, 1))

    @test muladd(Rational128(2, 3), Rational128(3, 4), Rational128(1, 2)) == Rational128(1, 1)
    @test fma(Rational128(2, 3), Rational128(3, 4), Rational128(1, 2)) == Rational128(1, 1)
    @test fma(Rational128(1, int128max), Rational128(1, int128max), Rational128(0, 1)) == Rational128(0, 1)
    @test fma(Rational128(int128max, 1), Rational128(2, 1), Rational128(0, 1)) == Rational128(int128max, 1)
    @test fma(Rational128(int128max, 1), Rational128(1, 1), Rational128(-1, 2)) == Rational128(int128max - 1, 1)

    @test Rational128(2, 3)^3 == Rational128(8, 27)
    @test Rational128(2, 3)^(-2) == Rational128(9, 4)
    @test Rational128(0, 1)^0 == Rational128(1, 1)
    @test_throws DivideError Rational128(0, 1)^(-1)

    @test rem(Rational128(7, 3), 2) == Rational128(1, 3)
    @test mod(-2, Rational128(3, 4)) == Rational128(1, 4)

    @test isinteger(Rational128(4, 1))
    @test !isinteger(Rational128(7, 3))

    @test trunc(Int, Rational128(7, 3)) == 2
    @test floor(Int, Rational128(-7, 3)) == -3
    @test ceil(Int, Rational128(-7, 3)) == -2

    @test trunc(Rational128(7, 3)) == Rational128(2, 1)
    @test floor(Rational128(-7, 3)) == Rational128(-3, 1)
    @test ceil(Rational128(-7, 3)) == Rational128(-2, 1)

    @test fld(Rational128(7, 3), Rational128(2, 3)) == Rational128(3, 1)
    @test cld(Rational128(7, 3), Rational128(2, 3)) == Rational128(4, 1)
    @test divrem(Rational128(7, 3), Rational128(2, 3)) == (3, Rational128(1, 3))
    @test fldmod(Rational128(-7, 3), Rational128(2, 3)) == (-4, Rational128(1, 3))
    @test fldmod1(Rational128(2, 1), Rational128(1, 1)) == (2, Rational128(1, 1))

    @test Rational128(int128max - 1, int128max) + Rational128(1 - int128max, int128max) == Rational128(0, 1)
    @test Rational128(int128max - 1, int128max) * Rational128(int128max, int128max - 1) == Rational128(1, 1)
end

println("Rational128 tests passed.")