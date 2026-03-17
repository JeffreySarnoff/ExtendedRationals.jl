module ExtendedRationalFast64s

include("RationalInt64s.jl")
using .RationalInt64s: Rational64

#===
Public type — lazy normalization
===#

"""
    ExtendedRationalFast64 <: Real

Like `ExtendedRational64` but delays GCD normalization until it is actually
required (display, hashing, `numerator`/`denominator`, conversion).  Arithmetic
stores results with `den > 0` and correct sign but **may leave a common factor
between `|num|` and `den`**.

Special-value encoding is identical to `ExtendedRational64`:

- `0//0`  => NaN
- `1//0`  => Inf
- `-1//0` => -Inf

Arithmetic that overflows `Int64` after GCD reduction saturates to
`Inf` / `-Inf` / `NaN` as appropriate.
"""
struct ExtendedRationalFast64 <: Real
    num::Int64
    den::Int64

    # Raw constructor — caller guarantees den > 0 (or special) and sign on num.
    ExtendedRationalFast64(num::Int64, den::Int64, ::Val{:raw}) = new(num, den)

    function ExtendedRationalFast64(num::Integer, den::Integer)
        num == typemin(Int64) && throw(OverflowError("typemin(Int64) is not allowed"))
        den == typemin(Int64) && throw(OverflowError("typemin(Int64) is not allowed"))
        if den == 0
            if num == 0
                return new(Int64(0), Int64(0))
            elseif num > 0
                return new(Int64(1), Int64(0))
            else
                return new(Int64(-1), Int64(0))
            end
        end

        if den < 0
            num = -num
            den = -den
        end

        if num == 0
            return new(Int64(0), Int64(1))
        end

        # Skip gcd — store unnormalized.
        typemin(Int64) < num <= typemax(Int64) || throw(OverflowError("numerator does not fit in Int64"))
        den <= typemax(Int64) || throw(OverflowError("denominator does not fit in Int64"))

        return new(Int64(num), Int64(den))
    end
end

ExtendedRationalFast64(n::Integer) = ExtendedRationalFast64(n, 1)
ExtendedRationalFast64(x::Rational64) = _from_raw64(x.num, x.den)
ExtendedRationalFast64(x::Rational{<:Integer}) = ExtendedRationalFast64(numerator(x), denominator(x))

function ExtendedRationalFast64(x::AbstractFloat)
    isnan(x) && return ExtendedRationalFast64(0, 0)
    isinf(x) && return x > 0 ? ExtendedRationalFast64(1, 0) : ExtendedRationalFast64(-1, 0)
    r = rationalize(Int64, x)
    ExtendedRationalFast64(r.num, r.den)
end

#===
Internal raw constructor and normalizer
===#

@inline _from_raw64(num::Int64, den::Int64) = ExtendedRationalFast64(num, den, Val(:raw))

@inline function _normalize(x::ExtendedRationalFast64)
    x.den == 0 && return x
    x.num == 0 && return _from_raw64(Int64(0), Int64(1))
    g = gcd(abs(x.num), x.den)
    return _from_raw64(div(x.num, g), div(x.den, g))
end

#===
Predicates and basic properties
===#

finite(x::ExtendedRationalFast64) = x.den != 0
Base.isfinite(x::ExtendedRationalFast64) = x.den != 0
Base.isinf(x::ExtendedRationalFast64) = x.den == 0 && x.num != 0
Base.isnan(x::ExtendedRationalFast64) = x.den == 0 && x.num == 0
Base.iszero(x::ExtendedRationalFast64) = x.num == 0 && x.den != 0
Base.isone(x::ExtendedRationalFast64) = x.den > 0 && x.num == x.den
Base.isinteger(x::ExtendedRationalFast64) = x.den > 0 && rem(x.num, x.den) == 0
Base.signbit(x::ExtendedRationalFast64) = x.num < 0
Base.sign(x::ExtendedRationalFast64) = isnan(x) ? x : (iszero(x) ? zero(x) : ExtendedRationalFast64(sign(x.num), 1))

Base.zero(::Type{ExtendedRationalFast64}) = _from_raw64(Int64(0), Int64(1))
Base.zero(::ExtendedRationalFast64) = _from_raw64(Int64(0), Int64(1))
Base.one(::Type{ExtendedRationalFast64}) = _from_raw64(Int64(1), Int64(1))
Base.one(::ExtendedRationalFast64) = _from_raw64(Int64(1), Int64(1))
Base.typemin(::Type{ExtendedRationalFast64}) = _from_raw64(Int64(-1), Int64(0))
Base.typemax(::Type{ExtendedRationalFast64}) = _from_raw64(Int64(1), Int64(0))

function Base.numerator(x::ExtendedRationalFast64)
    n = _normalize(x)
    return n.num
end

function Base.denominator(x::ExtendedRationalFast64)
    n = _normalize(x)
    return n.den
end

nan(::Type{ExtendedRationalFast64}) = _from_raw64(Int64(0), Int64(0))
inf(::Type{ExtendedRationalFast64}) = _from_raw64(Int64(1), Int64(0))
posinf(::Type{ExtendedRationalFast64}) = _from_raw64(Int64(1), Int64(0))
neginf(::Type{ExtendedRationalFast64}) = _from_raw64(Int64(-1), Int64(0))

const NaN = nan
const Inf = inf
const NegInf = neginf

#===
Internal helpers
===#

@inline _signnum(x::ExtendedRationalFast64) = x.num > 0 ? 1 : (x.num < 0 ? -1 : 0)
@inline _both_finite(x::ExtendedRationalFast64, y::ExtendedRationalFast64) = x.den != 0 && y.den != 0
@inline _finite_nonzero_divisor(x::ExtendedRationalFast64, y::ExtendedRationalFast64) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::ExtendedRationalFast64, y::ExtendedRationalFast64) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)

@inline function _overflow_policy_f64(num::Integer, den::Integer)
    if den == 0
        return num == 0 ? nan(ExtendedRationalFast64) : _from_raw64(Int64(sign(num)), Int64(0))
    end
    if den < 0
        num = -num
    end
    return num == 0 ? zero(ExtendedRationalFast64) : _from_raw64(Int64(sign(num)), Int64(0))
end

# Try to store result without gcd; normalize only if it doesn't fit Int64.
@inline function _raw_or_normalize_f64(n::Int128, d::Int128)
    if n == 0
        return _from_raw64(Int64(0), Int64(1))
    end
    # Fast path: fits Int64 without normalization
    if typemin(Int64) < n <= typemax(Int64) && d <= typemax(Int64)
        return _from_raw64(Int64(n), Int64(d))
    end
    # Slow path: normalize with gcd
    g = gcd(abs(n), d)
    nn = div(n, g)
    dd = div(d, g)
    (typemin(Int64) < nn <= typemax(Int64) && dd <= typemax(Int64)) ||
        return _overflow_policy_f64(nn, dd)
    return _from_raw64(Int64(nn), Int64(dd))
end

# For results that are already coprime (from cross-cancelled multiply).
@inline function _raw_or_policy_f64(n::Int128, d::Int128)
    (typemin(Int64) < n <= typemax(Int64) && typemin(Int64) < d <= typemax(Int64)) ||
        return _overflow_policy_f64(n, d)
    return _from_raw64(Int64(n), Int64(d))
end

@inline _finite64(x::ExtendedRationalFast64) = Rational64(numerator(x), denominator(x))

#===
Display — normalizes before printing
===#

function Base.show(io::IO, x::ExtendedRationalFast64)
    if isnan(x)
        print(io, "NaN64f")
    elseif isinf(x)
        print(io, x.num > 0 ? "Inf64f" : "-Inf64f")
    else
        n = _normalize(x)
        print(io, n.num, "//", n.den)
    end
end

#===
Conversion and promotion
===#

Base.convert(::Type{ExtendedRationalFast64}, x::ExtendedRationalFast64) = x
Base.convert(::Type{ExtendedRationalFast64}, x::Integer) = ExtendedRationalFast64(x)
Base.convert(::Type{ExtendedRationalFast64}, x::Rational64) = ExtendedRationalFast64(x)
Base.convert(::Type{ExtendedRationalFast64}, x::Rational{<:Integer}) = ExtendedRationalFast64(x)
Base.convert(::Type{Float64}, x::ExtendedRationalFast64) = isnan(x) ? Base.NaN : isinf(x) ? (x.num > 0 ? Base.Inf : -Base.Inf) : Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::ExtendedRationalFast64) = isnan(x) ? Float32(Base.NaN) : isinf(x) ? (x.num > 0 ? Float32(Base.Inf) : Float32(-Base.Inf)) : Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::ExtendedRationalFast64) = isnan(x) ? BigFloat(Base.NaN) : isinf(x) ? (x.num > 0 ? BigFloat(Base.Inf) : BigFloat(-Base.Inf)) : BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational64}, x::ExtendedRationalFast64) = isfinite(x) ? _finite64(x) : throw(InexactError(:convert, Rational64, x))
Base.convert(::Type{Rational{Int64}}, x::ExtendedRationalFast64) = isfinite(x) ? (numerator(x) // denominator(x)) : throw(InexactError(:convert, Rational{Int64}, x))

Base.promote_rule(::Type{ExtendedRationalFast64}, ::Type{<:Integer}) = ExtendedRationalFast64
Base.promote_rule(::Type{ExtendedRationalFast64}, ::Type{Rational64}) = ExtendedRationalFast64
Base.promote_rule(::Type{ExtendedRationalFast64}, ::Type{ExtendedRationalFast64}) = ExtendedRationalFast64

#===
Unary operations
===#

Base.abs(x::ExtendedRationalFast64) = isnan(x) ? x : isinf(x) ? posinf(ExtendedRationalFast64) : signbit(x) ? _from_raw64(-x.num, x.den) : x
Base.:-(x::ExtendedRationalFast64) = isnan(x) ? x : _from_raw64(-x.num, x.den)
Base.inv(x::ExtendedRationalFast64) = isnan(x) ? x : isinf(x) ? zero(ExtendedRationalFast64) : iszero(x) ? posinf(ExtendedRationalFast64) : ExtendedRationalFast64(x.den, x.num)
Base.copysign(x::ExtendedRationalFast64, y::Real) = isnan(x) ? x : (signbit(x) == signbit(y) ? x : -x)
Base.flipsign(x::ExtendedRationalFast64, y::Real) = isnan(x) ? x : (signbit(y) ? -x : x)

#===
Arithmetic — lazy normalization
===#

@inline function Base.:+(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if x.den != 0 && y.den != 0
        n = Int128(x.num) * Int128(y.den) + Int128(y.num) * Int128(x.den)
        d = Int128(x.den) * Int128(y.den)
        return _raw_or_normalize_f64(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRationalFast64)
    elseif isinf(x) || isinf(y)
        return isinf(x) && isinf(y) && _signnum(x) != _signnum(y) ? nan(ExtendedRationalFast64) : (isinf(x) ? x : y)
    end
end

@inline function Base.:-(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if x.den != 0 && y.den != 0
        n = Int128(x.num) * Int128(y.den) - Int128(y.num) * Int128(x.den)
        d = Int128(x.den) * Int128(y.den)
        return _raw_or_normalize_f64(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRationalFast64)
    elseif isinf(x)
        return isinf(y) && _signnum(x) == _signnum(y) ? nan(ExtendedRationalFast64) : x
    elseif isinf(y)
        return _from_raw64(Int64(-_signnum(y)), Int64(0))
    end
end

@inline function Base.:*(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if x.den != 0 && y.den != 0
        n = Int128(x.num) * Int128(y.num)
        n == 0 && return _from_raw64(Int64(0), Int64(1))
        d = Int128(x.den) * Int128(y.den)
        return _raw_or_normalize_f64(n, d)
    elseif (x.den == 0 && x.num == 0) || (y.den == 0 && y.num == 0)
        return nan(ExtendedRationalFast64)
    elseif (x.den == 0 && x.num != 0 && y.den != 0 && y.num == 0) ||
           (y.den == 0 && y.num != 0 && x.den != 0 && x.num == 0)
        return nan(ExtendedRationalFast64)
    else
        return _from_raw64(Int64(_signnum(x) * _signnum(y)), Int64(0))
    end
end

@inline function Base.:/(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if x.den != 0 && y.den != 0 && y.num != 0
        n = Int128(x.num) * Int128(y.den)
        n == 0 && return _from_raw64(Int64(0), Int64(1))
        d = Int128(x.den) * Int128(y.num)
        if d < 0
            n = -n
            d = -d
        end
        return _raw_or_normalize_f64(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRationalFast64)
    elseif isinf(x) && isinf(y)
        return nan(ExtendedRationalFast64)
    elseif iszero(y)
        return iszero(x) ? nan(ExtendedRationalFast64) : _from_raw64(Int64(_signnum(x)), Int64(0))
    elseif isinf(y)
        return isinf(x) ? nan(ExtendedRationalFast64) : zero(ExtendedRationalFast64)
    elseif isinf(x)
        return _from_raw64(Int64(_signnum(x) * _signnum(y)), Int64(0))
    end
end

# Quotient/remainder family — normalizes operands via _finite64 then delegates.
function Base.rem(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if _finite_nonzero_divisor(x, y)
        r = rem(_finite64(x), _finite64(y))
        return ExtendedRationalFast64(r)
    elseif _invalid_divisor_args(x, y)
        return nan(ExtendedRationalFast64)
    end
end

function Base.mod(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if _finite_nonzero_divisor(x, y)
        r = mod(_finite64(x), _finite64(y))
        return ExtendedRationalFast64(r)
    elseif _invalid_divisor_args(x, y)
        return nan(ExtendedRationalFast64)
    end
end

function Base.fld(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if _finite_nonzero_divisor(x, y)
        return fld(_finite64(x), _finite64(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function Base.cld(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if _finite_nonzero_divisor(x, y)
        return cld(_finite64(x), _finite64(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function Base.divrem(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if _finite_nonzero_divisor(x, y)
        q, r = divrem(_finite64(x), _finite64(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function Base.fldmod(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod(_finite64(x), _finite64(y))
        return q, r
    end
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod1(_finite64(x), _finite64(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fldmod1 requires finite nonzero divisor"))
    end
end

#===
Fused multiply-add and powers
===#

Base.muladd(x::ExtendedRationalFast64, y::ExtendedRationalFast64, z::ExtendedRationalFast64) = x * y + z
function Base.fma(x::ExtendedRationalFast64, y::ExtendedRationalFast64, z::ExtendedRationalFast64)
    if _both_finite(x, y) && z.den != 0
        return ExtendedRationalFast64(fma(_finite64(x), _finite64(y), _finite64(z)))
    end
    return muladd(x, y, z)
end

function Base.:^(x::ExtendedRationalFast64, p::Integer)
    if p == 0
        return one(ExtendedRationalFast64)
    elseif p < 0
        return inv(x)^(-p)
    end

    result = one(ExtendedRationalFast64)
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
Mixed arithmetic with integers and Rational64
===#

for op in (:+, :-, :*, :/)
    @eval begin
        Base.$op(x::ExtendedRationalFast64, y::Integer) = $op(x, ExtendedRationalFast64(y))
        Base.$op(x::Integer, y::ExtendedRationalFast64) = $op(ExtendedRationalFast64(x), y)
        Base.$op(x::ExtendedRationalFast64, y::Rational64) = $op(x, ExtendedRationalFast64(y))
        Base.$op(x::Rational64, y::ExtendedRationalFast64) = $op(ExtendedRationalFast64(x), y)
    end
end

#===
Mixed quotient/remainder with integers and Rational64
===#

Base.rem(x::ExtendedRationalFast64, y::Integer) = rem(x, ExtendedRationalFast64(y))
Base.rem(x::Integer, y::ExtendedRationalFast64) = rem(ExtendedRationalFast64(x), y)
Base.rem(x::ExtendedRationalFast64, y::Rational64) = rem(x, ExtendedRationalFast64(y))
Base.rem(x::Rational64, y::ExtendedRationalFast64) = rem(ExtendedRationalFast64(x), y)
Base.mod(x::ExtendedRationalFast64, y::Integer) = mod(x, ExtendedRationalFast64(y))
Base.mod(x::Integer, y::ExtendedRationalFast64) = mod(ExtendedRationalFast64(x), y)
Base.mod(x::ExtendedRationalFast64, y::Rational64) = mod(x, ExtendedRationalFast64(y))
Base.mod(x::Rational64, y::ExtendedRationalFast64) = mod(ExtendedRationalFast64(x), y)
Base.fld(x::ExtendedRationalFast64, y::Integer) = fld(x, ExtendedRationalFast64(y))
Base.fld(x::Integer, y::ExtendedRationalFast64) = fld(ExtendedRationalFast64(x), y)
Base.fld(x::ExtendedRationalFast64, y::Rational64) = fld(x, ExtendedRationalFast64(y))
Base.fld(x::Rational64, y::ExtendedRationalFast64) = fld(ExtendedRationalFast64(x), y)
Base.cld(x::ExtendedRationalFast64, y::Integer) = cld(x, ExtendedRationalFast64(y))
Base.cld(x::Integer, y::ExtendedRationalFast64) = cld(ExtendedRationalFast64(x), y)
Base.cld(x::ExtendedRationalFast64, y::Rational64) = cld(x, ExtendedRationalFast64(y))
Base.cld(x::Rational64, y::ExtendedRationalFast64) = cld(ExtendedRationalFast64(x), y)
Base.divrem(x::ExtendedRationalFast64, y::Integer) = divrem(x, ExtendedRationalFast64(y))
Base.divrem(x::Integer, y::ExtendedRationalFast64) = divrem(ExtendedRationalFast64(x), y)
Base.divrem(x::ExtendedRationalFast64, y::Rational64) = divrem(x, ExtendedRationalFast64(y))
Base.divrem(x::Rational64, y::ExtendedRationalFast64) = divrem(ExtendedRationalFast64(x), y)
Base.fldmod(x::ExtendedRationalFast64, y::Integer) = fldmod(x, ExtendedRationalFast64(y))
Base.fldmod(x::Integer, y::ExtendedRationalFast64) = fldmod(ExtendedRationalFast64(x), y)
Base.fldmod(x::ExtendedRationalFast64, y::Rational64) = fldmod(x, ExtendedRationalFast64(y))
Base.fldmod(x::Rational64, y::ExtendedRationalFast64) = fldmod(ExtendedRationalFast64(x), y)
Base.fldmod1(x::ExtendedRationalFast64, y::Integer) = fldmod1(x, ExtendedRationalFast64(y))
Base.fldmod1(x::Integer, y::ExtendedRationalFast64) = fldmod1(ExtendedRationalFast64(x), y)
Base.fldmod1(x::ExtendedRationalFast64, y::Rational64) = fldmod1(x, ExtendedRationalFast64(y))
Base.fldmod1(x::Rational64, y::ExtendedRationalFast64) = fldmod1(ExtendedRationalFast64(x), y)

#===
Mixed fused multiply-add
===#

Base.muladd(x::ExtendedRationalFast64, y::ExtendedRationalFast64, z::Integer) = muladd(x, y, ExtendedRationalFast64(z))
Base.muladd(x::ExtendedRationalFast64, y::Integer, z::ExtendedRationalFast64) = muladd(x, ExtendedRationalFast64(y), z)
Base.muladd(x::Integer, y::ExtendedRationalFast64, z::ExtendedRationalFast64) = muladd(ExtendedRationalFast64(x), y, z)
Base.muladd(x::ExtendedRationalFast64, y::ExtendedRationalFast64, z::Rational64) = muladd(x, y, ExtendedRationalFast64(z))
Base.fma(x::ExtendedRationalFast64, y::ExtendedRationalFast64, z::Integer) = fma(x, y, ExtendedRationalFast64(z))
Base.fma(x::ExtendedRationalFast64, y::Integer, z::ExtendedRationalFast64) = fma(x, ExtendedRationalFast64(y), z)
Base.fma(x::Integer, y::ExtendedRationalFast64, z::ExtendedRationalFast64) = fma(ExtendedRationalFast64(x), y, z)
Base.fma(x::ExtendedRationalFast64, y::ExtendedRationalFast64, z::Rational64) = fma(x, y, ExtendedRationalFast64(z))

#===
Equality, ordering — uses cross-multiplication (no normalization needed)
===#

@inline function Base.:(==)(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    (isnan(x) || isnan(y)) && return false
    # Special values: compare directly (cross-multiply fails when den==0).
    (x.den == 0 || y.den == 0) && return x.num == y.num && x.den == y.den
    # Finite: cross-multiply works since den > 0.
    return Int128(x.num) * Int128(y.den) == Int128(y.num) * Int128(x.den)
end
Base.:(==)(x::ExtendedRationalFast64, y::Integer) = x == ExtendedRationalFast64(y)
Base.:(==)(x::Integer, y::ExtendedRationalFast64) = ExtendedRationalFast64(x) == y

function Base.isless(x::ExtendedRationalFast64, y::ExtendedRationalFast64)
    if isnan(x)
        return false
    elseif isnan(y)
        return true
    elseif isinf(x)
        return x.num < 0 && !(isinf(y) && y.num < 0)
    elseif isinf(y)
        return y.num > 0 && !(isinf(x) && x.num > 0)
    else
        return Int128(x.num) * Int128(y.den) < Int128(y.num) * Int128(x.den)
    end
end

Base.:(<)(x::ExtendedRationalFast64, y::ExtendedRationalFast64) = !isnan(x) && !isnan(y) && isless(x, y)
Base.:(<=)(x::ExtendedRationalFast64, y::ExtendedRationalFast64) = !isnan(x) && !isnan(y) && (x == y || isless(x, y))
Base.:(>)(x::ExtendedRationalFast64, y::ExtendedRationalFast64) = y < x
Base.:(>=)(x::ExtendedRationalFast64, y::ExtendedRationalFast64) = y <= x

function Base.hash(x::ExtendedRationalFast64, h::UInt)
    n = _normalize(x)
    return hash((n.num, n.den), h)
end

Base.float(x::ExtendedRationalFast64) = Float64(x)

function Base.round(::Type{T}, x::ExtendedRationalFast64) where {T<:Integer}
    isfinite(x) || throw(InexactError(:round, T, x))
    return round(T, x.num / x.den)
end

function Base.trunc(::Type{T}, x::ExtendedRationalFast64) where {T<:Integer}
    isfinite(x) || throw(InexactError(:trunc, T, x))
    return trunc(T, x.num / x.den)
end

function Base.floor(::Type{T}, x::ExtendedRationalFast64) where {T<:Integer}
    isfinite(x) || throw(InexactError(:floor, T, x))
    return floor(T, x.num / x.den)
end

function Base.ceil(::Type{T}, x::ExtendedRationalFast64) where {T<:Integer}
    isfinite(x) || throw(InexactError(:ceil, T, x))
    return ceil(T, x.num / x.den)
end

Base.trunc(x::ExtendedRationalFast64) = isfinite(x) ? ExtendedRationalFast64(trunc(Int128, x), 1) : nan(ExtendedRationalFast64)
Base.floor(x::ExtendedRationalFast64) = isfinite(x) ? ExtendedRationalFast64(floor(Int128, x), 1) : nan(ExtendedRationalFast64)
Base.ceil(x::ExtendedRationalFast64) = isfinite(x) ? ExtendedRationalFast64(ceil(Int128, x), 1) : nan(ExtendedRationalFast64)

export ExtendedRationalFast64, finite, isfinite, isinf, isnan

end # module
