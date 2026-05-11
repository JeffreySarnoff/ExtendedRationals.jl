using Test

include("../src/XRational128s.jl")
using .XRational128s

@testset "XRational128 constructors and predicates" begin
    x = XRational128(6, -8)
    @test x == XRational128(-3, 4)

    @test isnan(XRational128s.NaN(XRational128))
    @test numerator(XRational128s.NaN(XRational128)) == 0
    @test denominator(XRational128s.NaN(XRational128)) == 0
    @test XRational128s.Inf(XRational128) == XRational128(1, 0)
    @test isinf(XRational128s.Inf(XRational128))
    @test XRational128s.NegInf(XRational128) == XRational128(-1, 0)
    @test isinf(XRational128s.NegInf(XRational128))
    @test signbit(XRational128s.NegInf(XRational128))

    z = XRational128(0, 99)
    @test z == XRational128(0, 1)
    @test iszero(z)

    p = XRational128(5, 0)
    n = XRational128(-7, 0)
    qnan = XRational128(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test XRational128s.finite(XRational128(3, 5))
end

@testset "XRational128 lazy normalization" begin
    x = XRational128(6, 8)
    @test numerator(x) == 3
    @test denominator(x) == 4
    @test x == XRational128(3, 4)
    @test x == XRational128(9, 12)
end

@testset "XRational128 display and conversion" begin
    @test sprint(show, XRational128(3, 2)) == "3//2"
    @test sprint(show, XRational128(1, 0)) == "InfQ128"
    @test sprint(show, XRational128(-1, 0)) == "-InfQ128"
    @test sprint(show, XRational128(0, 0)) == "NaNQ128"
    @test sprint(show, XRational128(6, 8)) == "3//4"

    @test convert(Float64, XRational128(3, 2)) == 1.5
    @test convert(Float64, XRational128(1, 0)) == Inf
    @test convert(Float64, XRational128(-1, 0)) == -Inf
    @test isnan(convert(Float64, XRational128(0, 0)))

    @test_throws InexactError convert(Rational{Int128}, XRational128(1, 0))
end

@testset "XRational128 arithmetic" begin
    a = XRational128(2, 3)
    b = XRational128(5, 7)
    int128min = typemin(Int128)

    @test a + b == XRational128(29, 21)
    @test a - b == XRational128(-1, 21)
    @test a * b == XRational128(10, 21)
    @test a / b == XRational128(14, 15)

    @test a + 1 == XRational128(5, 3)
    @test 1 + a == XRational128(5, 3)
    @test a * 3 == XRational128(2, 1)

    @test XRational128(1, 0) + XRational128(5, 9) == XRational128(1, 0)
    @test isnan(XRational128(1, 0) + XRational128(-1, 0))
    @test isnan(XRational128(1, 0) * XRational128(0, 1))
    @test XRational128(1, 2) / XRational128(0, 1) == XRational128(1, 0)
    @test isnan(XRational128(0, 1) / XRational128(0, 1))
    @test_throws OverflowError XRational128(int128min, 1)
    @test_throws OverflowError XRational128(1, int128min)
    int128min1 = typemin(Int128) + 1
    @test XRational128(int128min1, 1) * XRational128(1, 1) == XRational128(int128min1, 1)
    @test XRational128(int128min1, 1) / XRational128(1, 1) == XRational128(int128min1, 1)
    @test -XRational128(int128min1, 1) == XRational128(typemax(Int128), 1)
    @test abs(XRational128(int128min1, 1)) == XRational128(typemax(Int128), 1)
end

@testset "XRational128 ordering and overflow policy" begin
    ninf = XRational128(-1, 0)
    pinf = XRational128(1, 0)
    qnan = XRational128(0, 0)
    one = XRational128(1, 1)
    int128max = typemax(Int128)
    int128min = typemin(Int128)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test XRational128(int128max, 1) + XRational128(1, 1) == pinf
    @test_throws OverflowError XRational128(int128min, 1)
    @test XRational128(int128min + 1, 1) - XRational128(1, 1) == ninf

    @test XRational128(1, int128max) * XRational128(1, int128max) == pinf
    @test XRational128(-1, int128max) * XRational128(1, int128max) == ninf
    @test XRational128(int128max, 1) / XRational128(1, int128max) == pinf
    @test XRational128(int128min + 1, 1) / XRational128(1, int128max) == ninf
end

@testset "XRational128 rational-valued functions" begin
    x = XRational128(7, 3)
    y = XRational128(2, 3)

    @test copysign(x, -1.0) == XRational128(-7, 3)
    @test copysign(XRational128(-7, 3), 2.0) == XRational128(7, 3)
    @test flipsign(x, -1.0) == XRational128(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == XRational128(1, 3)
    @test mod(XRational128(-7, 3), y) == XRational128(1, 3)

    @test isnan(rem(XRational128(1, 0), y))
    @test isnan(mod(XRational128(1, 0), y))
    @test isnan(rem(x, XRational128(0, 1)))
    @test isnan(mod(x, XRational128(0, 1)))

    @test muladd(XRational128(2, 3), XRational128(3, 4), XRational128(1, 2)) == XRational128(1, 1)
    @test fma(XRational128(2, 3), XRational128(3, 4), XRational128(1, 2)) == XRational128(1, 1)
    @test fma(XRational128(1, 0), XRational128(2, 1), XRational128(3, 1)) == XRational128(1, 0)
    @test isnan(fma(XRational128(1, 0), XRational128(-2, 1), XRational128(1, 0)))
    @test isnan(fma(XRational128(0, 1), XRational128(1, 0), XRational128(1, 1)))
    @test fma(XRational128(2, 1), XRational128(3, 1), XRational128(1, 0)) == XRational128(1, 0)
    @test isnan(fma(XRational128(0, 0), XRational128(1, 1), XRational128(2, 1)))

    @test XRational128(2, 3)^3 == XRational128(8, 27)
    @test XRational128(2, 3)^(-2) == XRational128(9, 4)
    @test XRational128(0, 1)^(-1) == XRational128(1, 0)

    @test isinteger(XRational128(4, 1))
    @test !isinteger(XRational128(7, 3))
    @test !isinteger(XRational128(1, 0))

    @test trunc(Int, XRational128(7, 3)) == 2
    @test floor(Int, XRational128(-7, 3)) == -3
    @test ceil(Int, XRational128(-7, 3)) == -2

    @test trunc(XRational128(7, 3)) == XRational128(2, 1)
    @test floor(XRational128(-7, 3)) == XRational128(-3, 1)
    @test ceil(XRational128(-7, 3)) == XRational128(-2, 1)
    @test isnan(trunc(XRational128(1, 0)))

    @test fld(XRational128(7, 3), XRational128(2, 3)) == XRational128(3, 1)
    @test cld(XRational128(7, 3), XRational128(2, 3)) == XRational128(4, 1)
    @test divrem(XRational128(7, 3), XRational128(2, 3)) == (3, XRational128(1, 3))
    @test fldmod(XRational128(-7, 3), XRational128(2, 3)) == (-4, XRational128(1, 3))
    @test fldmod1(XRational128(2, 1), XRational128(1, 1)) == (2, XRational128(1, 1))

    @test_throws DomainError fld(XRational128(1, 0), XRational128(1, 1))
    @test_throws DomainError divrem(XRational128(1, 0), XRational128(1, 1))
end

@testset "XRational128 hashing" begin
    a = XRational128(6, 8)
    b = XRational128(3, 4)
    @test hash(a) == hash(b)
    d = Dict(a => 1)
    d[b] = 2
    @test length(d) == 1
end

println("XRational128 tests passed.")