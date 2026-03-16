module ExtendedRationalInt32s

include("RationalInt32s.jl")
using .RationalInt32s: Rational32

#===
Public type and canonical representation
===#

"""
    ExtendedRational32 <: Real

An `Int32`-backed rational type extended with IEEE-like special values using the
following compact encodings:

- `0//0`   => `NaN`
- `1//0`   => `Inf`
- `-1//0`  => `-Inf`
- `n//d` with `d > 0` => finite normalized rational value

Finite values are stored canonically:

- `den > 0`
- `gcd(abs(num), den) == 1`
- zero is stored as `0//1`

Arithmetic on finite values is exact when the result fits in `Int32`; otherwise
a policy value is returned: `Inf32`, `-Inf32`, or `NaN32` as appropriate.
"""
struct ExtendedRational32 <: Real
    num::Int32
    den::Int32

    ExtendedRational32(num::Int32, den::Int32, ::Val{:canonical}) = new(num, den)

    function ExtendedRational32(num::Integer, den::Integer)
        if den == 0
            if num == 0
                return new(Int32(0), Int32(0))
            elseif num > 0
                return new(Int32(1), Int32(0))
            else
                return new(Int32(-1), Int32(0))
            end
        end

        if den < 0
            num = -num
            den = -den
        end

        if num == 0
            return new(Int32(0), Int32(1))
        end

        g = gcd(num, den)
        n = div(num, g)
        d = div(den, g)

        typemin(Int32) <= n <= typemax(Int32) || throw(OverflowError("numerator does not fit in Int32"))
        typemin(Int32) <= d <= typemax(Int32) || throw(OverflowError("denominator does not fit in Int32"))

        return new(Int32(n), Int32(d))
    end
end

const ℚx32 = ExtendedRational32

ExtendedRational32(n::Integer) = ExtendedRational32(n, 1)
ExtendedRational32(x::Rational32) = ExtendedRational32(x.num, x.den)
ExtendedRational32(x::Rational{<:Integer}) = ExtendedRational32(numerator(x), denominator(x))

function ExtendedRational32(x::AbstractFloat)
    isnan(x) && return Qx32(0, 0)
    isinf(x) && return x > 0 ? Qx32(1, 0) : Qx32(-1, 0)
    r = rationalize(Int32, x)
    Qx32(r.num, r.den)
end

#===
Predicates and basic properties
===#

finite(x::ExtendedRational32) = x.den != 0
Base.isfinite(x::ExtendedRational32) = x.den != 0
Base.isinf(x::ExtendedRational32) = x.den == 0 && x.num != 0
Base.isnan(x::ExtendedRational32) = x.den == 0 && x.num == 0
Base.iszero(x::ExtendedRational32) = x.den != 0 && x.num == 0
Base.isone(x::ExtendedRational32) = x.den == 1 && x.num == 1
Base.isinteger(x::ExtendedRational32) = isfinite(x) && x.den == 1
Base.signbit(x::ExtendedRational32) = x.num < 0
Base.sign(x::ExtendedRational32) = isnan(x) ? x : (iszero(x) ? zero(x) : ExtendedRational32(sign(x.num), 1))

Base.zero(::Type{ExtendedRational32}) = ExtendedRational32(0, 1)
Base.zero(::ExtendedRational32) = ExtendedRational32(0, 1)
Base.one(::Type{ExtendedRational32}) = ExtendedRational32(1, 1)
Base.one(::ExtendedRational32) = ExtendedRational32(1, 1)
Base.typemin(::Type{ExtendedRational32}) = ExtendedRational32(-1, 0)
Base.typemax(::Type{ExtendedRational32}) = ExtendedRational32(1, 0)

Base.numerator(x::ExtendedRational32) = x.num
Base.denominator(x::ExtendedRational32) = x.den

nan(::Type{ExtendedRational32}) = ExtendedRational32(0, 0)
posinf(::Type{ExtendedRational32}) = ExtendedRational32(1, 0)
neginf(::Type{ExtendedRational32}) = ExtendedRational32(-1, 0)

#===
Internal helpers
===#

@inline function _checked_int32(x::Integer)
    typemin(Int32) <= x <= typemax(Int32) || throw(OverflowError("value does not fit in Int32"))
    return Int32(x)
end

@inline function _normalize32(num::Integer, den::Integer)
    den == 0 && throw(ArgumentError("finite normalization requires nonzero denominator"))
    if den < 0
        num = -num
        den = -den
    end
    if num == 0
        return Int32(0), Int32(1)
    end
    g = gcd(num, den)
    n = div(num, g)
    d = div(den, g)
    return _checked_int32(n), _checked_int32(d)
end

@inline _from_canonical32(num::Int32, den::Int32) = ExtendedRational32(num, den, Val(:canonical))

@inline function _overflow_policy32(num::Integer, den::Integer)
    if den == 0
        return num == 0 ? nan(ExtendedRational32) : ExtendedRational32(sign(num), 0)
    end
    if den < 0
        num = -num
        den = -den
    end
    return num == 0 ? zero(ExtendedRational32) : ExtendedRational32(sign(num), 0)
end

@inline function _normalize_or_policy32(num::Integer, den::Integer)
    try
        nn, dd = _normalize32(num, den)
        return _from_canonical32(nn, dd)
    catch err
        if err isa OverflowError
            return _overflow_policy32(num, den)
        end
        rethrow()
    end
end

@inline function _canonical_or_policy32(num::Integer, den::Integer)
    try
        return _from_canonical32(_checked_int32(num), _checked_int32(den))
    catch err
        if err isa OverflowError
            return _overflow_policy32(num, den)
        end
        rethrow()
    end
end

# Convert finite extended values to the finite Rational32 kernel.
@inline _finite32(x::ExtendedRational32) = Rational32(x.num, x.den)
# Return sign as -1, 0, or 1 for finite and special values.
@inline _signnum(x::ExtendedRational32) = x.num > 0 ? 1 : (x.num < 0 ? -1 : 0)
@inline _both_finite(x::ExtendedRational32, y::ExtendedRational32) = x.den != 0 && y.den != 0
@inline _finite_nonzero_divisor(x::ExtendedRational32, y::ExtendedRational32) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::ExtendedRational32, y::ExtendedRational32) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)

#===
Display
===#

function Base.show(io::IO, x::ExtendedRational32)
    if isnan(x)
        print(io, "NaN32")
    elseif isinf(x)
        print(io, x.num > 0 ? "Inf32" : "-Inf32")
    else
        print(io, x.num, "//", x.den)
    end
end

#===
Conversion and promotion
===#

Base.convert(::Type{ExtendedRational32}, x::ExtendedRational32) = x
Base.convert(::Type{ExtendedRational32}, x::Integer) = ExtendedRational32(x)
Base.convert(::Type{ExtendedRational32}, x::Rational32) = ExtendedRational32(x)
Base.convert(::Type{ExtendedRational32}, x::Rational{<:Integer}) = ExtendedRational32(x)
Base.convert(::Type{Float64}, x::ExtendedRational32) = isnan(x) ? Base.NaN : isinf(x) ? (x.num > 0 ? Base.Inf : -Base.Inf) : Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::ExtendedRational32) = isnan(x) ? Float32(Base.NaN) : isinf(x) ? (x.num > 0 ? Float32(Base.Inf) : Float32(-Base.Inf)) : Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::ExtendedRational32) = isnan(x) ? BigFloat(Base.NaN) : isinf(x) ? (x.num > 0 ? BigFloat(Base.Inf) : BigFloat(-Base.Inf)) : BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational32}, x::ExtendedRational32) = isfinite(x) ? Rational32(x.num, x.den) : throw(InexactError(:convert, Rational32, x))
Base.convert(::Type{Rational{Int32}}, x::ExtendedRational32) = isfinite(x) ? (x.num // x.den) : throw(InexactError(:convert, Rational{Int32}, x))

Base.promote_rule(::Type{ExtendedRational32}, ::Type{<:Integer}) = ExtendedRational32
Base.promote_rule(::Type{ExtendedRational32}, ::Type{Rational32}) = ExtendedRational32
Base.promote_rule(::Type{ExtendedRational32}, ::Type{ExtendedRational32}) = ExtendedRational32

#===
Unary operations
===#

Base.abs(x::ExtendedRational32) = isnan(x) ? x : isinf(x) ? posinf(ExtendedRational32) : ExtendedRational32(abs(x.num), x.den)
Base.:-(x::ExtendedRational32) = isnan(x) ? x : ExtendedRational32(-Int64(x.num), x.den)
Base.inv(x::ExtendedRational32) = isnan(x) ? x : isinf(x) ? zero(ExtendedRational32) : iszero(x) ? (x.num == 0 ? posinf(ExtendedRational32) : posinf(ExtendedRational32)) : ExtendedRational32(x.den, x.num)
Base.copysign(x::ExtendedRational32, y::Real) = isnan(x) ? x : (signbit(x) == signbit(y) ? x : -x)
Base.flipsign(x::ExtendedRational32, y::Real) = isnan(x) ? x : (signbit(y) ? -x : x)

#===
Arithmetic
===#

function Base.:+(x::ExtendedRational32, y::ExtendedRational32)
    if x.den != 0 && y.den != 0
        n = Int64(x.num) * Int64(y.den) + Int64(y.num) * Int64(x.den)
        d = Int64(x.den) * Int64(y.den)
        return _normalize_or_policy32(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRational32)
    elseif isinf(x) || isinf(y)
        return isinf(x) && isinf(y) && _signnum(x) != _signnum(y) ? nan(ExtendedRational32) : (isinf(x) ? x : y)
    end
end

@inline function Base.:-(x::ExtendedRational32, y::ExtendedRational32)
    if x.den != 0 && y.den != 0
        n = Int64(x.num) * Int64(y.den) - Int64(y.num) * Int64(x.den)
        d = Int64(x.den) * Int64(y.den)
        return _normalize_or_policy32(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRational32)
    elseif isinf(x)
        return isinf(y) && _signnum(x) == _signnum(y) ? nan(ExtendedRational32) : x
    elseif isinf(y)
        return ExtendedRational32(-_signnum(y), 0)
    end
end

@inline function Base.:*(x::ExtendedRational32, y::ExtendedRational32)
    # Fast path: most workloads multiply finite values.
    if x.den != 0 && y.den != 0
        g1 = gcd(abs(Int64(x.num)), Int64(y.den))
        g2 = gcd(abs(Int64(y.num)), Int64(x.den))

        n1 = div(Int64(x.num), g1)
        d2 = div(Int64(y.den), g1)
        n2 = div(Int64(y.num), g2)
        d1 = div(Int64(x.den), g2)

        n = n1 * n2
        n == 0 && return _from_canonical32(Int32(0), Int32(1))

        d = d1 * d2
        return _canonical_or_policy32(n, d)
    elseif (x.den == 0 && x.num == 0) || (y.den == 0 && y.num == 0)
        return nan(ExtendedRational32)
    elseif (x.den == 0 && x.num != 0 && y.den != 0 && y.num == 0) ||
           (y.den == 0 && y.num != 0 && x.den != 0 && x.num == 0)
        return nan(ExtendedRational32)
    else
        return ExtendedRational32(_signnum(x) * _signnum(y), 0)
    end
end

function Base.:/(x::ExtendedRational32, y::ExtendedRational32)
    if x.den != 0 && y.den != 0 && y.num != 0
        g1 = gcd(abs(Int64(x.num)), abs(Int64(y.num)))
        g2 = gcd(Int64(x.den), Int64(y.den))

        n1 = div(Int64(x.num), g1)
        d2 = div(Int64(y.num), g1)
        n2 = div(Int64(y.den), g2)
        d1 = div(Int64(x.den), g2)

        n = n1 * n2
        n == 0 && return _from_canonical32(Int32(0), Int32(1))

        d = d1 * d2
        if d < 0
            n = -n
            d = -d
        end

        return _canonical_or_policy32(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRational32)
    elseif isinf(x) && isinf(y)
        return nan(ExtendedRational32)
    elseif iszero(y)
        return iszero(x) ? nan(ExtendedRational32) : ExtendedRational32(_signnum(x), 0)
    elseif isinf(y)
        return isinf(x) ? nan(ExtendedRational32) : zero(ExtendedRational32)
    elseif isinf(x)
        return ExtendedRational32(_signnum(x) * _signnum(y), 0)
    end
end

# Quotient/remainder family delegates finite computation to Rational32.
function Base.rem(x::ExtendedRational32, y::ExtendedRational32)
    if _finite_nonzero_divisor(x, y)
        return rem(_finite32(x), _finite32(y))
    elseif _invalid_divisor_args(x, y)
        return nan(ExtendedRational32)
    end
end

function Base.mod(x::ExtendedRational32, y::ExtendedRational32)
    if _finite_nonzero_divisor(x, y)
        return mod(_finite32(x), _finite32(y))
    elseif _invalid_divisor_args(x, y)
        return nan(ExtendedRational32)
    end
end

function Base.fld(x::ExtendedRational32, y::ExtendedRational32)
    if _finite_nonzero_divisor(x, y)
        return fld(_finite32(x), _finite32(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function Base.cld(x::ExtendedRational32, y::ExtendedRational32)
    if _finite_nonzero_divisor(x, y)
        return cld(_finite32(x), _finite32(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function Base.divrem(x::ExtendedRational32, y::ExtendedRational32)
    if _finite_nonzero_divisor(x, y)
        q, r = divrem(_finite32(x), _finite32(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function Base.fldmod(x::ExtendedRational32, y::ExtendedRational32)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod(_finite32(x), _finite32(y))
        return q, r
    end
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::ExtendedRational32, y::ExtendedRational32)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod1(_finite32(x), _finite32(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fldmod1 requires finite nonzero divisor"))
    end
end

#===
Fused multiply-add and powers
===#

Base.muladd(x::ExtendedRational32, y::ExtendedRational32, z::ExtendedRational32) = x * y + z
function Base.fma(x::ExtendedRational32, y::ExtendedRational32, z::ExtendedRational32)
    if _both_finite(x, y) && z.den != 0
        return ExtendedRational32(fma(_finite32(x), _finite32(y), _finite32(z)))
    end
    return muladd(x, y, z)
end

function Base.:^(x::ExtendedRational32, p::Integer)
    if p == 0
        return one(ExtendedRational32)
    elseif p < 0
        return inv(x)^(-p)
    end

    result = one(ExtendedRational32)
    base = x
    e = p
    while e > 0
        if isodd(e)
            result *= base
        end
        e = fld(e, 2)
        e == 0 && break
        base *= base
    end
    return result
end

#===
Mixed arithmetic with integers and Rational32
===#

for op in (:+, :-, :*, :/)
    @eval begin
        Base.$op(x::ExtendedRational32, y::Integer) = $op(x, ExtendedRational32(y))
        Base.$op(x::Integer, y::ExtendedRational32) = $op(ExtendedRational32(x), y)
        Base.$op(x::ExtendedRational32, y::Rational32) = $op(x, ExtendedRational32(y))
        Base.$op(x::Rational32, y::ExtendedRational32) = $op(ExtendedRational32(x), y)
    end
end

#===
Mixed quotient/remainder with integers and Rational32
===#

Base.rem(x::ExtendedRational32, y::Integer) = rem(x, ExtendedRational32(y))
Base.rem(x::Integer, y::ExtendedRational32) = rem(ExtendedRational32(x), y)
Base.rem(x::ExtendedRational32, y::Rational32) = rem(x, ExtendedRational32(y))
Base.rem(x::Rational32, y::ExtendedRational32) = rem(ExtendedRational32(x), y)
Base.mod(x::ExtendedRational32, y::Integer) = mod(x, ExtendedRational32(y))
Base.mod(x::Integer, y::ExtendedRational32) = mod(ExtendedRational32(x), y)
Base.mod(x::ExtendedRational32, y::Rational32) = mod(x, ExtendedRational32(y))
Base.mod(x::Rational32, y::ExtendedRational32) = mod(ExtendedRational32(x), y)
Base.fld(x::ExtendedRational32, y::Integer) = fld(x, ExtendedRational32(y))
Base.fld(x::Integer, y::ExtendedRational32) = fld(ExtendedRational32(x), y)
Base.fld(x::ExtendedRational32, y::Rational32) = fld(x, ExtendedRational32(y))
Base.fld(x::Rational32, y::ExtendedRational32) = fld(ExtendedRational32(x), y)
Base.cld(x::ExtendedRational32, y::Integer) = cld(x, ExtendedRational32(y))
Base.cld(x::Integer, y::ExtendedRational32) = cld(ExtendedRational32(x), y)
Base.cld(x::ExtendedRational32, y::Rational32) = cld(x, ExtendedRational32(y))
Base.cld(x::Rational32, y::ExtendedRational32) = cld(ExtendedRational32(x), y)
Base.divrem(x::ExtendedRational32, y::Integer) = divrem(x, ExtendedRational32(y))
Base.divrem(x::Integer, y::ExtendedRational32) = divrem(ExtendedRational32(x), y)
Base.divrem(x::ExtendedRational32, y::Rational32) = divrem(x, ExtendedRational32(y))
Base.divrem(x::Rational32, y::ExtendedRational32) = divrem(ExtendedRational32(x), y)
Base.fldmod(x::ExtendedRational32, y::Integer) = fldmod(x, ExtendedRational32(y))
Base.fldmod(x::Integer, y::ExtendedRational32) = fldmod(ExtendedRational32(x), y)
Base.fldmod(x::ExtendedRational32, y::Rational32) = fldmod(x, ExtendedRational32(y))
Base.fldmod(x::Rational32, y::ExtendedRational32) = fldmod(ExtendedRational32(x), y)
Base.fldmod1(x::ExtendedRational32, y::Integer) = fldmod1(x, ExtendedRational32(y))
Base.fldmod1(x::Integer, y::ExtendedRational32) = fldmod1(ExtendedRational32(x), y)
Base.fldmod1(x::ExtendedRational32, y::Rational32) = fldmod1(x, ExtendedRational32(y))
Base.fldmod1(x::Rational32, y::ExtendedRational32) = fldmod1(ExtendedRational32(x), y)

#===
Mixed fused multiply-add
===#

Base.muladd(x::ExtendedRational32, y::ExtendedRational32, z::Integer) = muladd(x, y, ExtendedRational32(z))
Base.muladd(x::ExtendedRational32, y::Integer, z::ExtendedRational32) = muladd(x, ExtendedRational32(y), z)
Base.muladd(x::Integer, y::ExtendedRational32, z::ExtendedRational32) = muladd(ExtendedRational32(x), y, z)
Base.muladd(x::ExtendedRational32, y::ExtendedRational32, z::Rational32) = muladd(x, y, ExtendedRational32(z))
Base.fma(x::ExtendedRational32, y::ExtendedRational32, z::Integer) = fma(x, y, ExtendedRational32(z))
Base.fma(x::ExtendedRational32, y::Integer, z::ExtendedRational32) = fma(x, ExtendedRational32(y), z)
Base.fma(x::Integer, y::ExtendedRational32, z::ExtendedRational32) = fma(ExtendedRational32(x), y, z)
Base.fma(x::ExtendedRational32, y::ExtendedRational32, z::Rational32) = fma(x, y, ExtendedRational32(z))

#===
Equality, ordering, and numeric traits
===#

Base.:(==)(x::ExtendedRational32, y::ExtendedRational32) = !isnan(x) && !isnan(y) && x.num == y.num && x.den == y.den
Base.:(==)(x::ExtendedRational32, y::Integer) = x == ExtendedRational32(y)
Base.:(==)(x::Integer, y::ExtendedRational32) = ExtendedRational32(x) == y

function Base.isless(x::ExtendedRational32, y::ExtendedRational32)
    if isnan(x)
        return false
    elseif isnan(y)
        return true
    elseif x == y
        return false
    elseif isinf(x)
        return x.num < 0
    elseif isinf(y)
        return y.num > 0
    else
        return Int64(x.num) * y.den < Int64(y.num) * x.den
    end
end

Base.:(<)(x::ExtendedRational32, y::ExtendedRational32) = !isnan(x) && !isnan(y) && isless(x, y)
Base.:(<=)(x::ExtendedRational32, y::ExtendedRational32) = !isnan(x) && !isnan(y) && (x == y || isless(x, y))
Base.:(>)(x::ExtendedRational32, y::ExtendedRational32) = y < x
Base.:(>=)(x::ExtendedRational32, y::ExtendedRational32) = y <= x

Base.hash(x::ExtendedRational32, h::UInt) = hash((x.num, x.den), h)
Base.float(x::ExtendedRational32) = Float64(x)

function Base.round(::Type{T}, x::ExtendedRational32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:round, T, x))
    return round(T, x.num / x.den)
end

function Base.trunc(::Type{T}, x::ExtendedRational32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:trunc, T, x))
    return trunc(T, x.num / x.den)
end

function Base.floor(::Type{T}, x::ExtendedRational32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:floor, T, x))
    return floor(T, x.num / x.den)
end

function Base.ceil(::Type{T}, x::ExtendedRational32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:ceil, T, x))
    return ceil(T, x.num / x.den)
end

Base.trunc(x::ExtendedRational32) = isfinite(x) ? ExtendedRational32(trunc(Int64, x), 1) : nan(ExtendedRational32)
Base.floor(x::ExtendedRational32) = isfinite(x) ? ExtendedRational32(floor(Int64, x), 1) : nan(ExtendedRational32)
Base.ceil(x::ExtendedRational32) = isfinite(x) ? ExtendedRational32(ceil(Int64, x), 1) : nan(ExtendedRational32)

export ExtendedRational32, ℚx32, finite, isfinite, isinf, isnan

end # module
