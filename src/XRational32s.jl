module XRational32s

include("Rational32s.jl")
using .Rational32s: Rational32

#===
Public type — lazy normalization
===#

"""
    XRational32 <: Real

Like `XRational32` but delays GCD normalization until it is actually
required (display, hashing, `numerator`/`denominator`, conversion).  Arithmetic
stores results with `den > 0` and correct sign but **may leave a common factor
between `|num|` and `den`**.

Special-value encoding is identical to `XRational32`:

- `0//0`  => NaN
- `1//0`  => Inf
- `-1//0` => -Inf

All intermediate arithmetic uses native `Int64`, which holds any product of two
`Int32` values exactly — no Int128 needed.  This makes the 32-bit fast path
significantly cheaper than the 64-bit equivalent.
"""
struct XRational32 <: Real
    num::Int32
    den::Int32

    # Raw constructor — caller guarantees den > 0 (or special) and sign on num.
    XRational32(num::Int32, den::Int32, ::Val{:raw}) = new(num, den)

    function XRational32(num::Integer, den::Integer)
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

XRational32(n::Integer) = XRational32(n, 1)
XRational32(x::Rational32) = _from_raw32(x.num, x.den)
XRational32(x::Rational{<:Integer}) = XRational32(numerator(x), denominator(x))

function XRational32(x::AbstractFloat)
    isnan(x) && return XRational32(0, 0)
    isinf(x) && return x > 0 ? XRational32(1, 0) : XRational32(-1, 0)
    r = rationalize(Int32, x)
    XRational32(r.num, r.den)
end

#===
Internal raw constructor and normalizer
===#

@inline _from_raw32(num::Int32, den::Int32) = XRational32(num, den, Val(:raw))

@inline function _normalize(x::XRational32)
    x.den == 0 && return x
    x.num == 0 && return _from_raw32(Int32(0), Int32(1))
    g = gcd(abs(x.num), x.den)
    return _from_raw32(div(x.num, g), div(x.den, g))
end

#===
Predicates and basic properties
===#

finite(x::XRational32) = x.den != 0
Base.isfinite(x::XRational32) = x.den != 0
Base.isinf(x::XRational32) = x.den == 0 && x.num != 0
Base.isnan(x::XRational32) = x.den == 0 && x.num == 0
Base.iszero(x::XRational32) = x.num == 0 && x.den != 0
Base.isone(x::XRational32) = x.den > 0 && x.num == x.den
Base.isinteger(x::XRational32) = x.den > 0 && rem(x.num, x.den) == 0
Base.signbit(x::XRational32) = x.num < 0
Base.sign(x::XRational32) = isnan(x) ? x : (iszero(x) ? zero(x) : XRational32(sign(x.num), 1))

Base.zero(::Type{XRational32}) = _from_raw32(Int32(0), Int32(1))
Base.zero(::XRational32) = _from_raw32(Int32(0), Int32(1))
Base.one(::Type{XRational32}) = _from_raw32(Int32(1), Int32(1))
Base.one(::XRational32) = _from_raw32(Int32(1), Int32(1))
Base.typemin(::Type{XRational32}) = _from_raw32(Int32(-1), Int32(0))
Base.typemax(::Type{XRational32}) = _from_raw32(Int32(1), Int32(0))

function Base.numerator(x::XRational32)
    n = _normalize(x)
    return n.num
end

function Base.denominator(x::XRational32)
    n = _normalize(x)
    return n.den
end

nan(::Type{XRational32}) = _from_raw32(Int32(0), Int32(0))
inf(::Type{XRational32}) = _from_raw32(Int32(1), Int32(0))
posinf(::Type{XRational32}) = _from_raw32(Int32(1), Int32(0))
neginf(::Type{XRational32}) = _from_raw32(Int32(-1), Int32(0))

const NaN = nan
const Inf = inf
const NegInf = neginf

#===
Internal helpers
===#

@inline _signnum(x::XRational32) = x.num > 0 ? 1 : (x.num < 0 ? -1 : 0)
@inline _both_finite(x::XRational32, y::XRational32) = x.den != 0 && y.den != 0
@inline _finite_nonzero_divisor(x::XRational32, y::XRational32) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::XRational32, y::XRational32) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)

@inline function _overflow_policy_f32(num::Integer, den::Integer)
    if den == 0
        return num == 0 ? nan(XRational32) : _from_raw32(Int32(sign(num)), Int32(0))
    end
    if den < 0
        num = -num
    end
    return num == 0 ? zero(XRational32) : _from_raw32(Int32(sign(num)), Int32(0))
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

@inline _finite32(x::XRational32) = Rational32(numerator(x), denominator(x))

#===
Display — normalizes before printing
===#

function Base.show(io::IO, x::XRational32)
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

Base.convert(::Type{XRational32}, x::XRational32) = x
Base.convert(::Type{XRational32}, x::Integer) = XRational32(x)
Base.convert(::Type{XRational32}, x::Rational32) = XRational32(x)
Base.convert(::Type{XRational32}, x::Rational{<:Integer}) = XRational32(x)
Base.convert(::Type{Float64}, x::XRational32) = isnan(x) ? Base.NaN : isinf(x) ? (x.num > 0 ? Base.Inf : -Base.Inf) : Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::XRational32) = isnan(x) ? Float32(Base.NaN) : isinf(x) ? (x.num > 0 ? Float32(Base.Inf) : Float32(-Base.Inf)) : Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::XRational32) = isnan(x) ? BigFloat(Base.NaN) : isinf(x) ? (x.num > 0 ? BigFloat(Base.Inf) : BigFloat(-Base.Inf)) : BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational32}, x::XRational32) = isfinite(x) ? _finite32(x) : throw(InexactError(:convert, Rational32, x))
Base.convert(::Type{Rational{Int32}}, x::XRational32) = isfinite(x) ? (numerator(x) // denominator(x)) : throw(InexactError(:convert, Rational{Int32}, x))

Base.promote_rule(::Type{XRational32}, ::Type{<:Integer}) = XRational32
Base.promote_rule(::Type{XRational32}, ::Type{Rational32}) = XRational32
Base.promote_rule(::Type{XRational32}, ::Type{XRational32}) = XRational32

#===
Unary operations
===#

Base.abs(x::XRational32) = isnan(x) ? x : isinf(x) ? posinf(XRational32) : signbit(x) ? _from_raw32(-x.num, x.den) : x
Base.:-(x::XRational32) = isnan(x) ? x : _from_raw32(-x.num, x.den)
Base.inv(x::XRational32) = isnan(x) ? x : isinf(x) ? zero(XRational32) : iszero(x) ? posinf(XRational32) : XRational32(x.den, x.num)
Base.copysign(x::XRational32, y::Real) = isnan(x) ? x : (signbit(x) == signbit(y) ? x : -x)
Base.flipsign(x::XRational32, y::Real) = isnan(x) ? x : (signbit(y) ? -x : x)

#===
Arithmetic — lazy normalization, Int64 intermediates
===#

@inline function Base.:+(x::XRational32, y::XRational32)
    if x.den != 0 && y.den != 0
        n = Int64(x.num) * Int64(y.den) + Int64(y.num) * Int64(x.den)
        d = Int64(x.den) * Int64(y.den)
        return _raw_or_normalize_f32(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational32)
    elseif isinf(x) || isinf(y)
        return isinf(x) && isinf(y) && _signnum(x) != _signnum(y) ? nan(XRational32) : (isinf(x) ? x : y)
    end
end

@inline function Base.:-(x::XRational32, y::XRational32)
    if x.den != 0 && y.den != 0
        n = Int64(x.num) * Int64(y.den) - Int64(y.num) * Int64(x.den)
        d = Int64(x.den) * Int64(y.den)
        return _raw_or_normalize_f32(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational32)
    elseif isinf(x)
        return isinf(y) && _signnum(x) == _signnum(y) ? nan(XRational32) : x
    elseif isinf(y)
        return _from_raw32(Int32(-_signnum(y)), Int32(0))
    end
end

@inline function Base.:*(x::XRational32, y::XRational32)
    if x.den != 0 && y.den != 0
        n = Int64(x.num) * Int64(y.num)
        n == 0 && return _from_raw32(Int32(0), Int32(1))
        d = Int64(x.den) * Int64(y.den)
        return _raw_or_normalize_f32(n, d)
    elseif (x.den == 0 && x.num == 0) || (y.den == 0 && y.num == 0)
        return nan(XRational32)
    elseif (x.den == 0 && x.num != 0 && y.den != 0 && y.num == 0) ||
           (y.den == 0 && y.num != 0 && x.den != 0 && x.num == 0)
        return nan(XRational32)
    else
        return _from_raw32(Int32(_signnum(x) * _signnum(y)), Int32(0))
    end
end

@inline function Base.:/(x::XRational32, y::XRational32)
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
        return nan(XRational32)
    elseif isinf(x) && isinf(y)
        return nan(XRational32)
    elseif iszero(y)
        return iszero(x) ? nan(XRational32) : _from_raw32(Int32(_signnum(x)), Int32(0))
    elseif isinf(y)
        return isinf(x) ? nan(XRational32) : zero(XRational32)
    elseif isinf(x)
        return _from_raw32(Int32(_signnum(x) * _signnum(y)), Int32(0))
    end
end

# Quotient/remainder family — normalizes operands via _finite32 then delegates.
function Base.rem(x::XRational32, y::XRational32)
    if _finite_nonzero_divisor(x, y)
        r = rem(_finite32(x), _finite32(y))
        return XRational32(r)
    elseif _invalid_divisor_args(x, y)
        return nan(XRational32)
    end
end

function Base.mod(x::XRational32, y::XRational32)
    if _finite_nonzero_divisor(x, y)
        r = mod(_finite32(x), _finite32(y))
        return XRational32(r)
    elseif _invalid_divisor_args(x, y)
        return nan(XRational32)
    end
end

function Base.fld(x::XRational32, y::XRational32)
    if _finite_nonzero_divisor(x, y)
        return fld(_finite32(x), _finite32(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function Base.cld(x::XRational32, y::XRational32)
    if _finite_nonzero_divisor(x, y)
        return cld(_finite32(x), _finite32(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function Base.divrem(x::XRational32, y::XRational32)
    if _finite_nonzero_divisor(x, y)
        q, r = divrem(_finite32(x), _finite32(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function Base.fldmod(x::XRational32, y::XRational32)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod(_finite32(x), _finite32(y))
        return q, r
    end
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::XRational32, y::XRational32)
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

Base.muladd(x::XRational32, y::XRational32, z::XRational32) = x * y + z
function Base.fma(x::XRational32, y::XRational32, z::XRational32)
    if _both_finite(x, y) && z.den != 0
        return XRational32(fma(_finite32(x), _finite32(y), _finite32(z)))
    end
    return muladd(x, y, z)
end

function Base.:^(x::XRational32, p::Integer)
    if p == 0
        return one(XRational32)
    elseif p < 0
        return inv(x)^(-p)
    end

    result = one(XRational32)
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
        Base.$op(x::XRational32, y::Integer) = $op(x, XRational32(y))
        Base.$op(x::Integer, y::XRational32) = $op(XRational32(x), y)
        Base.$op(x::XRational32, y::Rational32) = $op(x, XRational32(y))
        Base.$op(x::Rational32, y::XRational32) = $op(XRational32(x), y)
    end
end

#===
Mixed quotient/remainder with integers and Rational32
===#

Base.rem(x::XRational32, y::Integer) = rem(x, XRational32(y))
Base.rem(x::Integer, y::XRational32) = rem(XRational32(x), y)
Base.rem(x::XRational32, y::Rational32) = rem(x, XRational32(y))
Base.rem(x::Rational32, y::XRational32) = rem(XRational32(x), y)
Base.mod(x::XRational32, y::Integer) = mod(x, XRational32(y))
Base.mod(x::Integer, y::XRational32) = mod(XRational32(x), y)
Base.mod(x::XRational32, y::Rational32) = mod(x, XRational32(y))
Base.mod(x::Rational32, y::XRational32) = mod(XRational32(x), y)
Base.fld(x::XRational32, y::Integer) = fld(x, XRational32(y))
Base.fld(x::Integer, y::XRational32) = fld(XRational32(x), y)
Base.fld(x::XRational32, y::Rational32) = fld(x, XRational32(y))
Base.fld(x::Rational32, y::XRational32) = fld(XRational32(x), y)
Base.cld(x::XRational32, y::Integer) = cld(x, XRational32(y))
Base.cld(x::Integer, y::XRational32) = cld(XRational32(x), y)
Base.cld(x::XRational32, y::Rational32) = cld(x, XRational32(y))
Base.cld(x::Rational32, y::XRational32) = cld(XRational32(x), y)
Base.divrem(x::XRational32, y::Integer) = divrem(x, XRational32(y))
Base.divrem(x::Integer, y::XRational32) = divrem(XRational32(x), y)
Base.divrem(x::XRational32, y::Rational32) = divrem(x, XRational32(y))
Base.divrem(x::Rational32, y::XRational32) = divrem(XRational32(x), y)
Base.fldmod(x::XRational32, y::Integer) = fldmod(x, XRational32(y))
Base.fldmod(x::Integer, y::XRational32) = fldmod(XRational32(x), y)
Base.fldmod(x::XRational32, y::Rational32) = fldmod(x, XRational32(y))
Base.fldmod(x::Rational32, y::XRational32) = fldmod(XRational32(x), y)
Base.fldmod1(x::XRational32, y::Integer) = fldmod1(x, XRational32(y))
Base.fldmod1(x::Integer, y::XRational32) = fldmod1(XRational32(x), y)
Base.fldmod1(x::XRational32, y::Rational32) = fldmod1(x, XRational32(y))
Base.fldmod1(x::Rational32, y::XRational32) = fldmod1(XRational32(x), y)

#===
Mixed fused multiply-add
===#

Base.muladd(x::XRational32, y::XRational32, z::Integer) = muladd(x, y, XRational32(z))
Base.muladd(x::XRational32, y::Integer, z::XRational32) = muladd(x, XRational32(y), z)
Base.muladd(x::Integer, y::XRational32, z::XRational32) = muladd(XRational32(x), y, z)
Base.muladd(x::XRational32, y::XRational32, z::Rational32) = muladd(x, y, XRational32(z))
Base.fma(x::XRational32, y::XRational32, z::Integer) = fma(x, y, XRational32(z))
Base.fma(x::XRational32, y::Integer, z::XRational32) = fma(x, XRational32(y), z)
Base.fma(x::Integer, y::XRational32, z::XRational32) = fma(XRational32(x), y, z)
Base.fma(x::XRational32, y::XRational32, z::Rational32) = fma(x, y, XRational32(z))

#===
Equality, ordering — uses cross-multiplication (no normalization needed)
===#

@inline function Base.:(==)(x::XRational32, y::XRational32)
    (isnan(x) || isnan(y)) && return false
    (x.den == 0 || y.den == 0) && return x.num == y.num && x.den == y.den
    # Finite: cross-multiply in Int64 — always exact for Int32 operands.
    return Int64(x.num) * Int64(y.den) == Int64(y.num) * Int64(x.den)
end
Base.:(==)(x::XRational32, y::Integer) = x == XRational32(y)
Base.:(==)(x::Integer, y::XRational32) = XRational32(x) == y

function Base.isless(x::XRational32, y::XRational32)
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

Base.:(<)(x::XRational32, y::XRational32) = !isnan(x) && !isnan(y) && isless(x, y)
Base.:(<=)(x::XRational32, y::XRational32) = !isnan(x) && !isnan(y) && (x == y || isless(x, y))
Base.:(>)(x::XRational32, y::XRational32) = y < x
Base.:(>=)(x::XRational32, y::XRational32) = y <= x

function Base.hash(x::XRational32, h::UInt)
    n = _normalize(x)
    return hash((n.num, n.den), h)
end

Base.float(x::XRational32) = Float64(x)

function Base.round(::Type{T}, x::XRational32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:round, T, x))
    return round(T, x.num / x.den)
end

function Base.trunc(::Type{T}, x::XRational32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:trunc, T, x))
    return trunc(T, x.num / x.den)
end

function Base.floor(::Type{T}, x::XRational32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:floor, T, x))
    return floor(T, x.num / x.den)
end

function Base.ceil(::Type{T}, x::XRational32) where {T<:Integer}
    isfinite(x) || throw(InexactError(:ceil, T, x))
    return ceil(T, x.num / x.den)
end

Base.trunc(x::XRational32) = isfinite(x) ? XRational32(trunc(Int64, x), 1) : nan(XRational32)
Base.floor(x::XRational32) = isfinite(x) ? XRational32(floor(Int64, x), 1) : nan(XRational32)
Base.ceil(x::XRational32) = isfinite(x) ? XRational32(ceil(Int64, x), 1) : nan(XRational32)

export XRational32, finite, isfinite, isinf, isnan

end # module
