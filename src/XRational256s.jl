module XRational256s

using BitIntegers: Int256, Int512
const Rational256 = Rational{Int256}

#===
Public type — lazy normalization
===#

struct XRational256 <: Real
    num::Int256
    den::Int256

    XRational256(num::Int256, den::Int256, ::Val{:raw}) = new(num, den)

    function XRational256(num::Integer, den::Integer)
        num == typemin(Int256) && throw(OverflowError("typemin(Int256) is not allowed"))
        den == typemin(Int256) && throw(OverflowError("typemin(Int256) is not allowed"))
        if den == 0
            if num == 0
                return new(Int256(0), Int256(0))
            elseif num > 0
                return new(Int256(1), Int256(0))
            else
                return new(Int256(-1), Int256(0))
            end
        end

        if den < 0
            num = -num
            den = -den
        end

        if num == 0
            return new(Int256(0), Int256(1))
        end

        typemin(Int256) < num <= typemax(Int256) || throw(OverflowError("numerator does not fit in Int256"))
        den <= typemax(Int256) || throw(OverflowError("denominator does not fit in Int256"))

        return new(Int256(num), Int256(den))
    end
end

XRational256(n::Integer) = XRational256(n, 1)
XRational256(x::Rational256) = _from_raw256(x.num, x.den)
XRational256(x::Rational{<:Integer}) = XRational256(numerator(x), denominator(x))

function XRational256(x::AbstractFloat)
    isnan(x) && return XRational256(0, 0)
    isinf(x) && return x > 0 ? XRational256(1, 0) : XRational256(-1, 0)
    r = rationalize(Int256, x)
    XRational256(r.num, r.den)
end

#===
Internal raw constructor and normalizer
===#

@inline _from_raw256(num::Int256, den::Int256) = XRational256(num, den, Val(:raw))

@inline function _normalize(x::XRational256)
    x.den == 0 && return x
    x.num == 0 && return _from_raw256(Int256(0), Int256(1))
    g = gcd(abs(x.num), x.den)
    return _from_raw256(div(x.num, g), div(x.den, g))
end

#===
Predicates and basic properties
===#

finite(x::XRational256) = x.den != 0
Base.isfinite(x::XRational256) = x.den != 0
Base.isinf(x::XRational256) = x.den == 0 && x.num != 0
Base.isnan(x::XRational256) = x.den == 0 && x.num == 0
Base.iszero(x::XRational256) = x.num == 0 && x.den != 0
Base.isone(x::XRational256) = x.den > 0 && x.num == x.den
Base.isinteger(x::XRational256) = x.den > 0 && rem(x.num, x.den) == 0
Base.signbit(x::XRational256) = x.num < 0
Base.sign(x::XRational256) = isnan(x) ? x : (iszero(x) ? zero(x) : XRational256(sign(x.num), 1))

Base.zero(::Type{XRational256}) = _from_raw256(Int256(0), Int256(1))
Base.zero(::XRational256) = _from_raw256(Int256(0), Int256(1))
Base.one(::Type{XRational256}) = _from_raw256(Int256(1), Int256(1))
Base.one(::XRational256) = _from_raw256(Int256(1), Int256(1))
Base.typemin(::Type{XRational256}) = _from_raw256(Int256(-1), Int256(0))
Base.typemax(::Type{XRational256}) = _from_raw256(Int256(1), Int256(0))

function Base.numerator(x::XRational256)
    n = _normalize(x)
    return n.num
end

function Base.denominator(x::XRational256)
    n = _normalize(x)
    return n.den
end

nan(::Type{XRational256}) = _from_raw256(Int256(0), Int256(0))
inf(::Type{XRational256}) = _from_raw256(Int256(1), Int256(0))
posinf(::Type{XRational256}) = _from_raw256(Int256(1), Int256(0))
neginf(::Type{XRational256}) = _from_raw256(Int256(-1), Int256(0))

const NaN = nan
const Inf = inf
const NegInf = neginf

#===
Internal helpers
===#

@inline _signnum(x::XRational256) = x.num > 0 ? 1 : (x.num < 0 ? -1 : 0)
@inline _both_finite(x::XRational256, y::XRational256) = x.den != 0 && y.den != 0
@inline _finite_nonzero_divisor(x::XRational256, y::XRational256) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::XRational256, y::XRational256) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)

@inline function _overflow_policy_f256(num::Integer, den::Integer)
    if den == 0
        return num == 0 ? nan(XRational256) : _from_raw256(Int256(sign(num)), Int256(0))
    end
    if den < 0
        num = -num
    end
    return num == 0 ? zero(XRational256) : _from_raw256(Int256(sign(num)), Int256(0))
end

@inline function _raw_or_normalize_f256(n::Int512, d::Int512)
    if n == 0
        return _from_raw256(Int256(0), Int256(1))
    end
    if typemin(Int256) < n <= typemax(Int256) && d <= typemax(Int256)
        return _from_raw256(Int256(n), Int256(d))
    end
    g = gcd(abs(n), d)
    nn = div(n, g)
    dd = div(d, g)
    (typemin(Int256) < nn <= typemax(Int256) && dd <= typemax(Int256)) ||
        return _overflow_policy_f256(nn, dd)
    return _from_raw256(Int256(nn), Int256(dd))
end

@inline function _raw_or_policy_f256(n::Int512, d::Int512)
    (typemin(Int256) < n <= typemax(Int256) && typemin(Int256) < d <= typemax(Int256)) ||
        return _overflow_policy_f256(n, d)
    return _from_raw256(Int256(n), Int256(d))
end

@inline _finite256(x::XRational256) = Rational256(numerator(x), denominator(x))

#===
Display — normalizes before printing
===#

function Base.show(io::IO, x::XRational256)
    if isnan(x)
        print(io, "NaNQ256")
    elseif isinf(x)
        print(io, x.num > 0 ? "InfQ256" : "-InfQ256")
    else
        n = _normalize(x)
        print(io, n.num, "//", n.den)
    end
end

#===
Conversion and promotion
===#

Base.convert(::Type{XRational256}, x::XRational256) = x
Base.convert(::Type{XRational256}, x::Integer) = XRational256(x)
Base.convert(::Type{XRational256}, x::Rational256) = XRational256(x)
Base.convert(::Type{XRational256}, x::Rational{<:Integer}) = XRational256(x)
Base.convert(::Type{Float64}, x::XRational256) = isnan(x) ? Base.NaN : isinf(x) ? (x.num > 0 ? Base.Inf : -Base.Inf) : Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::XRational256) = isnan(x) ? Float32(Base.NaN) : isinf(x) ? (x.num > 0 ? Float32(Base.Inf) : Float32(-Base.Inf)) : Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::XRational256) = isnan(x) ? BigFloat(Base.NaN) : isinf(x) ? (x.num > 0 ? BigFloat(Base.Inf) : BigFloat(-Base.Inf)) : BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational{Int256}}, x::XRational256) = isfinite(x) ? (numerator(x) // denominator(x)) : throw(InexactError(:convert, Rational{Int256}, x))

Base.Float32(x::XRational256) = convert(Float32, x)
Base.Float64(x::XRational256) = convert(Float64, x)
Base.BigFloat(x::XRational256) = convert(BigFloat, x)

Base.promote_rule(::Type{XRational256}, ::Type{<:Integer}) = XRational256
Base.promote_rule(::Type{XRational256}, ::Type{Rational256}) = XRational256
Base.promote_rule(::Type{XRational256}, ::Type{XRational256}) = XRational256

#===
Unary operations
===#

Base.abs(x::XRational256) = isnan(x) ? x : isinf(x) ? posinf(XRational256) : signbit(x) ? _from_raw256(-x.num, x.den) : x
Base.:-(x::XRational256) = isnan(x) ? x : _from_raw256(-x.num, x.den)
Base.inv(x::XRational256) = isnan(x) ? x : isinf(x) ? zero(XRational256) : iszero(x) ? posinf(XRational256) : XRational256(x.den, x.num)
Base.copysign(x::XRational256, y::Real) = isnan(x) ? x : (signbit(x) == signbit(y) ? x : -x)
Base.flipsign(x::XRational256, y::Real) = isnan(x) ? x : (signbit(y) ? -x : x)

#===
Arithmetic — lazy normalization
===#

@inline function Base.:+(x::XRational256, y::XRational256)
    if x.den != 0 && y.den != 0
        n = Int512(x.num) * Int512(y.den) + Int512(y.num) * Int512(x.den)
        d = Int512(x.den) * Int512(y.den)
        return _raw_or_normalize_f256(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational256)
    elseif isinf(x) || isinf(y)
        return isinf(x) && isinf(y) && _signnum(x) != _signnum(y) ? nan(XRational256) : (isinf(x) ? x : y)
    end
end

@inline function Base.:-(x::XRational256, y::XRational256)
    if x.den != 0 && y.den != 0
        n = Int512(x.num) * Int512(y.den) - Int512(y.num) * Int512(x.den)
        d = Int512(x.den) * Int512(y.den)
        return _raw_or_normalize_f256(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational256)
    elseif isinf(x)
        return isinf(y) && _signnum(x) == _signnum(y) ? nan(XRational256) : x
    elseif isinf(y)
        return _from_raw256(Int256(-_signnum(y)), Int256(0))
    end
end

@inline function Base.:*(x::XRational256, y::XRational256)
    if x.den != 0 && y.den != 0
        n = Int512(x.num) * Int512(y.num)
        n == 0 && return _from_raw256(Int256(0), Int256(1))
        d = Int512(x.den) * Int512(y.den)
        return _raw_or_normalize_f256(n, d)
    elseif (x.den == 0 && x.num == 0) || (y.den == 0 && y.num == 0)
        return nan(XRational256)
    elseif (x.den == 0 && x.num != 0 && y.den != 0 && y.num == 0) ||
           (y.den == 0 && y.num != 0 && x.den != 0 && x.num == 0)
        return nan(XRational256)
    else
        return _from_raw256(Int256(_signnum(x) * _signnum(y)), Int256(0))
    end
end

@inline function Base.:/(x::XRational256, y::XRational256)
    if x.den != 0 && y.den != 0 && y.num != 0
        n = Int512(x.num) * Int512(y.den)
        n == 0 && return _from_raw256(Int256(0), Int256(1))
        d = Int512(x.den) * Int512(y.num)
        if d < 0
            n = -n
            d = -d
        end
        return _raw_or_normalize_f256(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational256)
    elseif isinf(x) && isinf(y)
        return nan(XRational256)
    elseif iszero(y)
        return iszero(x) ? nan(XRational256) : _from_raw256(Int256(_signnum(x)), Int256(0))
    elseif isinf(y)
        return isinf(x) ? nan(XRational256) : zero(XRational256)
    elseif isinf(x)
        return _from_raw256(Int256(_signnum(x) * _signnum(y)), Int256(0))
    end
end

function Base.rem(x::XRational256, y::XRational256)
    if _finite_nonzero_divisor(x, y)
        r = rem(_finite256(x), _finite256(y))
        return XRational256(r)
    elseif _invalid_divisor_args(x, y)
        return nan(XRational256)
    end
end

function Base.mod(x::XRational256, y::XRational256)
    if _finite_nonzero_divisor(x, y)
        r = mod(_finite256(x), _finite256(y))
        return XRational256(r)
    elseif _invalid_divisor_args(x, y)
        return nan(XRational256)
    end
end

function Base.fld(x::XRational256, y::XRational256)
    if _finite_nonzero_divisor(x, y)
        return fld(_finite256(x), _finite256(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function Base.cld(x::XRational256, y::XRational256)
    if _finite_nonzero_divisor(x, y)
        return cld(_finite256(x), _finite256(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function Base.divrem(x::XRational256, y::XRational256)
    if _finite_nonzero_divisor(x, y)
        q, r = divrem(_finite256(x), _finite256(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function Base.fldmod(x::XRational256, y::XRational256)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod(_finite256(x), _finite256(y))
        return q, r
    end
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::XRational256, y::XRational256)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod1(_finite256(x), _finite256(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fldmod1 requires finite nonzero divisor"))
    end
end

#===
Fused multiply-add and powers
===#

Base.muladd(x::XRational256, y::XRational256, z::XRational256) = x * y + z
function Base.fma(x::XRational256, y::XRational256, z::XRational256)
    if _both_finite(x, y) && z.den != 0
        return XRational256(fma(_finite256(x), _finite256(y), _finite256(z)))
    end
    return muladd(x, y, z)
end

function Base.:^(x::XRational256, p::Integer)
    if p == 0
        return one(XRational256)
    elseif p < 0
        return inv(x)^(-p)
    end

    result = one(XRational256)
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
Mixed arithmetic with integers and Rational256
===#

for op in (:+, :-, :*, :/)
    @eval begin
        Base.$op(x::XRational256, y::Integer) = $op(x, XRational256(y))
        Base.$op(x::Integer, y::XRational256) = $op(XRational256(x), y)
        Base.$op(x::XRational256, y::Rational256) = $op(x, XRational256(y))
        Base.$op(x::Rational256, y::XRational256) = $op(XRational256(x), y)
    end
end

#===
Mixed quotient/remainder with integers and Rational256
===#

Base.rem(x::XRational256, y::Integer) = rem(x, XRational256(y))
Base.rem(x::Integer, y::XRational256) = rem(XRational256(x), y)
Base.rem(x::XRational256, y::Rational256) = rem(x, XRational256(y))
Base.rem(x::Rational256, y::XRational256) = rem(XRational256(x), y)
Base.mod(x::XRational256, y::Integer) = mod(x, XRational256(y))
Base.mod(x::Integer, y::XRational256) = mod(XRational256(x), y)
Base.mod(x::XRational256, y::Rational256) = mod(x, XRational256(y))
Base.mod(x::Rational256, y::XRational256) = mod(XRational256(x), y)
Base.fld(x::XRational256, y::Integer) = fld(x, XRational256(y))
Base.fld(x::Integer, y::XRational256) = fld(XRational256(x), y)
Base.fld(x::XRational256, y::Rational256) = fld(x, XRational256(y))
Base.fld(x::Rational256, y::XRational256) = fld(XRational256(x), y)
Base.cld(x::XRational256, y::Integer) = cld(x, XRational256(y))
Base.cld(x::Integer, y::XRational256) = cld(XRational256(x), y)
Base.cld(x::XRational256, y::Rational256) = cld(x, XRational256(y))
Base.cld(x::Rational256, y::XRational256) = cld(XRational256(x), y)
Base.divrem(x::XRational256, y::Integer) = divrem(x, XRational256(y))
Base.divrem(x::Integer, y::XRational256) = divrem(XRational256(x), y)
Base.divrem(x::XRational256, y::Rational256) = divrem(x, XRational256(y))
Base.divrem(x::Rational256, y::XRational256) = divrem(XRational256(x), y)
Base.fldmod(x::XRational256, y::Integer) = fldmod(x, XRational256(y))
Base.fldmod(x::Integer, y::XRational256) = fldmod(XRational256(x), y)
Base.fldmod(x::XRational256, y::Rational256) = fldmod(x, XRational256(y))
Base.fldmod(x::Rational256, y::XRational256) = fldmod(XRational256(x), y)
Base.fldmod1(x::XRational256, y::Integer) = fldmod1(x, XRational256(y))
Base.fldmod1(x::Integer, y::XRational256) = fldmod1(XRational256(x), y)
Base.fldmod1(x::XRational256, y::Rational256) = fldmod1(x, XRational256(y))
Base.fldmod1(x::Rational256, y::XRational256) = fldmod1(XRational256(x), y)

#===
Mixed fused multiply-add
===#

Base.muladd(x::XRational256, y::XRational256, z::Integer) = muladd(x, y, XRational256(z))
Base.muladd(x::XRational256, y::Integer, z::XRational256) = muladd(x, XRational256(y), z)
Base.muladd(x::Integer, y::XRational256, z::XRational256) = muladd(XRational256(x), y, z)
Base.muladd(x::XRational256, y::XRational256, z::Rational256) = muladd(x, y, XRational256(z))
Base.fma(x::XRational256, y::XRational256, z::Integer) = fma(x, y, XRational256(z))
Base.fma(x::XRational256, y::Integer, z::XRational256) = fma(x, XRational256(y), z)
Base.fma(x::Integer, y::XRational256, z::XRational256) = fma(XRational256(x), y, z)
Base.fma(x::XRational256, y::XRational256, z::Rational256) = fma(x, y, XRational256(z))

#===
Equality, ordering — uses cross-multiplication (no normalization needed)
===#

@inline function Base.:(==)(x::XRational256, y::XRational256)
    (isnan(x) || isnan(y)) && return false
    (x.den == 0 || y.den == 0) && return x.num == y.num && x.den == y.den
    return Int512(x.num) * Int512(y.den) == Int512(y.num) * Int512(x.den)
end
Base.:(==)(x::XRational256, y::Integer) = x == XRational256(y)
Base.:(==)(x::Integer, y::XRational256) = XRational256(x) == y

function Base.isless(x::XRational256, y::XRational256)
    if isnan(x)
        return false
    elseif isnan(y)
        return true
    elseif isinf(x)
        return x.num < 0 && !(isinf(y) && y.num < 0)
    elseif isinf(y)
        return y.num > 0 && !(isinf(x) && x.num > 0)
    else
        return Int512(x.num) * Int512(y.den) < Int512(y.num) * Int512(x.den)
    end
end

Base.:(<)(x::XRational256, y::XRational256) = !isnan(x) && !isnan(y) && isless(x, y)
Base.:(<=)(x::XRational256, y::XRational256) = !isnan(x) && !isnan(y) && (x == y || isless(x, y))
Base.:(>)(x::XRational256, y::XRational256) = y < x
Base.:(>=)(x::XRational256, y::XRational256) = y <= x

function Base.hash(x::XRational256, h::UInt)
    n = _normalize(x)
    return hash((n.num, n.den), h)
end

Base.float(x::XRational256) = Float64(x)

function Base.round(::Type{T}, x::XRational256) where {T<:Integer}
    isfinite(x) || throw(InexactError(:round, T, x))
    return round(T, x.num / x.den)
end

function Base.trunc(::Type{T}, x::XRational256) where {T<:Integer}
    isfinite(x) || throw(InexactError(:trunc, T, x))
    return trunc(T, x.num / x.den)
end

function Base.floor(::Type{T}, x::XRational256) where {T<:Integer}
    isfinite(x) || throw(InexactError(:floor, T, x))
    return floor(T, x.num / x.den)
end

function Base.ceil(::Type{T}, x::XRational256) where {T<:Integer}
    isfinite(x) || throw(InexactError(:ceil, T, x))
    return ceil(T, x.num / x.den)
end

Base.trunc(x::XRational256) = isfinite(x) ? XRational256(trunc(Int512, x), 1) : nan(XRational256)
Base.floor(x::XRational256) = isfinite(x) ? XRational256(floor(Int512, x), 1) : nan(XRational256)
Base.ceil(x::XRational256) = isfinite(x) ? XRational256(ceil(Int512, x), 1) : nan(XRational256)

export XRational256, finite, isfinite, isinf, isnan

end # module