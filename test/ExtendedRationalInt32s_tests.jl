using Test

include("../src/ExtendedRationalInt32s.jl")
using .ExtendedRationalInt32s

@testset "ExtendedRational32 constructors and predicates" begin
    x = ExtendedRational32(6, -8)
    @test x == ExtendedRational32(-3, 4)

    z = ExtendedRational32(0, 99)
    @test z == ExtendedRational32(0, 1)
    @test iszero(z)

    p = ExtendedRational32(5, 0)
    n = ExtendedRational32(-7, 0)
    qnan = ExtendedRational32(0, 0)

    @test isinf(p)
    @test isinf(n)
    @test isnan(qnan)
    @test !isfinite(p)
    @test !isfinite(qnan)
    @test finite(ExtendedRational32(3, 5))
end

@testset "ExtendedRational32 display and conversion" begin
    @test sprint(show, ExtendedRational32(3, 2)) == "3//2"
    @test sprint(show, ExtendedRational32(1, 0)) == "Inf32"
    @test sprint(show, ExtendedRational32(-1, 0)) == "-Inf32"
    @test sprint(show, ExtendedRational32(0, 0)) == "NaN32"

    @test convert(Float64, ExtendedRational32(3, 2)) == 1.5
    @test convert(Float64, ExtendedRational32(1, 0)) == Inf
    @test convert(Float64, ExtendedRational32(-1, 0)) == -Inf
    @test isnan(convert(Float64, ExtendedRational32(0, 0)))

    @test_throws InexactError convert(Rational{Int32}, ExtendedRational32(1, 0))
end

@testset "ExtendedRational32 arithmetic" begin
    a = ExtendedRational32(2, 3)
    b = ExtendedRational32(5, 7)

    @test a + b == ExtendedRational32(29, 21)
    @test a - b == ExtendedRational32(-1, 21)
    @test a * b == ExtendedRational32(10, 21)
    @test a / b == ExtendedRational32(14, 15)

    @test a + 1 == ExtendedRational32(5, 3)
    @test 1 + a == ExtendedRational32(5, 3)
    @test a * 3 == ExtendedRational32(2, 1)

    @test ExtendedRational32(1, 0) + ExtendedRational32(5, 9) == ExtendedRational32(1, 0)
    @test isnan(ExtendedRational32(1, 0) + ExtendedRational32(-1, 0))
    @test isnan(ExtendedRational32(1, 0) * ExtendedRational32(0, 1))
    @test ExtendedRational32(1, 2) / ExtendedRational32(0, 1) == ExtendedRational32(1, 0)
    @test isnan(ExtendedRational32(0, 1) / ExtendedRational32(0, 1))
end

@testset "ExtendedRational32 ordering and overflow" begin
    ninf = ExtendedRational32(-1, 0)
    pinf = ExtendedRational32(1, 0)
    qnan = ExtendedRational32(0, 0)
    one = ExtendedRational32(1, 1)

    @test ninf < one
    @test one < pinf
    @test !(qnan < one)
    @test !(one < qnan)
    @test ninf <= ninf
    @test pinf >= one

    @test_throws OverflowError ExtendedRational32(typemax(Int32), 1) + ExtendedRational32(1, 1)
end

@testset "ExtendedRational32 rational-valued functions" begin
    x = ExtendedRational32(7, 3)
    y = ExtendedRational32(2, 3)
    int32max = typemax(Int32)

    @test copysign(x, -1.0) == ExtendedRational32(-7, 3)
    @test copysign(ExtendedRational32(-7, 3), 2.0) == ExtendedRational32(7, 3)
    @test flipsign(x, -1.0) == ExtendedRational32(-7, 3)
    @test flipsign(x, 1.0) == x

    @test rem(x, y) == ExtendedRational32(1, 3)
    @test mod(ExtendedRational32(-7, 3), y) == ExtendedRational32(1, 3)

    @test isnan(rem(ExtendedRational32(1, 0), y))
    @test isnan(mod(ExtendedRational32(1, 0), y))
    @test isnan(rem(x, ExtendedRational32(0, 1)))
    @test isnan(mod(x, ExtendedRational32(0, 1)))

    @test muladd(ExtendedRational32(2, 3), ExtendedRational32(3, 4), ExtendedRational32(1, 2)) == ExtendedRational32(1, 1)
    @test fma(ExtendedRational32(2, 3), ExtendedRational32(3, 4), ExtendedRational32(1, 2)) == ExtendedRational32(1, 1)
    @test fma(ExtendedRational32(1, int32max), ExtendedRational32(1, int32max), ExtendedRational32(0, 1)) == ExtendedRational32(0, 1)
    @test fma(ExtendedRational32(int32max, 1), ExtendedRational32(2, 1), ExtendedRational32(0, 1)) == ExtendedRational32(int32max, 1)
    @test fma(ExtendedRational32(int32max, 1), ExtendedRational32(1, 1), ExtendedRational32(-1, 2)) == ExtendedRational32(int32max - 1, 1)
    @test fma(ExtendedRational32(1, 0), ExtendedRational32(2, 1), ExtendedRational32(3, 1)) == ExtendedRational32(1, 0)
    @test isnan(fma(ExtendedRational32(1, 0), ExtendedRational32(-2, 1), ExtendedRational32(1, 0)))
    @test isnan(fma(ExtendedRational32(0, 1), ExtendedRational32(1, 0), ExtendedRational32(1, 1)))
    @test fma(ExtendedRational32(2, 1), ExtendedRational32(3, 1), ExtendedRational32(1, 0)) == ExtendedRational32(1, 0)
    @test isnan(fma(ExtendedRational32(0, 0), ExtendedRational32(1, 1), ExtendedRational32(2, 1)))

    @test ExtendedRational32(2, 3)^3 == ExtendedRational32(8, 27)
    @test ExtendedRational32(2, 3)^(-2) == ExtendedRational32(9, 4)
    @test ExtendedRational32(0, 1)^(-1) == ExtendedRational32(1, 0)

    @test isinteger(ExtendedRational32(4, 1))
    @test !isinteger(ExtendedRational32(7, 3))
    @test !isinteger(ExtendedRational32(1, 0))

    @test trunc(Int, ExtendedRational32(7, 3)) == 2
    @test floor(Int, ExtendedRational32(-7, 3)) == -3
    @test ceil(Int, ExtendedRational32(-7, 3)) == -2

    @test trunc(ExtendedRational32(7, 3)) == ExtendedRational32(2, 1)
    @test floor(ExtendedRational32(-7, 3)) == ExtendedRational32(-3, 1)
    @test ceil(ExtendedRational32(-7, 3)) == ExtendedRational32(-2, 1)
    @test isnan(trunc(ExtendedRational32(1, 0)))

    @test fld(ExtendedRational32(7, 3), ExtendedRational32(2, 3)) == ExtendedRational32(3, 1)
    @test cld(ExtendedRational32(7, 3), ExtendedRational32(2, 3)) == ExtendedRational32(4, 1)
    @test divrem(ExtendedRational32(7, 3), ExtendedRational32(2, 3)) == (3, ExtendedRational32(1, 3))
    @test fldmod(ExtendedRational32(-7, 3), ExtendedRational32(2, 3)) == (-4, ExtendedRational32(1, 3))
    @test fldmod1(ExtendedRational32(2, 1), ExtendedRational32(1, 1)) == (2, ExtendedRational32(1, 1))

    @test_throws DomainError fld(ExtendedRational32(1, 0), ExtendedRational32(1, 1))
    @test_throws DomainError divrem(ExtendedRational32(1, 0), ExtendedRational32(1, 1))
end

println("ExtendedRational32 tests passed.")