module XRational128s

using BitIntegers: Int256
const Rational128 = Rational{Int128}

#===
Public type — lazy normalization
===#

"""
    XRational128 <: Real

Like `XRational128` but delays GCD normalization until it is actually
required (display, hashing, `numerator`/`denominator`, conversion). Arithmetic
stores results with `den > 0` and correct sign but **may leave a common factor
between `|num|` and `den`**.

Special-value encoding is identical to `XRational128`:

- `0//0`  => NaN
- `1//0`  => Inf
- `-1//0` => -Inf

Arithmetic that overflows `Int128` after GCD reduction saturates to
`Inf` / `-Inf` / `NaN` as appropriate.
"""
struct XRational128 <: Real
    num::Int128
    den::Int128

    XRational128(num::Int128, den::Int128, ::Val{:raw}) = new(num, den)

    function XRational128(num::Integer, den::Integer)
        num == typemin(Int128) && throw(OverflowError("typemin(Int128) is not allowed"))
        den == typemin(Int128) && throw(OverflowError("typemin(Int128) is not allowed"))
        if den == 0
            if num == 0
                return new(Int128(0), Int128(0))
            elseif num > 0
                return new(Int128(1), Int128(0))
            else
                return new(Int128(-1), Int128(0))
            end
        end

        if den < 0
            num = -num
            den = -den
        end

        if num == 0
            return new(Int128(0), Int128(1))
        end

        typemin(Int128) < num <= typemax(Int128) || throw(OverflowError("numerator does not fit in Int128"))
        den <= typemax(Int128) || throw(OverflowError("denominator does not fit in Int128"))

        return new(Int128(num), Int128(den))
    end
end

XRational128(n::Integer) = XRational128(n, 1)
XRational128(x::Rational128) = _from_raw128(x.num, x.den)
XRational128(x::Rational{<:Integer}) = XRational128(numerator(x), denominator(x))

function XRational128(x::AbstractFloat)
    isnan(x) && return XRational128(0, 0)
    isinf(x) && return x > 0 ? XRational128(1, 0) : XRational128(-1, 0)
    r = rationalize(Int128, x)
    XRational128(r.num, r.den)
end

#===
Internal raw constructor and normalizer
===#

@inline _from_raw128(num::Int128, den::Int128) = XRational128(num, den, Val(:raw))

@inline function _normalize(x::XRational128)
    x.den == 0 && return x
    x.num == 0 && return _from_raw128(Int128(0), Int128(1))
    g = gcd(abs(x.num), x.den)
    return _from_raw128(div(x.num, g), div(x.den, g))
end

#===
Predicates and basic properties
===#

finite(x::XRational128) = x.den != 0
Base.isfinite(x::XRational128) = x.den != 0
Base.isinf(x::XRational128) = x.den == 0 && x.num != 0
Base.isnan(x::XRational128) = x.den == 0 && x.num == 0
Base.iszero(x::XRational128) = x.num == 0 && x.den != 0
Base.isone(x::XRational128) = x.den > 0 && x.num == x.den
Base.isinteger(x::XRational128) = x.den > 0 && rem(x.num, x.den) == 0
Base.signbit(x::XRational128) = x.num < 0
Base.sign(x::XRational128) = isnan(x) ? x : (iszero(x) ? zero(x) : XRational128(sign(x.num), 1))

Base.zero(::Type{XRational128}) = _from_raw128(Int128(0), Int128(1))
Base.zero(::XRational128) = _from_raw128(Int128(0), Int128(1))
Base.one(::Type{XRational128}) = _from_raw128(Int128(1), Int128(1))
Base.one(::XRational128) = _from_raw128(Int128(1), Int128(1))
Base.typemin(::Type{XRational128}) = _from_raw128(Int128(-1), Int128(0))
Base.typemax(::Type{XRational128}) = _from_raw128(Int128(1), Int128(0))

function Base.numerator(x::XRational128)
    n = _normalize(x)
    return n.num
end

function Base.denominator(x::XRational128)
    n = _normalize(x)
    return n.den
end

nan(::Type{XRational128}) = _from_raw128(Int128(0), Int128(0))
inf(::Type{XRational128}) = _from_raw128(Int128(1), Int128(0))
posinf(::Type{XRational128}) = _from_raw128(Int128(1), Int128(0))
neginf(::Type{XRational128}) = _from_raw128(Int128(-1), Int128(0))

const NaN = nan
const Inf = inf
const NegInf = neginf

#===
Internal helpers
===#

@inline _signnum(x::XRational128) = x.num > 0 ? 1 : (x.num < 0 ? -1 : 0)
@inline _both_finite(x::XRational128, y::XRational128) = x.den != 0 && y.den != 0
@inline _finite_nonzero_divisor(x::XRational128, y::XRational128) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::XRational128, y::XRational128) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)

@inline function _overflow_policy_f128(num::Integer, den::Integer)
    if den == 0
        return num == 0 ? nan(XRational128) : _from_raw128(Int128(sign(num)), Int128(0))
    end
    if den < 0
        num = -num
    end
    return num == 0 ? zero(XRational128) : _from_raw128(Int128(sign(num)), Int128(0))
end

@inline function _raw_or_normalize_f128(n::Int256, d::Int256)
    if n == 0
        return _from_raw128(Int128(0), Int128(1))
    end
    if typemin(Int128) < n <= typemax(Int128) && d <= typemax(Int128)
        return _from_raw128(Int128(n), Int128(d))
    end
    g = gcd(abs(n), d)
    nn = div(n, g)
    dd = div(d, g)
    (typemin(Int128) < nn <= typemax(Int128) && dd <= typemax(Int128)) ||
        return _overflow_policy_f128(nn, dd)
    return _from_raw128(Int128(nn), Int128(dd))
end

@inline function _raw_or_policy_f128(n::Int256, d::Int256)
    (typemin(Int128) < n <= typemax(Int128) && typemin(Int128) < d <= typemax(Int128)) ||
        return _overflow_policy_f128(n, d)
    return _from_raw128(Int128(n), Int128(d))
end

@inline _finite128(x::XRational128) = Rational128(x.num, x.den)

#===
Display — normalizes before printing
===#

function Base.show(io::IO, x::XRational128)
    if isnan(x)
        print(io, "NaNQ128")
    elseif isinf(x)
        print(io, x.num > 0 ? "InfQ128" : "-InfQ128")
    else
        n = _normalize(x)
        print(io, n.num, "//", n.den)
    end
end

#===
Conversion and promotion
===#

Base.convert(::Type{XRational128}, x::XRational128) = x
Base.convert(::Type{XRational128}, x::Integer) = XRational128(x)
Base.convert(::Type{XRational128}, x::Rational128) = XRational128(x)
Base.convert(::Type{XRational128}, x::Rational{<:Integer}) = XRational128(x)
Base.convert(::Type{Float64}, x::XRational128) = isnan(x) ? Base.NaN : isinf(x) ? (x.num > 0 ? Base.Inf : -Base.Inf) : Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::XRational128) = isnan(x) ? Float32(Base.NaN) : isinf(x) ? (x.num > 0 ? Float32(Base.Inf) : Float32(-Base.Inf)) : Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::XRational128) = isnan(x) ? BigFloat(Base.NaN) : isinf(x) ? (x.num > 0 ? BigFloat(Base.Inf) : BigFloat(-Base.Inf)) : BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational{Int128}}, x::XRational128) = isfinite(x) ? Rational128(x.num, x.den) : throw(InexactError(:convert, Rational{Int128}, x))

Base.Float32(x::XRational128) = convert(Float32, x)
Base.Float64(x::XRational128) = convert(Float64, x)
Base.BigFloat(x::XRational128) = convert(BigFloat, x)

Base.promote_rule(::Type{XRational128}, ::Type{<:Integer}) = XRational128
Base.promote_rule(::Type{XRational128}, ::Type{Rational128}) = XRational128
Base.promote_rule(::Type{XRational128}, ::Type{XRational128}) = XRational128

#===
Unary operations
===#

Base.abs(x::XRational128) = isnan(x) ? x : isinf(x) ? posinf(XRational128) : signbit(x) ? _from_raw128(-x.num, x.den) : x
Base.:-(x::XRational128) = isnan(x) ? x : _from_raw128(-x.num, x.den)
Base.inv(x::XRational128) = isnan(x) ? x : isinf(x) ? zero(XRational128) : iszero(x) ? posinf(XRational128) : XRational128(x.den, x.num)
Base.copysign(x::XRational128, y::Real) = isnan(x) ? x : (signbit(x) == signbit(y) ? x : -x)
Base.flipsign(x::XRational128, y::Real) = isnan(x) ? x : (signbit(y) ? -x : x)

#===
Arithmetic — lazy normalization
===#

@inline function Base.:+(x::XRational128, y::XRational128)
    if x.den != 0 && y.den != 0
        n = Int256(x.num) * Int256(y.den) + Int256(y.num) * Int256(x.den)
        d = Int256(x.den) * Int256(y.den)
        return _raw_or_normalize_f128(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational128)
    elseif isinf(x) || isinf(y)
        return isinf(x) && isinf(y) && _signnum(x) != _signnum(y) ? nan(XRational128) : (isinf(x) ? x : y)
    end
end

@inline function Base.:-(x::XRational128, y::XRational128)
    if x.den != 0 && y.den != 0
        n = Int256(x.num) * Int256(y.den) - Int256(y.num) * Int256(x.den)
        d = Int256(x.den) * Int256(y.den)
        return _raw_or_normalize_f128(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational128)
    elseif isinf(x)
        return isinf(y) && _signnum(x) == _signnum(y) ? nan(XRational128) : x
    elseif isinf(y)
        return _from_raw128(Int128(-_signnum(y)), Int128(0))
    end
end

@inline function Base.:*(x::XRational128, y::XRational128)
    if x.den != 0 && y.den != 0
        n = Int256(x.num) * Int256(y.num)
        n == 0 && return _from_raw128(Int128(0), Int128(1))
        d = Int256(x.den) * Int256(y.den)
        return _raw_or_normalize_f128(n, d)
    elseif (x.den == 0 && x.num == 0) || (y.den == 0 && y.num == 0)
        return nan(XRational128)
    elseif (x.den == 0 && x.num != 0 && y.den != 0 && y.num == 0) ||
           (y.den == 0 && y.num != 0 && x.den != 0 && x.num == 0)
        return nan(XRational128)
    else
        return _from_raw128(Int128(_signnum(x) * _signnum(y)), Int128(0))
    end
end

@inline function Base.:/(x::XRational128, y::XRational128)
    if x.den != 0 && y.den != 0 && y.num != 0
        n = Int256(x.num) * Int256(y.den)
        n == 0 && return _from_raw128(Int128(0), Int128(1))
        d = Int256(x.den) * Int256(y.num)
        if d < 0
            n = -n
            d = -d
        end
        return _raw_or_normalize_f128(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational128)
    elseif isinf(x) && isinf(y)
        return nan(XRational128)
    elseif iszero(y)
        return iszero(x) ? nan(XRational128) : _from_raw128(Int128(_signnum(x)), Int128(0))
    elseif isinf(y)
        return isinf(x) ? nan(XRational128) : zero(XRational128)
    elseif isinf(x)
        return _from_raw128(Int128(_signnum(x) * _signnum(y)), Int128(0))
    end
end

function Base.rem(x::XRational128, y::XRational128)
    if _finite_nonzero_divisor(x, y)
        r = rem(_finite128(x), _finite128(y))
        return XRational128(r)
    elseif _invalid_divisor_args(x, y)
        return nan(XRational128)
    end
end

function Base.mod(x::XRational128, y::XRational128)
    if _finite_nonzero_divisor(x, y)
        r = mod(_finite128(x), _finite128(y))
        return XRational128(r)
    elseif _invalid_divisor_args(x, y)
        return nan(XRational128)
    end
end

function Base.fld(x::XRational128, y::XRational128)
    if _finite_nonzero_divisor(x, y)
        return fld(_finite128(x), _finite128(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function Base.cld(x::XRational128, y::XRational128)
    if _finite_nonzero_divisor(x, y)
        return cld(_finite128(x), _finite128(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function Base.divrem(x::XRational128, y::XRational128)
    if _finite_nonzero_divisor(x, y)
        q, r = divrem(_finite128(x), _finite128(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function Base.fldmod(x::XRational128, y::XRational128)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod(_finite128(x), _finite128(y))
        return q, r
    end
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::XRational128, y::XRational128)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod1(_finite128(x), _finite128(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fldmod1 requires finite nonzero divisor"))
    end
end

#===
Fused multiply-add and powers
===#

Base.muladd(x::XRational128, y::XRational128, z::XRational128) = x * y + z
function Base.fma(x::XRational128, y::XRational128, z::XRational128)
    if _both_finite(x, y) && z.den != 0
        return XRational128(fma(_finite128(x), _finite128(y), _finite128(z)))
    end
    return muladd(x, y, z)
end

function Base.:^(x::XRational128, p::Integer)
    if p == 0
        return one(XRational128)
    elseif p < 0
        return inv(x)^(-p)
    end

    result = one(XRational128)
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
Mixed arithmetic with integers and Rational128
===#

for op in (:+, :-, :*, :/)
    @eval begin
        Base.$op(x::XRational128, y::Integer) = $op(x, XRational128(y))
        Base.$op(x::Integer, y::XRational128) = $op(XRational128(x), y)
        Base.$op(x::XRational128, y::Rational128) = $op(x, XRational128(y))
        Base.$op(x::Rational128, y::XRational128) = $op(XRational128(x), y)
    end
end

#===
Mixed quotient/remainder with integers and Rational128
===#

Base.rem(x::XRational128, y::Integer) = rem(x, XRational128(y))
Base.rem(x::Integer, y::XRational128) = rem(XRational128(x), y)
Base.rem(x::XRational128, y::Rational128) = rem(x, XRational128(y))
Base.rem(x::Rational128, y::XRational128) = rem(XRational128(x), y)
Base.mod(x::XRational128, y::Integer) = mod(x, XRational128(y))
Base.mod(x::Integer, y::XRational128) = mod(XRational128(x), y)
Base.mod(x::XRational128, y::Rational128) = mod(x, XRational128(y))
Base.mod(x::Rational128, y::XRational128) = mod(XRational128(x), y)
Base.fld(x::XRational128, y::Integer) = fld(x, XRational128(y))
Base.fld(x::Integer, y::XRational128) = fld(XRational128(x), y)
Base.fld(x::XRational128, y::Rational128) = fld(x, XRational128(y))
Base.fld(x::Rational128, y::XRational128) = fld(XRational128(x), y)
Base.cld(x::XRational128, y::Integer) = cld(x, XRational128(y))
Base.cld(x::Integer, y::XRational128) = cld(XRational128(x), y)
Base.cld(x::XRational128, y::Rational128) = cld(x, XRational128(y))
Base.cld(x::Rational128, y::XRational128) = cld(XRational128(x), y)
Base.divrem(x::XRational128, y::Integer) = divrem(x, XRational128(y))
Base.divrem(x::Integer, y::XRational128) = divrem(XRational128(x), y)
Base.divrem(x::XRational128, y::Rational128) = divrem(x, XRational128(y))
Base.divrem(x::Rational128, y::XRational128) = divrem(XRational128(x), y)
Base.fldmod(x::XRational128, y::Integer) = fldmod(x, XRational128(y))
Base.fldmod(x::Integer, y::XRational128) = fldmod(XRational128(x), y)
Base.fldmod(x::XRational128, y::Rational128) = fldmod(x, XRational128(y))
Base.fldmod(x::Rational128, y::XRational128) = fldmod(XRational128(x), y)
Base.fldmod1(x::XRational128, y::Integer) = fldmod1(x, XRational128(y))
Base.fldmod1(x::Integer, y::XRational128) = fldmod1(XRational128(x), y)
Base.fldmod1(x::XRational128, y::Rational128) = fldmod1(x, XRational128(y))
Base.fldmod1(x::Rational128, y::XRational128) = fldmod1(XRational128(x), y)

#===
Mixed fused multiply-add
===#

Base.muladd(x::XRational128, y::XRational128, z::Integer) = muladd(x, y, XRational128(z))
Base.muladd(x::XRational128, y::Integer, z::XRational128) = muladd(x, XRational128(y), z)
Base.muladd(x::Integer, y::XRational128, z::XRational128) = muladd(XRational128(x), y, z)
Base.muladd(x::XRational128, y::XRational128, z::Rational128) = muladd(x, y, XRational128(z))
Base.fma(x::XRational128, y::XRational128, z::Integer) = fma(x, y, XRational128(z))
Base.fma(x::XRational128, y::Integer, z::XRational128) = fma(x, XRational128(y), z)
Base.fma(x::Integer, y::XRational128, z::XRational128) = fma(XRational128(x), y, z)
Base.fma(x::XRational128, y::XRational128, z::Rational128) = fma(x, y, XRational128(z))

#===
Equality, ordering — uses cross-multiplication (no normalization needed)
===#

@inline function Base.:(==)(x::XRational128, y::XRational128)
    (isnan(x) || isnan(y)) && return false
    (x.den == 0 || y.den == 0) && return x.num == y.num && x.den == y.den
    return Int256(x.num) * Int256(y.den) == Int256(y.num) * Int256(x.den)
end
Base.:(==)(x::XRational128, y::Integer) = x == XRational128(y)
Base.:(==)(x::Integer, y::XRational128) = XRational128(x) == y

function Base.isless(x::XRational128, y::XRational128)
    if isnan(x)
        return false
    elseif isnan(y)
        return true
    elseif isinf(x)
        return x.num < 0 && !(isinf(y) && y.num < 0)
    elseif isinf(y)
        return y.num > 0 && !(isinf(x) && x.num > 0)
    else
        return Int256(x.num) * Int256(y.den) < Int256(y.num) * Int256(x.den)
    end
end

Base.:(<)(x::XRational128, y::XRational128) = !isnan(x) && !isnan(y) && isless(x, y)
Base.:(<=)(x::XRational128, y::XRational128) = !isnan(x) && !isnan(y) && (x == y || isless(x, y))
Base.:(>)(x::XRational128, y::XRational128) = y < x
Base.:(>=)(x::XRational128, y::XRational128) = y <= x

function Base.hash(x::XRational128, h::UInt)
    n = _normalize(x)
    return hash((n.num, n.den), h)
end

Base.float(x::XRational128) = Float64(x)

function Base.round(::Type{T}, x::XRational128) where {T<:Integer}
    isfinite(x) || throw(InexactError(:round, T, x))
    return round(T, x.num / x.den)
end

function Base.trunc(::Type{T}, x::XRational128) where {T<:Integer}
    isfinite(x) || throw(InexactError(:trunc, T, x))
    return trunc(T, x.num / x.den)
end

function Base.floor(::Type{T}, x::XRational128) where {T<:Integer}
    isfinite(x) || throw(InexactError(:floor, T, x))
    return floor(T, x.num / x.den)
end

function Base.ceil(::Type{T}, x::XRational128) where {T<:Integer}
    isfinite(x) || throw(InexactError(:ceil, T, x))
    return ceil(T, x.num / x.den)
end

Base.trunc(x::XRational128) = isfinite(x) ? XRational128(trunc(Int256, x), 1) : nan(XRational128)
Base.floor(x::XRational128) = isfinite(x) ? XRational128(floor(Int256, x), 1) : nan(XRational128)
Base.ceil(x::XRational128) = isfinite(x) ? XRational128(ceil(Int256, x), 1) : nan(XRational128)

export XRational128, finite, isfinite, isinf, isnan

end # module