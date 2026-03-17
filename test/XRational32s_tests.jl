using Test

include("../src/XRational32s.jl")
using .XRational32s

@testset "XRational32 constructors and predicates" begin
    x = XRational32(6, -8)
    @test x == XRational32(-3, 4)

    @test isnan(XRational32s.NaN(XRational32))
    @test numerator(XRational32s.NaN(XRational32)) == 0
    @test denominator(XRational32s.NaN(XRational32)) == 0
    @test XRational32s.Inf(XRational32) == XRational32(1, 0)
    @test isinf(XRational32s.Inf(XRational32))
    @test XRational32s.NegInf(XRational32) == XRational32(-1, 0)
    @test isinf(XRational32s.NegInf(XRational32))
    @test signbit(XRational32s.NegInf(XRational32))

    z = XRational32(0, 99)
    @test z == XRational32(0, 1)
    @test iszero(z)

    p = XRational32(5, 0)
    n = XRational32(-7, 0)
    qnan = XRational32(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test XRational32s.finite(XRational32(3, 5))
end

@testset "XRational32 lazy normalization" begin
    # Unnormalized storage: 6//8 stored as-is, but numerator/denominator normalize
    x = XRational32(6, 8)
    @test numerator(x) == 3
    @test denominator(x) == 4
    # Equality works without normalization (cross-multiply in Int64)
    @test x == XRational32(3, 4)
    @test x == XRational32(9, 12)
end

@testset "XRational32 display and conversion" begin
    @test sprint(show, XRational32(3, 2)) == "3//2"
    @test sprint(show, XRational32(1, 0)) == "Inf32f"
    @test sprint(show, XRational32(-1, 0)) == "-Inf32f"
    @test sprint(show, XRational32(0, 0)) == "NaNQ32"
    # Display normalizes
    @test sprint(show, XRational32(6, 8)) == "3//4"

    @test convert(Float64, XRational32(3, 2)) == 1.5
    @test convert(Float64, XRational32(1, 0)) == Inf
    @test convert(Float64, XRational32(-1, 0)) == -Inf
    @test isnan(convert(Float64, XRational32(0, 0)))

    @test_throws InexactError convert(Rational{Int32}, XRational32(1, 0))
end

@testset "XRational32 arithmetic" begin
    a = XRational32(2, 3)
    b = XRational32(5, 7)
    int32min = typemin(Int32)

    @test a + b == XRational32(29, 21)
    @test a - b == XRational32(-1, 21)
    @test a * b == XRational32(10, 21)
    @test a / b == XRational32(14, 15)

    @test a + 1 == XRational32(5, 3)
    @test 1 + a == XRational32(5, 3)
    @test a * 3 == XRational32(2, 1)

    @test XRational32(1, 0) + XRational32(5, 9) == XRational32(1, 0)
    @test isnan(XRational32(1, 0) + XRational32(-1, 0))
    @test isnan(XRational32(1, 0) * XRational32(0, 1))
    @test XRational32(1, 2) / XRational32(0, 1) == XRational32(1, 0)
    @test isnan(XRational32(0, 1) / XRational32(0, 1))
    @test_throws OverflowError XRational32(int32min, 1)
    @test_throws OverflowError XRational32(1, int32min)
    int32min1 = typemin(Int32) + 1
    @test XRational32(int32min1, 1) * XRational32(1, 1) == XRational32(int32min1, 1)
    @test XRational32(int32min1, 1) / XRational32(1, 1) == XRational32(int32min1, 1)
    @test -XRational32(int32min1, 1) == XRational32(typemax(Int32), 1)
    @test abs(XRational32(int32min1, 1)) == XRational32(typemax(Int32), 1)
end

@testset "XRational32 ordering and overflow policy" begin
    ninf = XRational32(-1, 0)
    pinf = XRational32(1, 0)
    qnan = XRational32(0, 0)
    one = XRational32(1, 1)
    int32max = typemax(Int32)
    int32min = typemin(Int32)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test XRational32(int32max, 1) + XRational32(1, 1) == pinf
    @test_throws OverflowError XRational32(int32min, 1)
    @test XRational32(int32min + 1, 1) - XRational32(1, 1) == ninf

    @test XRational32(1, int32max) * XRational32(1, int32max) == pinf
    @test XRational32(-1, int32max) * XRational32(1, int32max) == ninf
    @test XRational32(int32max, 1) / XRational32(1, int32max) == pinf
    @test XRational32(int32min + 1, 1) / XRational32(1, int32max) == ninf
end

@testset "XRational32 rational-valued functions" begin
    x = XRational32(7, 3)
    y = XRational32(2, 3)

    @test copysign(x, -1.0) == XRational32(-7, 3)
    @test copysign(XRational32(-7, 3), 2.0) == XRational32(7, 3)
    @test flipsign(x, -1.0) == XRational32(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == XRational32(1, 3)
    @test mod(XRational32(-7, 3), y) == XRational32(1, 3)

    @test isnan(rem(XRational32(1, 0), y))
    @test isnan(mod(XRational32(1, 0), y))
    @test isnan(rem(x, XRational32(0, 1)))
    @test isnan(mod(x, XRational32(0, 1)))

    @test muladd(XRational32(2, 3), XRational32(3, 4), XRational32(1, 2)) == XRational32(1, 1)
    @test fma(XRational32(2, 3), XRational32(3, 4), XRational32(1, 2)) == XRational32(1, 1)
    @test fma(XRational32(1, 0), XRational32(2, 1), XRational32(3, 1)) == XRational32(1, 0)
    @test isnan(fma(XRational32(1, 0), XRational32(-2, 1), XRational32(1, 0)))
    @test isnan(fma(XRational32(0, 1), XRational32(1, 0), XRational32(1, 1)))
    @test fma(XRational32(2, 1), XRational32(3, 1), XRational32(1, 0)) == XRational32(1, 0)
    @test isnan(fma(XRational32(0, 0), XRational32(1, 1), XRational32(2, 1)))

    @test XRational32(2, 3)^3 == XRational32(8, 27)
    @test XRational32(2, 3)^(-2) == XRational32(9, 4)
    @test XRational32(0, 1)^(-1) == XRational32(1, 0)

    @test isinteger(XRational32(4, 1))
    @test !isinteger(XRational32(7, 3))
    @test !isinteger(XRational32(1, 0))

    @test trunc(Int, XRational32(7, 3)) == 2
    @test floor(Int, XRational32(-7, 3)) == -3
    @test ceil(Int, XRational32(-7, 3)) == -2

    @test trunc(XRational32(7, 3)) == XRational32(2, 1)
    @test floor(XRational32(-7, 3)) == XRational32(-3, 1)
    @test ceil(XRational32(-7, 3)) == XRational32(-2, 1)
    @test isnan(trunc(XRational32(1, 0)))

    @test fld(XRational32(7, 3), XRational32(2, 3)) == XRational32(3, 1)
    @test cld(XRational32(7, 3), XRational32(2, 3)) == XRational32(4, 1)
    @test divrem(XRational32(7, 3), XRational32(2, 3)) == (3, XRational32(1, 3))
    @test fldmod(XRational32(-7, 3), XRational32(2, 3)) == (-4, XRational32(1, 3))
    @test fldmod1(XRational32(2, 1), XRational32(1, 1)) == (2, XRational32(1, 1))

    @test_throws DomainError fld(XRational32(1, 0), XRational32(1, 1))
    @test_throws DomainError divrem(XRational32(1, 0), XRational32(1, 1))
end

@testset "XRational32 hashing" begin
    a = XRational32(6, 8)
    b = XRational32(3, 4)
    @test hash(a) == hash(b)
    d = Dict(a => 1)
    d[b] = 2
    @test length(d) == 1
end

println("XRational32 tests passed.")
