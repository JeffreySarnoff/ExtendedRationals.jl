module ExtendedRationalFast32s

include("RationalInt32s.jl")
using .RationalInt32s: Rational32

#===
Public type — lazy normalization
===#

"""
    ExtendedRationalFast32 <: Real

Like `ExtendedRational32` but delays GCD normalization until it is actually
required (display, hashing, `numerator`/`denominator`, conversion).  Arithmetic
stores results with `den > 0` and correct sign but **may leave a common factor
between `|num|` and `den`**.

Special-value encoding is identical to `ExtendedRational32`:

- `0//0`  => NaN
- `1//0`  => Inf
- `-1//0` => -Inf

All intermediate arithmetic uses native `Int64`, which holds any product of two
`Int32` values exactly — no Int128 needed.  This makes the 32-bit fast path
significantly cheaper than the 64-bit equivalent.
"""
struct ExtendedRationalFast32 <: Real
    num::Int32
    den::Int32

    # Raw constructor — caller guarantees den > 0 (or special) and sign on num.
    ExtendedRationalFast32(num::Int32, den::Int32, ::Val{:raw}) = new(num, den)

    function ExtendedRationalFast32(num::Integer, den::Integer)
        num == typemin(Int32) && throw(OverflowError("typemin(Int32) is not allowed"))
        den == typemin(Int32) && throw(OverflowError("typemin(Int32) is not allowed"))
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

        typemin(Int32) < num <= typemax(Int32) || throw(OverflowError("numerator does not fit in Int32"))
        den <= typemax(Int32) || throw(OverflowError("denominator does not fit in Int32"))

        return new(Int32(num), Int32(den))
    end
end

ExtendedRationalFast32(n::Integer) = ExtendedRationalFast32(n, 1)
ExtendedRationalFast32(x::Rational32) = _from_raw32(x.num, x.den)
ExtendedRationalFast32(x::Rational{<:Integer}) = ExtendedRationalFast32(numerator(x), denominator(x))

function ExtendedRationalFast32(x::AbstractFloat)
    isnan(x) && return ExtendedRationalFast32(0, 0)
    isinf(x) && return x > 0 ? ExtendedRationalFast32(1, 0) : ExtendedRationalFast32(-1, 0)
    r = rationalize(Int32, x)
    ExtendedRationalFast32(r.num, r.den)
end

#===
Internal raw constructor and normalizer
===#

@inline _from_raw32(num::Int32, den::Int32) = ExtendedRationalFast32(num, den, Val(:raw))

@inline function _normalize(x::ExtendedRationalFast32)
    x.den == 0 && return x
    x.num == 0 && return _from_raw32(Int32(0), Int32(1))
    g = gcd(abs(x.num), x.den)
    return _from_raw32(div(x.num, g), div(x.den, g))
end

#===
Predicates and basic properties
===#

finite(x::ExtendedRationalFast32) = x.den != 0
Base.isfinite(x::ExtendedRationalFast32) = x.den != 0
Base.isinf(x::ExtendedRationalFast32) = x.den == 0 && x.num != 0
Base.isnan(x::ExtendedRationalFast32) = x.den == 0 && x.num == 0
Base.iszero(x::ExtendedRationalFast32) = x.num == 0 && x.den != 0
Base.isone(x::ExtendedRationalFast32) = x.den > 0 && x.num == x.den
Base.isinteger(x::ExtendedRationalFast32) = x.den > 0 && rem(x.num, x.den) == 0
Base.signbit(x::ExtendedRationalFast32) = x.num < 0
Base.sign(x::ExtendedRationalFast32) = isnan(x) ? x : (iszero(x) ? zero(x) : ExtendedRationalFast32(sign(x.num), 1))

Base.zero(::Type{ExtendedRationalFast32}) = _from_raw32(Int32(0), Int32(1))
Base.zero(::ExtendedRationalFast32) = _from_raw32(Int32(0), Int32(1))
Base.one(::Type{ExtendedRationalFast32}) = _from_raw32(Int32(1), Int32(1))
Base.one(::ExtendedRationalFast32) = _from_raw32(Int32(1), Int32(1))
Base.typemin(::Type{ExtendedRationalFast32}) = _from_raw32(Int32(-1), Int32(0))
Base.typemax(::Type{ExtendedRationalFast32}) = _from_raw32(Int32(1), Int32(0))

function Base.numerator(x::ExtendedRationalFast32)
    n = _normalize(x)
    return n.num
end

function Base.denominator(x::ExtendedRationalFast32)
    n = _normalize(x)
    return n.den
end

nan(::Type{ExtendedRationalFast32}) = _from_raw32(Int32(0), Int32(0))
inf(::Type{ExtendedRationalFast32}) = _from_raw32(Int32(1), Int32(0))
posinf(::Type{ExtendedRationalFast32}) = _from_raw32(Int32(1), Int32(0))
neginf(::Type{ExtendedRationalFast32}) = _from_raw32(Int32(-1), Int32(0))

const NaN = nan
const Inf = inf
const NegInf = neginf

#===
Internal helpers
===#

@inline _signnum(x::ExtendedRationalFast32) = x.num > 0 ? 1 : (x.num < 0 ? -1 : 0)
@inline _both_finite(x::ExtendedRationalFast32, y::ExtendedRationalFast32) = x.den != 0 && y.den != 0
@inline _finite_nonzero_divisor(x::ExtendedRationalFast32, y::ExtendedRationalFast32) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::ExtendedRationalFast32, y::ExtendedRationalFast32) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)

@inline function _overflow_policy_f32(num::Integer, den::Integer)
    if den == 0
        return num == 0 ? nan(ExtendedRationalFast32) : _from_raw32(Int32(sign(num)), Int32(0))
    end
    if den < 0
        num = -num
    end
    return num == 0 ? zero(ExtendedRationalFast32) : _from_raw32(Int32(sign(num)), Int32(0))
end

# Try to store result without gcd; normalize only if it doesn't fit Int32.
# Int64 intermediates: Int32 * Int32 always fits in Int64.
@inline function _raw_or_normalize_f32(n::Int64, d::Int64)
    if n == 0
        return _from_raw32(Int32(0), Int32(1))
    end
    # Fast path: fits Int32 without normalization
    if typemin(Int32) < n <= typemax(Int32) && d <= typemax(Int32)
        return _from_raw32(Int32(n), Int32(d))
    end
    # Slow path: normalize with gcd to try to fit
    g = gcd(abs(n), d)
    nn = div(n, g)
    dd = div(d, g)
    (typemin(Int32) < nn <= typemax(Int32) && dd <= typemax(Int32)) ||
        return _overflow_policy_f32(nn, dd)
    return _from_raw32(Int32(nn), Int32(dd))
end

# For results that are already coprime.
@inline function _raw_or_policy_f32(n::Int64, d::Int64)
    (typemin(Int32) < n <= typemax(Int32) && typemin(Int32) < d <= typemax(Int32)) ||
        return _overflow_policy_f32(n, d)
    return _from_raw32(Int32(n), Int32(d))
end

@inline _finite32(x::ExtendedRationalFast32) = Rational32(numerator(x), denominator(x))

#===
Display — normalizes before printing
===#

function Base.show(io::IO, x::ExtendedRationalFast32)
    if isnan(x)
        print(io, "NaN32f")
    elseif isinf(x)
        print(io, x.num > 0 ? "Inf32f" : "-Inf32f")
    else
        n = _normalize(x)
        print(io, n.num, "//", n.den)
    end
end

#===
Conversion and promotion
===#

Base.convert(::Type{ExtendedRationalFast32}, x::ExtendedRationalFast32) = x
Base.convert(::Type{ExtendedRationalFast32}, x::Integer) = ExtendedRationalFast32(x)
Base.convert(::Type{ExtendedRationalFast32}, x::Rational32) = ExtendedRationalFast32(x)
Base.convert(::Type{ExtendedRationalFast32}, x::Rational{<:Integer}) = ExtendedRationalFast32(x)
Base.convert(::Type{Float64}, x::ExtendedRationalFast32) = isnan(x) ? Base.NaN : isinf(x) ? (x.num > 0 ? Base.Inf : -Base.Inf) : Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::ExtendedRationalFast32) = isnan(x) ? Float32(Base.NaN) : isinf(x) ? (x.num > 0 ? Float32(Base.Inf) : Float32(-Base.Inf)) : Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::ExtendedRationalFast32) = isnan(x) ? BigFloat(Base.NaN) : isinf(x) ? (x.num > 0 ? BigFloat(Base.Inf) : BigFloat(-Base.Inf)) : BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational32}, x::ExtendedRationalFast32) = isfinite(x) ? _finite32(x) : throw(InexactError(:convert, Rational32, x))
Base.convert(::Type{Rational{Int32}}, x::ExtendedRationalFast32) = isfinite(x) ? (numerator(x) // denominator(x)) : throw(InexactError(:convert, Rational{Int32}, x))

Base.promote_rule(::Type{ExtendedRationalFast32}, ::Type{<:Integer}) = ExtendedRationalFast32
Base.promote_rule(::Type{ExtendedRationalFast32}, ::Type{Rational32}) = ExtendedRationalFast32
Base.promote_rule(::Type{ExtendedRationalFast32}, ::Type{ExtendedRationalFast32}) = ExtendedRationalFast32

#===
Unary operations
===#

Base.abs(x::ExtendedRationalFast32) = isnan(x) ? x : isinf(x) ? posinf(ExtendedRationalFast32) : signbit(x) ? _from_raw32(-x.num, x.den) : x
Base.:-(x::ExtendedRationalFast32) = isnan(x) ? x : _from_raw32(-x.num, x.den)
Base.inv(x::ExtendedRationalFast32) = isnan(x) ? x : isinf(x) ? zero(ExtendedRationalFast32) : iszero(x) ? posinf(ExtendedRationalFast32) : ExtendedRationalFast32(x.den, x.num)
Base.copysign(x::ExtendedRationalFast32, y::Real) = isnan(x) ? x : (signbit(x) == signbit(y) ? x : -x)
Base.flipsign(x::ExtendedRationalFast32, y::Real) = isnan(x) ? x : (signbit(y) ? -x : x)

#===
Arithmetic — lazy normalization, Int64 intermediates
===#

@inline function Base.:+(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if x.den != 0 && y.den != 0
        n = Int64(x.num) * Int64(y.den) + Int64(y.num) * Int64(x.den)
        d = Int64(x.den) * Int64(y.den)
        return _raw_or_normalize_f32(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRationalFast32)
    elseif isinf(x) || isinf(y)
        return isinf(x) && isinf(y) && _signnum(x) != _signnum(y) ? nan(ExtendedRationalFast32) : (isinf(x) ? x : y)
    end
end

@inline function Base.:-(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if x.den != 0 && y.den != 0
        n = Int64(x.num) * Int64(y.den) - Int64(y.num) * Int64(x.den)
        d = Int64(x.den) * Int64(y.den)
        return _raw_or_normalize_f32(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRationalFast32)
    elseif isinf(x)
        return isinf(y) && _signnum(x) == _signnum(y) ? nan(ExtendedRationalFast32) : x
    elseif isinf(y)
        return _from_raw32(Int32(-_signnum(y)), Int32(0))
    end
end

@inline function Base.:*(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if x.den != 0 && y.den != 0
        n = Int64(x.num) * Int64(y.num)
        n == 0 && return _from_raw32(Int32(0), Int32(1))
        d = Int64(x.den) * Int64(y.den)
        return _raw_or_normalize_f32(n, d)
    elseif (x.den == 0 && x.num == 0) || (y.den == 0 && y.num == 0)
        return nan(ExtendedRationalFast32)
    elseif (x.den == 0 && x.num != 0 && y.den != 0 && y.num == 0) ||
           (y.den == 0 && y.num != 0 && x.den != 0 && x.num == 0)
        return nan(ExtendedRationalFast32)
    else
        return _from_raw32(Int32(_signnum(x) * _signnum(y)), Int32(0))
    end
end

@inline function Base.:/(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if x.den != 0 && y.den != 0 && y.num != 0
        n = Int64(x.num) * Int64(y.den)
        n == 0 && return _from_raw32(Int32(0), Int32(1))
        d = Int64(x.den) * Int64(y.num)
        if d < 0
            n = -n
            d = -d
        end
        return _raw_or_normalize_f32(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRationalFast32)
    elseif isinf(x) && isinf(y)
        return nan(ExtendedRationalFast32)
    elseif iszero(y)
        return iszero(x) ? nan(ExtendedRationalFast32) : _from_raw32(Int32(_signnum(x)), Int32(0))
    elseif isinf(y)
        return isinf(x) ? nan(ExtendedRationalFast32) : zero(ExtendedRationalFast32)
    elseif isinf(x)
        return _from_raw32(Int32(_signnum(x) * _signnum(y)), Int32(0))
    end
end

# Quotient/remainder family — normalizes operands via _finite32 then delegates.
function Base.rem(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if _finite_nonzero_divisor(x, y)
        r = rem(_finite32(x), _finite32(y))
        return ExtendedRationalFast32(r)
    elseif _invalid_divisor_args(x, y)
        return nan(ExtendedRationalFast32)
    end
end

function Base.mod(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if _finite_nonzero_divisor(x, y)
        r = mod(_finite32(x), _finite32(y))
        return ExtendedRationalFast32(r)
    elseif _invalid_divisor_args(x, y)
        return nan(ExtendedRationalFast32)
    end
end

function Base.fld(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if _finite_nonzero_divisor(x, y)
        return fld(_finite32(x), _finite32(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function Base.cld(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if _finite_nonzero_divisor(x, y)
        return cld(_finite32(x), _finite32(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function Base.divrem(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if _finite_nonzero_divisor(x, y)
        q, r = divrem(_finite32(x), _finite32(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function Base.fldmod(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod(_finite32(x), _finite32(y))
        return q, r
    end
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
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

Base.muladd(x::ExtendedRationalFast32, y::ExtendedRationalFast32, z::ExtendedRationalFast32) = x * y + z
function Base.fma(x::ExtendedRationalFast32, y::ExtendedRationalFast32, z::ExtendedRationalFast32)
    if _both_finite(x, y) && z.den != 0
        return ExtendedRationalFast32(fma(_finite32(x), _finite32(y), _finite32(z)))
    end
    return muladd(x, y, z)
end

function Base.:^(x::ExtendedRationalFast32, p::Integer)
    if p == 0
        return one(ExtendedRationalFast32)
    elseif p < 0
        return inv(x)^(-p)
    end

    result = one(ExtendedRationalFast32)
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
        Base.$op(x::ExtendedRationalFast32, y::Integer) = $op(x, ExtendedRationalFast32(y))
        Base.$op(x::Integer, y::ExtendedRationalFast32) = $op(ExtendedRationalFast32(x), y)
        Base.$op(x::ExtendedRationalFast32, y::Rational32) = $op(x, ExtendedRationalFast32(y))
        Base.$op(x::Rational32, y::ExtendedRationalFast32) = $op(ExtendedRationalFast32(x), y)
    end
end

#===
Mixed quotient/remainder with integers and Rational32
===#

Base.rem(x::ExtendedRationalFast32, y::Integer) = rem(x, ExtendedRationalFast32(y))
Base.rem(x::Integer, y::ExtendedRationalFast32) = rem(ExtendedRationalFast32(x), y)
Base.rem(x::ExtendedRationalFast32, y::Rational32) = rem(x, ExtendedRationalFast32(y))
Base.rem(x::Rational32, y::ExtendedRationalFast32) = rem(ExtendedRationalFast32(x), y)
Base.mod(x::ExtendedRationalFast32, y::Integer) = mod(x, ExtendedRationalFast32(y))
Base.mod(x::Integer, y::ExtendedRationalFast32) = mod(ExtendedRationalFast32(x), y)
Base.mod(x::ExtendedRationalFast32, y::Rational32) = mod(x, ExtendedRationalFast32(y))
Base.mod(x::Rational32, y::ExtendedRationalFast32) = mod(ExtendedRationalFast32(x), y)
Base.fld(x::ExtendedRationalFast32, y::Integer) = fld(x, ExtendedRationalFast32(y))
Base.fld(x::Integer, y::ExtendedRationalFast32) = fld(ExtendedRationalFast32(x), y)
Base.fld(x::ExtendedRationalFast32, y::Rational32) = fld(x, ExtendedRationalFast32(y))
Base.fld(x::Rational32, y::ExtendedRationalFast32) = fld(ExtendedRationalFast32(x), y)
Base.cld(x::ExtendedRationalFast32, y::Integer) = cld(x, ExtendedRationalFast32(y))
Base.cld(x::Integer, y::ExtendedRationalFast32) = cld(ExtendedRationalFast32(x), y)
Base.cld(x::ExtendedRationalFast32, y::Rational32) = cld(x, ExtendedRationalFast32(y))
Base.cld(x::Rational32, y::ExtendedRationalFast32) = cld(ExtendedRationalFast32(x), y)
Base.divrem(x::ExtendedRationalFast32, y::Integer) = divrem(x, ExtendedRationalFast32(y))
Base.divrem(x::Integer, y::ExtendedRationalFast32) = divrem(ExtendedRationalFast32(x), y)
Base.divrem(x::ExtendedRationalFast32, y::Rational32) = divrem(x, ExtendedRationalFast32(y))
Base.divrem(x::Rational32, y::ExtendedRationalFast32) = divrem(ExtendedRationalFast32(x), y)
Base.fldmod(x::ExtendedRationalFast32, y::Integer) = fldmod(x, ExtendedRationalFast32(y))
Base.fldmod(x::Integer, y::ExtendedRationalFast32) = fldmod(ExtendedRationalFast32(x), y)
Base.fldmod(x::ExtendedRationalFast32, y::Rational32) = fldmod(x, ExtendedRationalFast32(y))
Base.fldmod(x::Rational32, y::ExtendedRationalFast32) = fldmod(ExtendedRationalFast32(x), y)
Base.fldmod1(x::ExtendedRationalFast32, y::Integer) = fldmod1(x, ExtendedRationalFast32(y))
Base.fldmod1(x::Integer, y::ExtendedRationalFast32) = fldmod1(ExtendedRationalFast32(x), y)
Base.fldmod1(x::ExtendedRationalFast32, y::Rational32) = fldmod1(x, ExtendedRationalFast32(y))
Base.fldmod1(x::Rational32, y::ExtendedRationalFast32) = fldmod1(ExtendedRationalFast32(x), y)

#===
Mixed fused multiply-add
===#

Base.muladd(x::ExtendedRationalFast32, y::ExtendedRationalFast32, z::Integer) = muladd(x, y, ExtendedRationalFast32(z))
Base.muladd(x::ExtendedRationalFast32, y::Integer, z::ExtendedRationalFast32) = muladd(x, ExtendedRationalFast32(y), z)
Base.muladd(x::Integer, y::ExtendedRationalFast32, z::ExtendedRationalFast32) = muladd(ExtendedRationalFast32(x), y, z)
Base.muladd(x::ExtendedRationalFast32, y::ExtendedRationalFast32, z::Rational32) = muladd(x, y, ExtendedRationalFast32(z))
Base.fma(x::ExtendedRationalFast32, y::ExtendedRationalFast32, z::Integer) = fma(x, y, ExtendedRationalFast32(z))
Base.fma(x::ExtendedRationalFast32, y::Integer, z::ExtendedRationalFast32) = fma(x, ExtendedRationalFast32(y), z)
Base.fma(x::Integer, y::ExtendedRationalFast32, z::ExtendedRationalFast32) = fma(ExtendedRationalFast32(x), y, z)
Base.fma(x::ExtendedRationalFast32, y::ExtendedRationalFast32, z::Rational32) = fma(x, y, ExtendedRationalFast32(z))

#===
Equality, ordering — uses cross-multiplication (no normalization needed)
===#

@inline function Base.:(==)(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    (isnan(x) || isnan(y)) && return false
    (x.den == 0 || y.den == 0) && return x.num == y.num && x.den == y.den
    # Finite: cross-multiply in Int64 — always exact for Int32 operands.
    return Int64(x.num) * Int64(y.den) == Int64(y.num) * Int64(x.den)
end
Base.:(==)(x::ExtendedRationalFast32, y::Integer) = x == ExtendedRationalFast32(y)
Base.:(==)(x::Integer, y::ExtendedRationalFast32) = ExtendedRationalFast32(x) == y

function Base.isless(x::ExtendedRationalFast32, y::ExtendedRationalFast32)
    if isnan(x)
        return false
    elseif isnan(y)
        return true
    elseif isinf(x)
        return x.num < 0 && !(isinf(y) && y.num < 0)
    elseif isinf(y)
        return y.num > 0 && !(isinf(x) && x.num > 0)
    else
        return Int64(x.num) * Int64(y.den) < Int64(y.num) * Int64(x.den)
    end
end

Base.:(<)(x::ExtendedRationalFast32, y::ExtendedRationalFast32) = !isnan(x) && !isnan(y) && isless(x, y)
Base.:(<=)(x::ExtendedRationalFast32, y::ExtendedRationalFast32) = !isnan(x) && !isnan(y) && (x == y || isless(x, y))
Base.:(>)(x::ExtendedRationalFast32, y::ExtendedRationalFast32) = y < x
Base.:(>=)(x::ExtendedRationalFast32, y::ExtendedRationalFast32) = y <= x

function Base.hash(x::ExtendedRationalFast32, h::UInt)
    n = _normalize(x)
    return hash((n.num, n.den), h)
end

Base.float(x::ExtendedRationalFast32) = Float64(x)

function Base.round(::Type{T}, x::ExtendedRationalFast32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:round, T, x))
    return round(T, x.num / x.den)
end

function Base.trunc(::Type{T}, x::ExtendedRationalFast32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:trunc, T, x))
    return trunc(T, x.num / x.den)
end

function Base.floor(::Type{T}, x::ExtendedRationalFast32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:floor, T, x))
    return floor(T, x.num / x.den)
end

function Base.ceil(::Type{T}, x::ExtendedRationalFast32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:ceil, T, x))
    return ceil(T, x.num / x.den)
end

Base.trunc(x::ExtendedRationalFast32) = isfinite(x) ? ExtendedRationalFast32(trunc(Int64, x), 1) : nan(ExtendedRationalFast32)
Base.floor(x::ExtendedRationalFast32) = isfinite(x) ? ExtendedRationalFast32(floor(Int64, x), 1) : nan(ExtendedRationalFast32)
Base.ceil(x::ExtendedRationalFast32) = isfinite(x) ? ExtendedRationalFast32(ceil(Int64, x), 1) : nan(ExtendedRationalFast32)

export ExtendedRationalFast32, finite, isfinite, isinf, isnan

end # module
