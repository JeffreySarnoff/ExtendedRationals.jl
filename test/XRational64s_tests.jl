using Test

include("../src/XRational64s.jl")
using .XRational64s

@testset "XRational64 constructors and predicates" begin
    x = XRational64(6, -8)
    @test x == XRational64(-3, 4)

    @test isnan(XRational64s.NaN(XRational64))
    @test numerator(XRational64s.NaN(XRational64)) == 0
    @test denominator(XRational64s.NaN(XRational64)) == 0
    @test XRational64s.Inf(XRational64) == XRational64(1, 0)
    @test isinf(XRational64s.Inf(XRational64))
    @test XRational64s.NegInf(XRational64) == XRational64(-1, 0)
    @test isinf(XRational64s.NegInf(XRational64))
    @test signbit(XRational64s.NegInf(XRational64))

    z = XRational64(0, 99)
    @test z == XRational64(0, 1)
    @test iszero(z)

    p = XRational64(5, 0)
    n = XRational64(-7, 0)
    qnan = XRational64(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test XRational64s.finite(XRational64(3, 5))
end

@testset "XRational64 lazy normalization" begin
    # Unnormalized storage: 6//8 stored as-is, but numerator/denominator normalize
    x = XRational64(6, 8)
    @test numerator(x) == 3
    @test denominator(x) == 4
    # Equality works without normalization (cross-multiply)
    @test x == XRational64(3, 4)
    @test x == XRational64(9, 12)
end

@testset "XRational64 display and conversion" begin
    @test sprint(show, XRational64(3, 2)) == "3//2"
    @test sprint(show, XRational64(1, 0)) == "Inf64f"
    @test sprint(show, XRational64(-1, 0)) == "-Inf64f"
    @test sprint(show, XRational64(0, 0)) == "NaNQ64"
    # Display normalizes
    @test sprint(show, XRational64(6, 8)) == "3//4"

    @test convert(Float64, XRational64(3, 2)) == 1.5
    @test convert(Float64, XRational64(1, 0)) == Inf
    @test convert(Float64, XRational64(-1, 0)) == -Inf
    @test isnan(convert(Float64, XRational64(0, 0)))

    @test_throws InexactError convert(Rational{Int64}, XRational64(1, 0))
end

@testset "XRational64 arithmetic" begin
    a = XRational64(2, 3)
    b = XRational64(5, 7)
    int64min = typemin(Int64)

    @test a + b == XRational64(29, 21)
    @test a - b == XRational64(-1, 21)
    @test a * b == XRational64(10, 21)
    @test a / b == XRational64(14, 15)

    @test a + 1 == XRational64(5, 3)
    @test 1 + a == XRational64(5, 3)
    @test a * 3 == XRational64(2, 1)

    @test XRational64(1, 0) + XRational64(5, 9) == XRational64(1, 0)
    @test isnan(XRational64(1, 0) + XRational64(-1, 0))
    @test isnan(XRational64(1, 0) * XRational64(0, 1))
    @test XRational64(1, 2) / XRational64(0, 1) == XRational64(1, 0)
    @test isnan(XRational64(0, 1) / XRational64(0, 1))
    @test_throws OverflowError XRational64(int64min, 1)
    @test_throws OverflowError XRational64(1, int64min)
    int64min1 = typemin(Int64) + 1
    @test XRational64(int64min1, 1) * XRational64(1, 1) == XRational64(int64min1, 1)
    @test XRational64(int64min1, 1) / XRational64(1, 1) == XRational64(int64min1, 1)
    @test -XRational64(int64min1, 1) == XRational64(typemax(Int64), 1)
    @test abs(XRational64(int64min1, 1)) == XRational64(typemax(Int64), 1)
end

@testset "XRational64 ordering and overflow policy" begin
    ninf = XRational64(-1, 0)
    pinf = XRational64(1, 0)
    qnan = XRational64(0, 0)
    one = XRational64(1, 1)
    int64max = typemax(Int64)
    int64min = typemin(Int64)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test XRational64(int64max, 1) + XRational64(1, 1) == pinf
    @test_throws OverflowError XRational64(int64min, 1)
    @test XRational64(int64min + 1, 1) - XRational64(1, 1) == ninf

    @test XRational64(1, int64max) * XRational64(1, int64max) == pinf
    @test XRational64(-1, int64max) * XRational64(1, int64max) == ninf
    @test XRational64(int64max, 1) / XRational64(1, int64max) == pinf
    @test XRational64(int64min + 1, 1) / XRational64(1, int64max) == ninf
end

@testset "XRational64 rational-valued functions" begin
    x = XRational64(7, 3)
    y = XRational64(2, 3)
    int64max = typemax(Int64)

    @test copysign(x, -1.0) == XRational64(-7, 3)
    @test copysign(XRational64(-7, 3), 2.0) == XRational64(7, 3)
    @test flipsign(x, -1.0) == XRational64(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == XRational64(1, 3)
    @test mod(XRational64(-7, 3), y) == XRational64(1, 3)

    @test isnan(rem(XRational64(1, 0), y))
    @test isnan(mod(XRational64(1, 0), y))
    @test isnan(rem(x, XRational64(0, 1)))
    @test isnan(mod(x, XRational64(0, 1)))

    @test muladd(XRational64(2, 3), XRational64(3, 4), XRational64(1, 2)) == XRational64(1, 1)
    @test fma(XRational64(2, 3), XRational64(3, 4), XRational64(1, 2)) == XRational64(1, 1)
    @test fma(XRational64(1, 0), XRational64(2, 1), XRational64(3, 1)) == XRational64(1, 0)
    @test isnan(fma(XRational64(1, 0), XRational64(-2, 1), XRational64(1, 0)))
    @test isnan(fma(XRational64(0, 1), XRational64(1, 0), XRational64(1, 1)))
    @test fma(XRational64(2, 1), XRational64(3, 1), XRational64(1, 0)) == XRational64(1, 0)
    @test isnan(fma(XRational64(0, 0), XRational64(1, 1), XRational64(2, 1)))

    @test XRational64(2, 3)^3 == XRational64(8, 27)
    @test XRational64(2, 3)^(-2) == XRational64(9, 4)
    @test XRational64(0, 1)^(-1) == XRational64(1, 0)

    @test isinteger(XRational64(4, 1))
    @test !isinteger(XRational64(7, 3))
    @test !isinteger(XRational64(1, 0))

    @test trunc(Int, XRational64(7, 3)) == 2
    @test floor(Int, XRational64(-7, 3)) == -3
    @test ceil(Int, XRational64(-7, 3)) == -2

    @test trunc(XRational64(7, 3)) == XRational64(2, 1)
    @test floor(XRational64(-7, 3)) == XRational64(-3, 1)
    @test ceil(XRational64(-7, 3)) == XRational64(-2, 1)
    @test isnan(trunc(XRational64(1, 0)))

    @test fld(XRational64(7, 3), XRational64(2, 3)) == XRational64(3, 1)
    @test cld(XRational64(7, 3), XRational64(2, 3)) == XRational64(4, 1)
    @test divrem(XRational64(7, 3), XRational64(2, 3)) == (3, XRational64(1, 3))
    @test fldmod(XRational64(-7, 3), XRational64(2, 3)) == (-4, XRational64(1, 3))
    @test fldmod1(XRational64(2, 1), XRational64(1, 1)) == (2, XRational64(1, 1))

    @test_throws DomainError fld(XRational64(1, 0), XRational64(1, 1))
    @test_throws DomainError divrem(XRational64(1, 0), XRational64(1, 1))
end

@testset "XRational64 hashing" begin
    # Normalized-equivalent values must hash identically
    a = XRational64(6, 8)
    b = XRational64(3, 4)
    @test hash(a) == hash(b)
    d = Dict(a => 1)
    d[b] = 2
    @test length(d) == 1
end

println("XRational64 tests passed.")
