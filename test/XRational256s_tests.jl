using Test
using BitIntegers: Int256

include("../src/XRational256s.jl")
using .XRational256s

@testset "XRational256 constructors and predicates" begin
    x = XRational256(6, -8)
    @test x == XRational256(-3, 4)

    @test isnan(XRational256s.NaN(XRational256))
    @test numerator(XRational256s.NaN(XRational256)) == 0
    @test denominator(XRational256s.NaN(XRational256)) == 0
    @test XRational256s.Inf(XRational256) == XRational256(1, 0)
    @test isinf(XRational256s.Inf(XRational256))
    @test XRational256s.NegInf(XRational256) == XRational256(-1, 0)
    @test isinf(XRational256s.NegInf(XRational256))
    @test signbit(XRational256s.NegInf(XRational256))

    z = XRational256(0, 99)
    @test z == XRational256(0, 1)
    @test iszero(z)

    p = XRational256(5, 0)
    n = XRational256(-7, 0)
    qnan = XRational256(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test XRational256s.finite(XRational256(3, 5))
end

@testset "XRational256 lazy normalization" begin
    x = XRational256(6, 8)
    @test numerator(x) == 3
    @test denominator(x) == 4
    @test x == XRational256(3, 4)
    @test x == XRational256(9, 12)
end

@testset "XRational256 display and conversion" begin
    @test sprint(show, XRational256(3, 2)) == "3//2"
    @test sprint(show, XRational256(1, 0)) == "InfQ256"
    @test sprint(show, XRational256(-1, 0)) == "-InfQ256"
    @test sprint(show, XRational256(0, 0)) == "NaNQ256"
    @test sprint(show, XRational256(6, 8)) == "3//4"

    @test convert(Float64, XRational256(3, 2)) == 1.5
    @test convert(Float64, XRational256(1, 0)) == Inf
    @test convert(Float64, XRational256(-1, 0)) == -Inf
    @test isnan(convert(Float64, XRational256(0, 0)))

    @test_throws InexactError convert(Rational{Int256}, XRational256(1, 0))
end

@testset "XRational256 arithmetic" begin
    a = XRational256(2, 3)
    b = XRational256(5, 7)
    int256min = typemin(Int256)

    @test a + b == XRational256(29, 21)
    @test a - b == XRational256(-1, 21)
    @test a * b == XRational256(10, 21)
    @test a / b == XRational256(14, 15)

    @test a + 1 == XRational256(5, 3)
    @test 1 + a == XRational256(5, 3)
    @test a * 3 == XRational256(2, 1)

    @test XRational256(1, 0) + XRational256(5, 9) == XRational256(1, 0)
    @test isnan(XRational256(1, 0) + XRational256(-1, 0))
    @test isnan(XRational256(1, 0) * XRational256(0, 1))
    @test XRational256(1, 2) / XRational256(0, 1) == XRational256(1, 0)
    @test isnan(XRational256(0, 1) / XRational256(0, 1))
    @test_throws OverflowError XRational256(int256min, 1)
    @test_throws OverflowError XRational256(1, int256min)
    int256min1 = typemin(Int256) + Int256(1)
    @test XRational256(int256min1, 1) * XRational256(1, 1) == XRational256(int256min1, 1)
    @test XRational256(int256min1, 1) / XRational256(1, 1) == XRational256(int256min1, 1)
    @test -XRational256(int256min1, 1) == XRational256(typemax(Int256), 1)
    @test abs(XRational256(int256min1, 1)) == XRational256(typemax(Int256), 1)
end

@testset "XRational256 ordering and overflow policy" begin
    ninf = XRational256(-1, 0)
    pinf = XRational256(1, 0)
    qnan = XRational256(0, 0)
    one = XRational256(1, 1)
    int256max = typemax(Int256)
    int256min = typemin(Int256)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test XRational256(int256max, 1) + XRational256(1, 1) == pinf
    @test_throws OverflowError XRational256(int256min, 1)
    @test XRational256(int256min + 1, 1) - XRational256(1, 1) == ninf

    @test XRational256(1, int256max) * XRational256(1, int256max) == pinf
    @test XRational256(-1, int256max) * XRational256(1, int256max) == ninf
    @test XRational256(int256max, 1) / XRational256(1, int256max) == pinf
    @test XRational256(int256min + 1, 1) / XRational256(1, int256max) == ninf
end

@testset "XRational256 rational-valued functions" begin
    x = XRational256(7, 3)
    y = XRational256(2, 3)

    @test copysign(x, -1.0) == XRational256(-7, 3)
    @test copysign(XRational256(-7, 3), 2.0) == XRational256(7, 3)
    @test flipsign(x, -1.0) == XRational256(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == XRational256(1, 3)
    @test mod(XRational256(-7, 3), y) == XRational256(1, 3)

    @test isnan(rem(XRational256(1, 0), y))
    @test isnan(mod(XRational256(1, 0), y))
    @test isnan(rem(x, XRational256(0, 1)))
    @test isnan(mod(x, XRational256(0, 1)))

    @test muladd(XRational256(2, 3), XRational256(3, 4), XRational256(1, 2)) == XRational256(1, 1)
    @test fma(XRational256(2, 3), XRational256(3, 4), XRational256(1, 2)) == XRational256(1, 1)
    @test fma(XRational256(1, 0), XRational256(2, 1), XRational256(3, 1)) == XRational256(1, 0)
    @test isnan(fma(XRational256(1, 0), XRational256(-2, 1), XRational256(1, 0)))
    @test isnan(fma(XRational256(0, 1), XRational256(1, 0), XRational256(1, 1)))
    @test fma(XRational256(2, 1), XRational256(3, 1), XRational256(1, 0)) == XRational256(1, 0)
    @test isnan(fma(XRational256(0, 0), XRational256(1, 1), XRational256(2, 1)))

    @test XRational256(2, 3)^3 == XRational256(8, 27)
    @test XRational256(2, 3)^(-2) == XRational256(9, 4)
    @test XRational256(0, 1)^(-1) == XRational256(1, 0)

    @test isinteger(XRational256(4, 1))
    @test !isinteger(XRational256(7, 3))
    @test !isinteger(XRational256(1, 0))

    @test trunc(Int, XRational256(7, 3)) == 2
    @test floor(Int, XRational256(-7, 3)) == -3
    @test ceil(Int, XRational256(-7, 3)) == -2

    @test trunc(XRational256(7, 3)) == XRational256(2, 1)
    @test floor(XRational256(-7, 3)) == XRational256(-3, 1)
    @test ceil(XRational256(-7, 3)) == XRational256(-2, 1)
    @test isnan(trunc(XRational256(1, 0)))

    @test fld(XRational256(7, 3), XRational256(2, 3)) == XRational256(3, 1)
    @test cld(XRational256(7, 3), XRational256(2, 3)) == XRational256(4, 1)
    @test divrem(XRational256(7, 3), XRational256(2, 3)) == (3, XRational256(1, 3))
    @test fldmod(XRational256(-7, 3), XRational256(2, 3)) == (-4, XRational256(1, 3))
    @test fldmod1(XRational256(2, 1), XRational256(1, 1)) == (2, XRational256(1, 1))

    @test_throws DomainError fld(XRational256(1, 0), XRational256(1, 1))
    @test_throws DomainError divrem(XRational256(1, 0), XRational256(1, 1))
end

@testset "XRational256 hashing" begin
    a = XRational256(6, 8)
    b = XRational256(3, 4)
    @test hash(a) == hash(b)
    d = Dict(a => 1)
    d[b] = 2
    @test length(d) == 1
end

println("XRational256 tests passed.")