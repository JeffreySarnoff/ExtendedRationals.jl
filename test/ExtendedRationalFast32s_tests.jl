using Test

include("../src/ExtendedRationalFast32s.jl")
using .ExtendedRationalFast32s

@testset "ExtendedRationalFast32 constructors and predicates" begin
    x = ExtendedRationalFast32(6, -8)
    @test x == ExtendedRationalFast32(-3, 4)

    @test isnan(ExtendedRationalFast32s.NaN(ExtendedRationalFast32))
    @test numerator(ExtendedRationalFast32s.NaN(ExtendedRationalFast32)) == 0
    @test denominator(ExtendedRationalFast32s.NaN(ExtendedRationalFast32)) == 0
    @test ExtendedRationalFast32s.Inf(ExtendedRationalFast32) == ExtendedRationalFast32(1, 0)
    @test isinf(ExtendedRationalFast32s.Inf(ExtendedRationalFast32))
    @test ExtendedRationalFast32s.NegInf(ExtendedRationalFast32) == ExtendedRationalFast32(-1, 0)
    @test isinf(ExtendedRationalFast32s.NegInf(ExtendedRationalFast32))
    @test signbit(ExtendedRationalFast32s.NegInf(ExtendedRationalFast32))

    z = ExtendedRationalFast32(0, 99)
    @test z == ExtendedRationalFast32(0, 1)
    @test iszero(z)

    p = ExtendedRationalFast32(5, 0)
    n = ExtendedRationalFast32(-7, 0)
    qnan = ExtendedRationalFast32(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test ExtendedRationalFast32s.finite(ExtendedRationalFast32(3, 5))
end

@testset "ExtendedRationalFast32 lazy normalization" begin
    # Unnormalized storage: 6//8 stored as-is, but numerator/denominator normalize
    x = ExtendedRationalFast32(6, 8)
    @test numerator(x) == 3
    @test denominator(x) == 4
    # Equality works without normalization (cross-multiply in Int64)
    @test x == ExtendedRationalFast32(3, 4)
    @test x == ExtendedRationalFast32(9, 12)
end

@testset "ExtendedRationalFast32 display and conversion" begin
    @test sprint(show, ExtendedRationalFast32(3, 2)) == "3//2"
    @test sprint(show, ExtendedRationalFast32(1, 0)) == "Inf32f"
    @test sprint(show, ExtendedRationalFast32(-1, 0)) == "-Inf32f"
    @test sprint(show, ExtendedRationalFast32(0, 0)) == "NaN32f"
    # Display normalizes
    @test sprint(show, ExtendedRationalFast32(6, 8)) == "3//4"

    @test convert(Float64, ExtendedRationalFast32(3, 2)) == 1.5
    @test convert(Float64, ExtendedRationalFast32(1, 0)) == Inf
    @test convert(Float64, ExtendedRationalFast32(-1, 0)) == -Inf
    @test isnan(convert(Float64, ExtendedRationalFast32(0, 0)))

    @test_throws InexactError convert(Rational{Int32}, ExtendedRationalFast32(1, 0))
end

@testset "ExtendedRationalFast32 arithmetic" begin
    a = ExtendedRationalFast32(2, 3)
    b = ExtendedRationalFast32(5, 7)
    int32min = typemin(Int32)

    @test a + b == ExtendedRationalFast32(29, 21)
    @test a - b == ExtendedRationalFast32(-1, 21)
    @test a * b == ExtendedRationalFast32(10, 21)
    @test a / b == ExtendedRationalFast32(14, 15)

    @test a + 1 == ExtendedRationalFast32(5, 3)
    @test 1 + a == ExtendedRationalFast32(5, 3)
    @test a * 3 == ExtendedRationalFast32(2, 1)

    @test ExtendedRationalFast32(1, 0) + ExtendedRationalFast32(5, 9) == ExtendedRationalFast32(1, 0)
    @test isnan(ExtendedRationalFast32(1, 0) + ExtendedRationalFast32(-1, 0))
    @test isnan(ExtendedRationalFast32(1, 0) * ExtendedRationalFast32(0, 1))
    @test ExtendedRationalFast32(1, 2) / ExtendedRationalFast32(0, 1) == ExtendedRationalFast32(1, 0)
    @test isnan(ExtendedRationalFast32(0, 1) / ExtendedRationalFast32(0, 1))
    @test_throws OverflowError ExtendedRationalFast32(int32min, 1)
    @test_throws OverflowError ExtendedRationalFast32(1, int32min)
    int32min1 = typemin(Int32) + 1
    @test ExtendedRationalFast32(int32min1, 1) * ExtendedRationalFast32(1, 1) == ExtendedRationalFast32(int32min1, 1)
    @test ExtendedRationalFast32(int32min1, 1) / ExtendedRationalFast32(1, 1) == ExtendedRationalFast32(int32min1, 1)
    @test -ExtendedRationalFast32(int32min1, 1) == ExtendedRationalFast32(typemax(Int32), 1)
    @test abs(ExtendedRationalFast32(int32min1, 1)) == ExtendedRationalFast32(typemax(Int32), 1)
end

@testset "ExtendedRationalFast32 ordering and overflow policy" begin
    ninf = ExtendedRationalFast32(-1, 0)
    pinf = ExtendedRationalFast32(1, 0)
    qnan = ExtendedRationalFast32(0, 0)
    one = ExtendedRationalFast32(1, 1)
    int32max = typemax(Int32)
    int32min = typemin(Int32)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test ExtendedRationalFast32(int32max, 1) + ExtendedRationalFast32(1, 1) == pinf
    @test_throws OverflowError ExtendedRationalFast32(int32min, 1)
    @test ExtendedRationalFast32(int32min + 1, 1) - ExtendedRationalFast32(1, 1) == ninf

    @test ExtendedRationalFast32(1, int32max) * ExtendedRationalFast32(1, int32max) == pinf
    @test ExtendedRationalFast32(-1, int32max) * ExtendedRationalFast32(1, int32max) == ninf
    @test ExtendedRationalFast32(int32max, 1) / ExtendedRationalFast32(1, int32max) == pinf
    @test ExtendedRationalFast32(int32min + 1, 1) / ExtendedRationalFast32(1, int32max) == ninf
end

@testset "ExtendedRationalFast32 rational-valued functions" begin
    x = ExtendedRationalFast32(7, 3)
    y = ExtendedRationalFast32(2, 3)

    @test copysign(x, -1.0) == ExtendedRationalFast32(-7, 3)
    @test copysign(ExtendedRationalFast32(-7, 3), 2.0) == ExtendedRationalFast32(7, 3)
    @test flipsign(x, -1.0) == ExtendedRationalFast32(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == ExtendedRationalFast32(1, 3)
    @test mod(ExtendedRationalFast32(-7, 3), y) == ExtendedRationalFast32(1, 3)

    @test isnan(rem(ExtendedRationalFast32(1, 0), y))
    @test isnan(mod(ExtendedRationalFast32(1, 0), y))
    @test isnan(rem(x, ExtendedRationalFast32(0, 1)))
    @test isnan(mod(x, ExtendedRationalFast32(0, 1)))

    @test muladd(ExtendedRationalFast32(2, 3), ExtendedRationalFast32(3, 4), ExtendedRationalFast32(1, 2)) == ExtendedRationalFast32(1, 1)
    @test fma(ExtendedRationalFast32(2, 3), ExtendedRationalFast32(3, 4), ExtendedRationalFast32(1, 2)) == ExtendedRationalFast32(1, 1)
    @test fma(ExtendedRationalFast32(1, 0), ExtendedRationalFast32(2, 1), ExtendedRationalFast32(3, 1)) == ExtendedRationalFast32(1, 0)
    @test isnan(fma(ExtendedRationalFast32(1, 0), ExtendedRationalFast32(-2, 1), ExtendedRationalFast32(1, 0)))
    @test isnan(fma(ExtendedRationalFast32(0, 1), ExtendedRationalFast32(1, 0), ExtendedRationalFast32(1, 1)))
    @test fma(ExtendedRationalFast32(2, 1), ExtendedRationalFast32(3, 1), ExtendedRationalFast32(1, 0)) == ExtendedRationalFast32(1, 0)
    @test isnan(fma(ExtendedRationalFast32(0, 0), ExtendedRationalFast32(1, 1), ExtendedRationalFast32(2, 1)))

    @test ExtendedRationalFast32(2, 3)^3 == ExtendedRationalFast32(8, 27)
    @test ExtendedRationalFast32(2, 3)^(-2) == ExtendedRationalFast32(9, 4)
    @test ExtendedRationalFast32(0, 1)^(-1) == ExtendedRationalFast32(1, 0)

    @test isinteger(ExtendedRationalFast32(4, 1))
    @test !isinteger(ExtendedRationalFast32(7, 3))
    @test !isinteger(ExtendedRationalFast32(1, 0))

    @test trunc(Int, ExtendedRationalFast32(7, 3)) == 2
    @test floor(Int, ExtendedRationalFast32(-7, 3)) == -3
    @test ceil(Int, ExtendedRationalFast32(-7, 3)) == -2

    @test trunc(ExtendedRationalFast32(7, 3)) == ExtendedRationalFast32(2, 1)
    @test floor(ExtendedRationalFast32(-7, 3)) == ExtendedRationalFast32(-3, 1)
    @test ceil(ExtendedRationalFast32(-7, 3)) == ExtendedRationalFast32(-2, 1)
    @test isnan(trunc(ExtendedRationalFast32(1, 0)))

    @test fld(ExtendedRationalFast32(7, 3), ExtendedRationalFast32(2, 3)) == ExtendedRationalFast32(3, 1)
    @test cld(ExtendedRationalFast32(7, 3), ExtendedRationalFast32(2, 3)) == ExtendedRationalFast32(4, 1)
    @test divrem(ExtendedRationalFast32(7, 3), ExtendedRationalFast32(2, 3)) == (3, ExtendedRationalFast32(1, 3))
    @test fldmod(ExtendedRationalFast32(-7, 3), ExtendedRationalFast32(2, 3)) == (-4, ExtendedRationalFast32(1, 3))
    @test fldmod1(ExtendedRationalFast32(2, 1), ExtendedRationalFast32(1, 1)) == (2, ExtendedRationalFast32(1, 1))

    @test_throws DomainError fld(ExtendedRationalFast32(1, 0), ExtendedRationalFast32(1, 1))
    @test_throws DomainError divrem(ExtendedRationalFast32(1, 0), ExtendedRationalFast32(1, 1))
end

@testset "ExtendedRationalFast32 hashing" begin
    a = ExtendedRationalFast32(6, 8)
    b = ExtendedRationalFast32(3, 4)
    @test hash(a) == hash(b)
    d = Dict(a => 1)
    d[b] = 2
    @test length(d) == 1
end

println("ExtendedRationalFast32 tests passed.")
