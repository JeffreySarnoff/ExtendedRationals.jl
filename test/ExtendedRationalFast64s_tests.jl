using Test

include("../src/ExtendedRationalFast64s.jl")
using .ExtendedRationalFast64s

@testset "ExtendedRationalFast64 constructors and predicates" begin
    x = ExtendedRationalFast64(6, -8)
    @test x == ExtendedRationalFast64(-3, 4)

    @test isnan(ExtendedRationalFast64s.NaN(ExtendedRationalFast64))
    @test numerator(ExtendedRationalFast64s.NaN(ExtendedRationalFast64)) == 0
    @test denominator(ExtendedRationalFast64s.NaN(ExtendedRationalFast64)) == 0
    @test ExtendedRationalFast64s.Inf(ExtendedRationalFast64) == ExtendedRationalFast64(1, 0)
    @test isinf(ExtendedRationalFast64s.Inf(ExtendedRationalFast64))
    @test ExtendedRationalFast64s.NegInf(ExtendedRationalFast64) == ExtendedRationalFast64(-1, 0)
    @test isinf(ExtendedRationalFast64s.NegInf(ExtendedRationalFast64))
    @test signbit(ExtendedRationalFast64s.NegInf(ExtendedRationalFast64))

    z = ExtendedRationalFast64(0, 99)
    @test z == ExtendedRationalFast64(0, 1)
    @test iszero(z)

    p = ExtendedRationalFast64(5, 0)
    n = ExtendedRationalFast64(-7, 0)
    qnan = ExtendedRationalFast64(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test ExtendedRationalFast64s.finite(ExtendedRationalFast64(3, 5))
end

@testset "ExtendedRationalFast64 lazy normalization" begin
    # Unnormalized storage: 6//8 stored as-is, but numerator/denominator normalize
    x = ExtendedRationalFast64(6, 8)
    @test numerator(x) == 3
    @test denominator(x) == 4
    # Equality works without normalization (cross-multiply)
    @test x == ExtendedRationalFast64(3, 4)
    @test x == ExtendedRationalFast64(9, 12)
end

@testset "ExtendedRationalFast64 display and conversion" begin
    @test sprint(show, ExtendedRationalFast64(3, 2)) == "3//2"
    @test sprint(show, ExtendedRationalFast64(1, 0)) == "Inf64f"
    @test sprint(show, ExtendedRationalFast64(-1, 0)) == "-Inf64f"
    @test sprint(show, ExtendedRationalFast64(0, 0)) == "NaN64f"
    # Display normalizes
    @test sprint(show, ExtendedRationalFast64(6, 8)) == "3//4"

    @test convert(Float64, ExtendedRationalFast64(3, 2)) == 1.5
    @test convert(Float64, ExtendedRationalFast64(1, 0)) == Inf
    @test convert(Float64, ExtendedRationalFast64(-1, 0)) == -Inf
    @test isnan(convert(Float64, ExtendedRationalFast64(0, 0)))

    @test_throws InexactError convert(Rational{Int64}, ExtendedRationalFast64(1, 0))
end

@testset "ExtendedRationalFast64 arithmetic" begin
    a = ExtendedRationalFast64(2, 3)
    b = ExtendedRationalFast64(5, 7)
    int64min = typemin(Int64)

    @test a + b == ExtendedRationalFast64(29, 21)
    @test a - b == ExtendedRationalFast64(-1, 21)
    @test a * b == ExtendedRationalFast64(10, 21)
    @test a / b == ExtendedRationalFast64(14, 15)

    @test a + 1 == ExtendedRationalFast64(5, 3)
    @test 1 + a == ExtendedRationalFast64(5, 3)
    @test a * 3 == ExtendedRationalFast64(2, 1)

    @test ExtendedRationalFast64(1, 0) + ExtendedRationalFast64(5, 9) == ExtendedRationalFast64(1, 0)
    @test isnan(ExtendedRationalFast64(1, 0) + ExtendedRationalFast64(-1, 0))
    @test isnan(ExtendedRationalFast64(1, 0) * ExtendedRationalFast64(0, 1))
    @test ExtendedRationalFast64(1, 2) / ExtendedRationalFast64(0, 1) == ExtendedRationalFast64(1, 0)
    @test isnan(ExtendedRationalFast64(0, 1) / ExtendedRationalFast64(0, 1))
    @test_throws OverflowError ExtendedRationalFast64(int64min, 1)
    @test_throws OverflowError ExtendedRationalFast64(1, int64min)
    int64min1 = typemin(Int64) + 1
    @test ExtendedRationalFast64(int64min1, 1) * ExtendedRationalFast64(1, 1) == ExtendedRationalFast64(int64min1, 1)
    @test ExtendedRationalFast64(int64min1, 1) / ExtendedRationalFast64(1, 1) == ExtendedRationalFast64(int64min1, 1)
    @test -ExtendedRationalFast64(int64min1, 1) == ExtendedRationalFast64(typemax(Int64), 1)
    @test abs(ExtendedRationalFast64(int64min1, 1)) == ExtendedRationalFast64(typemax(Int64), 1)
end

@testset "ExtendedRationalFast64 ordering and overflow policy" begin
    ninf = ExtendedRationalFast64(-1, 0)
    pinf = ExtendedRationalFast64(1, 0)
    qnan = ExtendedRationalFast64(0, 0)
    one = ExtendedRationalFast64(1, 1)
    int64max = typemax(Int64)
    int64min = typemin(Int64)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test ExtendedRationalFast64(int64max, 1) + ExtendedRationalFast64(1, 1) == pinf
    @test_throws OverflowError ExtendedRationalFast64(int64min, 1)
    @test ExtendedRationalFast64(int64min + 1, 1) - ExtendedRationalFast64(1, 1) == ninf

    @test ExtendedRationalFast64(1, int64max) * ExtendedRationalFast64(1, int64max) == pinf
    @test ExtendedRationalFast64(-1, int64max) * ExtendedRationalFast64(1, int64max) == ninf
    @test ExtendedRationalFast64(int64max, 1) / ExtendedRationalFast64(1, int64max) == pinf
    @test ExtendedRationalFast64(int64min + 1, 1) / ExtendedRationalFast64(1, int64max) == ninf
end

@testset "ExtendedRationalFast64 rational-valued functions" begin
    x = ExtendedRationalFast64(7, 3)
    y = ExtendedRationalFast64(2, 3)
    int64max = typemax(Int64)

    @test copysign(x, -1.0) == ExtendedRationalFast64(-7, 3)
    @test copysign(ExtendedRationalFast64(-7, 3), 2.0) == ExtendedRationalFast64(7, 3)
    @test flipsign(x, -1.0) == ExtendedRationalFast64(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == ExtendedRationalFast64(1, 3)
    @test mod(ExtendedRationalFast64(-7, 3), y) == ExtendedRationalFast64(1, 3)

    @test isnan(rem(ExtendedRationalFast64(1, 0), y))
    @test isnan(mod(ExtendedRationalFast64(1, 0), y))
    @test isnan(rem(x, ExtendedRationalFast64(0, 1)))
    @test isnan(mod(x, ExtendedRationalFast64(0, 1)))

    @test muladd(ExtendedRationalFast64(2, 3), ExtendedRationalFast64(3, 4), ExtendedRationalFast64(1, 2)) == ExtendedRationalFast64(1, 1)
    @test fma(ExtendedRationalFast64(2, 3), ExtendedRationalFast64(3, 4), ExtendedRationalFast64(1, 2)) == ExtendedRationalFast64(1, 1)
    @test fma(ExtendedRationalFast64(1, 0), ExtendedRationalFast64(2, 1), ExtendedRationalFast64(3, 1)) == ExtendedRationalFast64(1, 0)
    @test isnan(fma(ExtendedRationalFast64(1, 0), ExtendedRationalFast64(-2, 1), ExtendedRationalFast64(1, 0)))
    @test isnan(fma(ExtendedRationalFast64(0, 1), ExtendedRationalFast64(1, 0), ExtendedRationalFast64(1, 1)))
    @test fma(ExtendedRationalFast64(2, 1), ExtendedRationalFast64(3, 1), ExtendedRationalFast64(1, 0)) == ExtendedRationalFast64(1, 0)
    @test isnan(fma(ExtendedRationalFast64(0, 0), ExtendedRationalFast64(1, 1), ExtendedRationalFast64(2, 1)))

    @test ExtendedRationalFast64(2, 3)^3 == ExtendedRationalFast64(8, 27)
    @test ExtendedRationalFast64(2, 3)^(-2) == ExtendedRationalFast64(9, 4)
    @test ExtendedRationalFast64(0, 1)^(-1) == ExtendedRationalFast64(1, 0)

    @test isinteger(ExtendedRationalFast64(4, 1))
    @test !isinteger(ExtendedRationalFast64(7, 3))
    @test !isinteger(ExtendedRationalFast64(1, 0))

    @test trunc(Int, ExtendedRationalFast64(7, 3)) == 2
    @test floor(Int, ExtendedRationalFast64(-7, 3)) == -3
    @test ceil(Int, ExtendedRationalFast64(-7, 3)) == -2

    @test trunc(ExtendedRationalFast64(7, 3)) == ExtendedRationalFast64(2, 1)
    @test floor(ExtendedRationalFast64(-7, 3)) == ExtendedRationalFast64(-3, 1)
    @test ceil(ExtendedRationalFast64(-7, 3)) == ExtendedRationalFast64(-2, 1)
    @test isnan(trunc(ExtendedRationalFast64(1, 0)))

    @test fld(ExtendedRationalFast64(7, 3), ExtendedRationalFast64(2, 3)) == ExtendedRationalFast64(3, 1)
    @test cld(ExtendedRationalFast64(7, 3), ExtendedRationalFast64(2, 3)) == ExtendedRationalFast64(4, 1)
    @test divrem(ExtendedRationalFast64(7, 3), ExtendedRationalFast64(2, 3)) == (3, ExtendedRationalFast64(1, 3))
    @test fldmod(ExtendedRationalFast64(-7, 3), ExtendedRationalFast64(2, 3)) == (-4, ExtendedRationalFast64(1, 3))
    @test fldmod1(ExtendedRationalFast64(2, 1), ExtendedRationalFast64(1, 1)) == (2, ExtendedRationalFast64(1, 1))

    @test_throws DomainError fld(ExtendedRationalFast64(1, 0), ExtendedRationalFast64(1, 1))
    @test_throws DomainError divrem(ExtendedRationalFast64(1, 0), ExtendedRationalFast64(1, 1))
end

@testset "ExtendedRationalFast64 hashing" begin
    # Normalized-equivalent values must hash identically
    a = ExtendedRationalFast64(6, 8)
    b = ExtendedRationalFast64(3, 4)
    @test hash(a) == hash(b)
    d = Dict(a => 1)
    d[b] = 2
    @test length(d) == 1
end

println("ExtendedRationalFast64 tests passed.")
