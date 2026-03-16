using Test

include("../src/ExtendedRationalInt64s.jl")
using .ExtendedRationalInt64s

@testset "ExtendedRational64 constructors and predicates" begin
    x = ExtendedRational64(6, -8)
    @test x == ExtendedRational64(-3, 4)

    z = ExtendedRational64(0, 99)
    @test z == ExtendedRational64(0, 1)
    @test iszero(z)

    p = ExtendedRational64(5, 0)
    n = ExtendedRational64(-7, 0)
    qnan = ExtendedRational64(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test ExtendedRationalInt64s.finite(ExtendedRational64(3, 5))
end

@testset "ExtendedRational64 display and conversion" begin
    @test sprint(show, ExtendedRational64(3, 2)) == "3//2"
    @test sprint(show, ExtendedRational64(1, 0)) == "Inf64"
    @test sprint(show, ExtendedRational64(-1, 0)) == "-Inf64"
    @test sprint(show, ExtendedRational64(0, 0)) == "NaN64"

    @test convert(Float64, ExtendedRational64(3, 2)) == 1.5
    @test convert(Float64, ExtendedRational64(1, 0)) == Inf
    @test convert(Float64, ExtendedRational64(-1, 0)) == -Inf
    @test isnan(convert(Float64, ExtendedRational64(0, 0)))

    @test_throws InexactError convert(Rational{Int64}, ExtendedRational64(1, 0))
end

@testset "ExtendedRational64 arithmetic" begin
    a = ExtendedRational64(2, 3)
    b = ExtendedRational64(5, 7)
    int64min = typemin(Int64)

    @test a + b == ExtendedRational64(29, 21)
    @test a - b == ExtendedRational64(-1, 21)
    @test a * b == ExtendedRational64(10, 21)
    @test a / b == ExtendedRational64(14, 15)

    @test a + 1 == ExtendedRational64(5, 3)
    @test 1 + a == ExtendedRational64(5, 3)
    @test a * 3 == ExtendedRational64(2, 1)

    @test ExtendedRational64(1, 0) + ExtendedRational64(5, 9) == ExtendedRational64(1, 0)
    @test isnan(ExtendedRational64(1, 0) + ExtendedRational64(-1, 0))
    @test isnan(ExtendedRational64(1, 0) * ExtendedRational64(0, 1))
    @test ExtendedRational64(1, 2) / ExtendedRational64(0, 1) == ExtendedRational64(1, 0)
    @test isnan(ExtendedRational64(0, 1) / ExtendedRational64(0, 1))
    @test ExtendedRational64(int64min, 1) * ExtendedRational64(1, 1) == ExtendedRational64(int64min, 1)
    @test ExtendedRational64(int64min, 1) / ExtendedRational64(1, 1) == ExtendedRational64(int64min, 1)
    @test -ExtendedRational64(int64min, 1) == ExtendedRational64(1, 0)
    @test abs(ExtendedRational64(int64min, 1)) == ExtendedRational64(1, 0)
end

@testset "ExtendedRational64 ordering and overflow policy" begin
    ninf = ExtendedRational64(-1, 0)
    pinf = ExtendedRational64(1, 0)
    qnan = ExtendedRational64(0, 0)
    one = ExtendedRational64(1, 1)
    int64max = typemax(Int64)
    int64min = typemin(Int64)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test ExtendedRational64(int64max, 1) + ExtendedRational64(1, 1) == pinf
    @test ExtendedRational64(int64min, 1) - ExtendedRational64(1, 1) == ninf

    ca = ExtendedRational64(1, 3037000500)
    cb = ExtendedRational64(1, 3037000501)
    @test ca + cb == pinf

    @test ExtendedRational64(1, int64max) * ExtendedRational64(1, int64max) == pinf
    @test ExtendedRational64(-1, int64max) * ExtendedRational64(1, int64max) == ninf
    @test ExtendedRational64(int64max, 1) / ExtendedRational64(1, int64max) == pinf
    @test ExtendedRational64(int64min, 1) / ExtendedRational64(1, int64max) == ninf
end

@testset "ExtendedRational64 rational-valued functions" begin
    x = ExtendedRational64(7, 3)
    y = ExtendedRational64(2, 3)
    int64max = typemax(Int64)

    @test copysign(x, -1.0) == ExtendedRational64(-7, 3)
    @test copysign(ExtendedRational64(-7, 3), 2.0) == ExtendedRational64(7, 3)
    @test flipsign(x, -1.0) == ExtendedRational64(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == ExtendedRational64(1, 3)
    @test mod(ExtendedRational64(-7, 3), y) == ExtendedRational64(1, 3)

    @test isnan(rem(ExtendedRational64(1, 0), y))
    @test isnan(mod(ExtendedRational64(1, 0), y))
    @test isnan(rem(x, ExtendedRational64(0, 1)))
    @test isnan(mod(x, ExtendedRational64(0, 1)))

    @test muladd(ExtendedRational64(2, 3), ExtendedRational64(3, 4), ExtendedRational64(1, 2)) == ExtendedRational64(1, 1)
    @test fma(ExtendedRational64(2, 3), ExtendedRational64(3, 4), ExtendedRational64(1, 2)) == ExtendedRational64(1, 1)
    @test fma(ExtendedRational64(1, int64max), ExtendedRational64(1, int64max), ExtendedRational64(0, 1)) == ExtendedRational64(0, 1)
    @test fma(ExtendedRational64(int64max, 1), ExtendedRational64(2, 1), ExtendedRational64(0, 1)) == ExtendedRational64(int64max, 1)
    @test fma(ExtendedRational64(int64max, 1), ExtendedRational64(1, 1), ExtendedRational64(-1, 2)) == ExtendedRational64(int64max - 1, 1)
    @test fma(ExtendedRational64(1, 0), ExtendedRational64(2, 1), ExtendedRational64(3, 1)) == ExtendedRational64(1, 0)
    @test isnan(fma(ExtendedRational64(1, 0), ExtendedRational64(-2, 1), ExtendedRational64(1, 0)))
    @test isnan(fma(ExtendedRational64(0, 1), ExtendedRational64(1, 0), ExtendedRational64(1, 1)))
    @test fma(ExtendedRational64(2, 1), ExtendedRational64(3, 1), ExtendedRational64(1, 0)) == ExtendedRational64(1, 0)
    @test isnan(fma(ExtendedRational64(0, 0), ExtendedRational64(1, 1), ExtendedRational64(2, 1)))

    @test ExtendedRational64(2, 3)^3 == ExtendedRational64(8, 27)
    @test ExtendedRational64(2, 3)^(-2) == ExtendedRational64(9, 4)
    @test ExtendedRational64(0, 1)^(-1) == ExtendedRational64(1, 0)

    @test isinteger(ExtendedRational64(4, 1))
    @test !isinteger(ExtendedRational64(7, 3))
    @test !isinteger(ExtendedRational64(1, 0))

    @test trunc(Int, ExtendedRational64(7, 3)) == 2
    @test floor(Int, ExtendedRational64(-7, 3)) == -3
    @test ceil(Int, ExtendedRational64(-7, 3)) == -2

    @test trunc(ExtendedRational64(7, 3)) == ExtendedRational64(2, 1)
    @test floor(ExtendedRational64(-7, 3)) == ExtendedRational64(-3, 1)
    @test ceil(ExtendedRational64(-7, 3)) == ExtendedRational64(-2, 1)
    @test isnan(trunc(ExtendedRational64(1, 0)))

    @test fld(ExtendedRational64(7, 3), ExtendedRational64(2, 3)) == ExtendedRational64(3, 1)
    @test cld(ExtendedRational64(7, 3), ExtendedRational64(2, 3)) == ExtendedRational64(4, 1)
    @test divrem(ExtendedRational64(7, 3), ExtendedRational64(2, 3)) == (3, ExtendedRational64(1, 3))
    @test fldmod(ExtendedRational64(-7, 3), ExtendedRational64(2, 3)) == (-4, ExtendedRational64(1, 3))
    @test fldmod1(ExtendedRational64(2, 1), ExtendedRational64(1, 1)) == (2, ExtendedRational64(1, 1))

    @test_throws DomainError fld(ExtendedRational64(1, 0), ExtendedRational64(1, 1))
    @test_throws DomainError divrem(ExtendedRational64(1, 0), ExtendedRational64(1, 1))
end

println("ExtendedRational64 tests passed.")