using Test
using BitIntegers: Int512

include("../src/XRational512s.jl")
using .XRational512s

@testset "XRational512 constructors and predicates" begin
    x = XRational512(6, -8)
    @test x == XRational512(-3, 4)

    @test isnan(XRational512s.NaN(XRational512))
    @test numerator(XRational512s.NaN(XRational512)) == 0
    @test denominator(XRational512s.NaN(XRational512)) == 0
    @test XRational512s.Inf(XRational512) == XRational512(1, 0)
    @test isinf(XRational512s.Inf(XRational512))
    @test XRational512s.NegInf(XRational512) == XRational512(-1, 0)
    @test isinf(XRational512s.NegInf(XRational512))
    @test signbit(XRational512s.NegInf(XRational512))

    z = XRational512(0, 99)
    @test z == XRational512(0, 1)
    @test iszero(z)

    p = XRational512(5, 0)
    n = XRational512(-7, 0)
    qnan = XRational512(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test XRational512s.finite(XRational512(3, 5))
end

@testset "XRational512 lazy normalization" begin
    x = XRational512(6, 8)
    @test numerator(x) == 3
    @test denominator(x) == 4
    @test x == XRational512(3, 4)
    @test x == XRational512(9, 12)
end

@testset "XRational512 display and conversion" begin
    @test sprint(show, XRational512(3, 2)) == "3//2"
    @test sprint(show, XRational512(1, 0)) == "InfQ512"
    @test sprint(show, XRational512(-1, 0)) == "-InfQ512"
    @test sprint(show, XRational512(0, 0)) == "NaNQ512"
    @test sprint(show, XRational512(6, 8)) == "3//4"

    @test convert(Float64, XRational512(3, 2)) == 1.5
    @test convert(Float64, XRational512(1, 0)) == Inf
    @test convert(Float64, XRational512(-1, 0)) == -Inf
    @test isnan(convert(Float64, XRational512(0, 0)))

    @test_throws InexactError convert(Rational{Int512}, XRational512(1, 0))
end

@testset "XRational512 arithmetic" begin
    a = XRational512(2, 3)
    b = XRational512(5, 7)
    int512min = typemin(Int512)

    @test a + b == XRational512(29, 21)
    @test a - b == XRational512(-1, 21)
    @test a * b == XRational512(10, 21)
    @test a / b == XRational512(14, 15)

    @test a + 1 == XRational512(5, 3)
    @test 1 + a == XRational512(5, 3)
    @test a * 3 == XRational512(2, 1)

    @test XRational512(1, 0) + XRational512(5, 9) == XRational512(1, 0)
    @test isnan(XRational512(1, 0) + XRational512(-1, 0))
    @test isnan(XRational512(1, 0) * XRational512(0, 1))
    @test XRational512(1, 2) / XRational512(0, 1) == XRational512(1, 0)
    @test isnan(XRational512(0, 1) / XRational512(0, 1))
    @test_throws OverflowError XRational512(int512min, 1)
    @test_throws OverflowError XRational512(1, int512min)
    int512min1 = typemin(Int512) + Int512(1)
    @test XRational512(int512min1, 1) * XRational512(1, 1) == XRational512(int512min1, 1)
    @test XRational512(int512min1, 1) / XRational512(1, 1) == XRational512(int512min1, 1)
    @test -XRational512(int512min1, 1) == XRational512(typemax(Int512), 1)
    @test abs(XRational512(int512min1, 1)) == XRational512(typemax(Int512), 1)
end

@testset "XRational512 ordering and overflow policy" begin
    ninf = XRational512(-1, 0)
    pinf = XRational512(1, 0)
    qnan = XRational512(0, 0)
    one = XRational512(1, 1)
    int512max = typemax(Int512)
    int512min = typemin(Int512)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test XRational512(int512max, 1) + XRational512(1, 1) == pinf
    @test_throws OverflowError XRational512(int512min, 1)
    @test XRational512(int512min + 1, 1) - XRational512(1, 1) == ninf

    @test XRational512(1, int512max) * XRational512(1, int512max) == pinf
    @test XRational512(-1, int512max) * XRational512(1, int512max) == ninf
    @test XRational512(int512max, 1) / XRational512(1, int512max) == pinf
    @test XRational512(int512min + 1, 1) / XRational512(1, int512max) == ninf
end

@testset "XRational512 rational-valued functions" begin
    x = XRational512(7, 3)
    y = XRational512(2, 3)

    @test copysign(x, -1.0) == XRational512(-7, 3)
    @test copysign(XRational512(-7, 3), 2.0) == XRational512(7, 3)
    @test flipsign(x, -1.0) == XRational512(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == XRational512(1, 3)
    @test mod(XRational512(-7, 3), y) == XRational512(1, 3)

    @test isnan(rem(XRational512(1, 0), y))
    @test isnan(mod(XRational512(1, 0), y))
    @test isnan(rem(x, XRational512(0, 1)))
    @test isnan(mod(x, XRational512(0, 1)))

    @test muladd(XRational512(2, 3), XRational512(3, 4), XRational512(1, 2)) == XRational512(1, 1)
    @test fma(XRational512(2, 3), XRational512(3, 4), XRational512(1, 2)) == XRational512(1, 1)
    @test fma(XRational512(1, 0), XRational512(2, 1), XRational512(3, 1)) == XRational512(1, 0)
    @test isnan(fma(XRational512(1, 0), XRational512(-2, 1), XRational512(1, 0)))
    @test isnan(fma(XRational512(0, 1), XRational512(1, 0), XRational512(1, 1)))
    @test fma(XRational512(2, 1), XRational512(3, 1), XRational512(1, 0)) == XRational512(1, 0)
    @test isnan(fma(XRational512(0, 0), XRational512(1, 1), XRational512(2, 1)))

    @test XRational512(2, 3)^3 == XRational512(8, 27)
    @test XRational512(2, 3)^(-2) == XRational512(9, 4)
    @test XRational512(0, 1)^(-1) == XRational512(1, 0)

    @test isinteger(XRational512(4, 1))
    @test !isinteger(XRational512(7, 3))
    @test !isinteger(XRational512(1, 0))

    @test trunc(Int, XRational512(7, 3)) == 2
    @test floor(Int, XRational512(-7, 3)) == -3
    @test ceil(Int, XRational512(-7, 3)) == -2

    @test trunc(XRational512(7, 3)) == XRational512(2, 1)
    @test floor(XRational512(-7, 3)) == XRational512(-3, 1)
    @test ceil(XRational512(-7, 3)) == XRational512(-2, 1)
    @test isnan(trunc(XRational512(1, 0)))

    @test fld(XRational512(7, 3), XRational512(2, 3)) == XRational512(3, 1)
    @test cld(XRational512(7, 3), XRational512(2, 3)) == XRational512(4, 1)
    @test divrem(XRational512(7, 3), XRational512(2, 3)) == (3, XRational512(1, 3))
    @test fldmod(XRational512(-7, 3), XRational512(2, 3)) == (-4, XRational512(1, 3))
    @test fldmod1(XRational512(2, 1), XRational512(1, 1)) == (2, XRational512(1, 1))

    @test_throws DomainError fld(XRational512(1, 0), XRational512(1, 1))
    @test_throws DomainError divrem(XRational512(1, 0), XRational512(1, 1))
end

@testset "XRational512 hashing" begin
    a = XRational512(6, 8)
    b = XRational512(3, 4)
    @test hash(a) == hash(b)
    d = Dict(a => 1)
    d[b] = 2
    @test length(d) == 1
end

println("XRational512 tests passed.")