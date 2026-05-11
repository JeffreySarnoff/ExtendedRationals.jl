module XRational512s

using BitIntegers: Int512, Int1024
const Rational512 = Rational{Int512}

#===
Public type — lazy normalization
===#

struct XRational512 <: Real
    num::Int512
    den::Int512

    XRational512(num::Int512, den::Int512, ::Val{:raw}) = new(num, den)

    function XRational512(num::Integer, den::Integer)
        num == typemin(Int512) && throw(OverflowError("typemin(Int512) is not allowed"))
        den == typemin(Int512) && throw(OverflowError("typemin(Int512) is not allowed"))
        if den == 0
            if num == 0
                return new(Int512(0), Int512(0))
            elseif num > 0
                return new(Int512(1), Int512(0))
            else
                return new(Int512(-1), Int512(0))
            end
        end

        if den < 0
            num = -num
            den = -den
        end

        if num == 0
            return new(Int512(0), Int512(1))
        end

        typemin(Int512) < num <= typemax(Int512) || throw(OverflowError("numerator does not fit in Int512"))
        den <= typemax(Int512) || throw(OverflowError("denominator does not fit in Int512"))

        return new(Int512(num), Int512(den))
    end
end

XRational512(n::Integer) = XRational512(n, 1)
XRational512(x::Rational512) = _from_raw512(x.num, x.den)
XRational512(x::Rational{<:Integer}) = XRational512(numerator(x), denominator(x))

function XRational512(x::AbstractFloat)
    isnan(x) && return XRational512(0, 0)
    isinf(x) && return x > 0 ? XRational512(1, 0) : XRational512(-1, 0)
    r = rationalize(Int512, x)
    XRational512(r.num, r.den)
end

#===
Internal raw constructor and normalizer
===#

@inline _from_raw512(num::Int512, den::Int512) = XRational512(num, den, Val(:raw))

@inline function _normalize(x::XRational512)
    x.den == 0 && return x
    x.num == 0 && return _from_raw512(Int512(0), Int512(1))
    g = gcd(abs(x.num), x.den)
    return _from_raw512(div(x.num, g), div(x.den, g))
end

#===
Predicates and basic properties
===#

finite(x::XRational512) = x.den != 0
Base.isfinite(x::XRational512) = x.den != 0
Base.isinf(x::XRational512) = x.den == 0 && x.num != 0
Base.isnan(x::XRational512) = x.den == 0 && x.num == 0
Base.iszero(x::XRational512) = x.num == 0 && x.den != 0
Base.isone(x::XRational512) = x.den > 0 && x.num == x.den
Base.isinteger(x::XRational512) = x.den > 0 && rem(x.num, x.den) == 0
Base.signbit(x::XRational512) = x.num < 0
Base.sign(x::XRational512) = isnan(x) ? x : (iszero(x) ? zero(x) : XRational512(sign(x.num), 1))

Base.zero(::Type{XRational512}) = _from_raw512(Int512(0), Int512(1))
Base.zero(::XRational512) = _from_raw512(Int512(0), Int512(1))
Base.one(::Type{XRational512}) = _from_raw512(Int512(1), Int512(1))
Base.one(::XRational512) = _from_raw512(Int512(1), Int512(1))
Base.typemin(::Type{XRational512}) = _from_raw512(Int512(-1), Int512(0))
Base.typemax(::Type{XRational512}) = _from_raw512(Int512(1), Int512(0))

function Base.numerator(x::XRational512)
    n = _normalize(x)
    return n.num
end

function Base.denominator(x::XRational512)
    n = _normalize(x)
    return n.den
end

nan(::Type{XRational512}) = _from_raw512(Int512(0), Int512(0))
inf(::Type{XRational512}) = _from_raw512(Int512(1), Int512(0))
posinf(::Type{XRational512}) = _from_raw512(Int512(1), Int512(0))
neginf(::Type{XRational512}) = _from_raw512(Int512(-1), Int512(0))

const NaN = nan
const Inf = inf
const NegInf = neginf

#===
Internal helpers
===#

@inline _signnum(x::XRational512) = x.num > 0 ? 1 : (x.num < 0 ? -1 : 0)
@inline _both_finite(x::XRational512, y::XRational512) = x.den != 0 && y.den != 0
@inline _finite_nonzero_divisor(x::XRational512, y::XRational512) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::XRational512, y::XRational512) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)

@inline function _overflow_policy_f512(num::Integer, den::Integer)
    if den == 0
        return num == 0 ? nan(XRational512) : _from_raw512(Int512(sign(num)), Int512(0))
    end
    if den < 0
        num = -num
    end
    return num == 0 ? zero(XRational512) : _from_raw512(Int512(sign(num)), Int512(0))
end

@inline function _raw_or_normalize_f512(n::Int1024, d::Int1024)
    if n == 0
        return _from_raw512(Int512(0), Int512(1))
    end
    if typemin(Int512) < n <= typemax(Int512) && d <= typemax(Int512)
        return _from_raw512(Int512(n), Int512(d))
    end
    g = gcd(abs(n), d)
    nn = div(n, g)
    dd = div(d, g)
    (typemin(Int512) < nn <= typemax(Int512) && dd <= typemax(Int512)) ||
        return _overflow_policy_f512(nn, dd)
    return _from_raw512(Int512(nn), Int512(dd))
end

@inline function _raw_or_policy_f512(n::Int1024, d::Int1024)
    (typemin(Int512) < n <= typemax(Int512) && typemin(Int512) < d <= typemax(Int512)) ||
        return _overflow_policy_f512(n, d)
    return _from_raw512(Int512(n), Int512(d))
end

@inline _finite512(x::XRational512) = Rational512(numerator(x), denominator(x))

#===
Display — normalizes before printing
===#

function Base.show(io::IO, x::XRational512)
    if isnan(x)
        print(io, "NaNQ512")
    elseif isinf(x)
        print(io, x.num > 0 ? "InfQ512" : "-InfQ512")
    else
        n = _normalize(x)
        print(io, n.num, "//", n.den)
    end
end

#===
Conversion and promotion
===#

Base.convert(::Type{XRational512}, x::XRational512) = x
Base.convert(::Type{XRational512}, x::Integer) = XRational512(x)
Base.convert(::Type{XRational512}, x::Rational512) = XRational512(x)
Base.convert(::Type{XRational512}, x::Rational{<:Integer}) = XRational512(x)
Base.convert(::Type{Float64}, x::XRational512) = isnan(x) ? Base.NaN : isinf(x) ? (x.num > 0 ? Base.Inf : -Base.Inf) : Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::XRational512) = isnan(x) ? Float32(Base.NaN) : isinf(x) ? (x.num > 0 ? Float32(Base.Inf) : Float32(-Base.Inf)) : Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::XRational512) = isnan(x) ? BigFloat(Base.NaN) : isinf(x) ? (x.num > 0 ? BigFloat(Base.Inf) : BigFloat(-Base.Inf)) : BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational{Int512}}, x::XRational512) = isfinite(x) ? (numerator(x) // denominator(x)) : throw(InexactError(:convert, Rational{Int512}, x))

Base.Float32(x::XRational512) = convert(Float32, x)
Base.Float64(x::XRational512) = convert(Float64, x)
Base.BigFloat(x::XRational512) = convert(BigFloat, x)

Base.promote_rule(::Type{XRational512}, ::Type{<:Integer}) = XRational512
Base.promote_rule(::Type{XRational512}, ::Type{Rational512}) = XRational512
Base.promote_rule(::Type{XRational512}, ::Type{XRational512}) = XRational512

#===
Unary operations
===#

Base.abs(x::XRational512) = isnan(x) ? x : isinf(x) ? posinf(XRational512) : signbit(x) ? _from_raw512(-x.num, x.den) : x
Base.:-(x::XRational512) = isnan(x) ? x : _from_raw512(-x.num, x.den)
Base.inv(x::XRational512) = isnan(x) ? x : isinf(x) ? zero(XRational512) : iszero(x) ? posinf(XRational512) : XRational512(x.den, x.num)
Base.copysign(x::XRational512, y::Real) = isnan(x) ? x : (signbit(x) == signbit(y) ? x : -x)
Base.flipsign(x::XRational512, y::Real) = isnan(x) ? x : (signbit(y) ? -x : x)

#===
Arithmetic — lazy normalization
===#

@inline function Base.:+(x::XRational512, y::XRational512)
    if x.den != 0 && y.den != 0
        n = Int1024(x.num) * Int1024(y.den) + Int1024(y.num) * Int1024(x.den)
        d = Int1024(x.den) * Int1024(y.den)
        return _raw_or_normalize_f512(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational512)
    elseif isinf(x) || isinf(y)
        return isinf(x) && isinf(y) && _signnum(x) != _signnum(y) ? nan(XRational512) : (isinf(x) ? x : y)
    end
end

@inline function Base.:-(x::XRational512, y::XRational512)
    if x.den != 0 && y.den != 0
        n = Int1024(x.num) * Int1024(y.den) - Int1024(y.num) * Int1024(x.den)
        d = Int1024(x.den) * Int1024(y.den)
        return _raw_or_normalize_f512(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational512)
    elseif isinf(x)
        return isinf(y) && _signnum(x) == _signnum(y) ? nan(XRational512) : x
    elseif isinf(y)
        return _from_raw512(Int512(-_signnum(y)), Int512(0))
    end
end

@inline function Base.:*(x::XRational512, y::XRational512)
    if x.den != 0 && y.den != 0
        n = Int1024(x.num) * Int1024(y.num)
        n == 0 && return _from_raw512(Int512(0), Int512(1))
        d = Int1024(x.den) * Int1024(y.den)
        return _raw_or_normalize_f512(n, d)
    elseif (x.den == 0 && x.num == 0) || (y.den == 0 && y.num == 0)
        return nan(XRational512)
    elseif (x.den == 0 && x.num != 0 && y.den != 0 && y.num == 0) ||
           (y.den == 0 && y.num != 0 && x.den != 0 && x.num == 0)
        return nan(XRational512)
    else
        return _from_raw512(Int512(_signnum(x) * _signnum(y)), Int512(0))
    end
end

@inline function Base.:/(x::XRational512, y::XRational512)
    if x.den != 0 && y.den != 0 && y.num != 0
        n = Int1024(x.num) * Int1024(y.den)
        n == 0 && return _from_raw512(Int512(0), Int512(1))
        d = Int1024(x.den) * Int1024(y.num)
        if d < 0
            n = -n
            d = -d
        end
        return _raw_or_normalize_f512(n, d)
    elseif isnan(x) || isnan(y)
        return nan(XRational512)
    elseif isinf(x) && isinf(y)
        return nan(XRational512)
    elseif iszero(y)
        return iszero(x) ? nan(XRational512) : _from_raw512(Int512(_signnum(x)), Int512(0))
    elseif isinf(y)
        return isinf(x) ? nan(XRational512) : zero(XRational512)
    elseif isinf(x)
        return _from_raw512(Int512(_signnum(x) * _signnum(y)), Int512(0))
    end
end

function Base.rem(x::XRational512, y::XRational512)
    if _finite_nonzero_divisor(x, y)
        r = rem(_finite512(x), _finite512(y))
        return XRational512(r)
    elseif _invalid_divisor_args(x, y)
        return nan(XRational512)
    end
end

function Base.mod(x::XRational512, y::XRational512)
    if _finite_nonzero_divisor(x, y)
        r = mod(_finite512(x), _finite512(y))
        return XRational512(r)
    elseif _invalid_divisor_args(x, y)
        return nan(XRational512)
    end
end

function Base.fld(x::XRational512, y::XRational512)
    if _finite_nonzero_divisor(x, y)
        return fld(_finite512(x), _finite512(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function Base.cld(x::XRational512, y::XRational512)
    if _finite_nonzero_divisor(x, y)
        return cld(_finite512(x), _finite512(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function Base.divrem(x::XRational512, y::XRational512)
    if _finite_nonzero_divisor(x, y)
        q, r = divrem(_finite512(x), _finite512(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function Base.fldmod(x::XRational512, y::XRational512)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod(_finite512(x), _finite512(y))
        return q, r
    end
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::XRational512, y::XRational512)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod1(_finite512(x), _finite512(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fldmod1 requires finite nonzero divisor"))
    end
end

#===
Fused multiply-add and powers
===#

Base.muladd(x::XRational512, y::XRational512, z::XRational512) = x * y + z
function Base.fma(x::XRational512, y::XRational512, z::XRational512)
    if _both_finite(x, y) && z.den != 0
        return XRational512(fma(_finite512(x), _finite512(y), _finite512(z)))
    end
    return muladd(x, y, z)
end

function Base.:^(x::XRational512, p::Integer)
    if p == 0
        return one(XRational512)
    elseif p < 0
        return inv(x)^(-p)
    end

    result = one(XRational512)
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
Mixed arithmetic with integers and Rational512
===#

for op in (:+, :-, :*, :/)
    @eval begin
        Base.$op(x::XRational512, y::Integer) = $op(x, XRational512(y))
        Base.$op(x::Integer, y::XRational512) = $op(XRational512(x), y)
        Base.$op(x::XRational512, y::Rational512) = $op(x, XRational512(y))
        Base.$op(x::Rational512, y::XRational512) = $op(XRational512(x), y)
    end
end

#===
Mixed quotient/remainder with integers and Rational512
===#

Base.rem(x::XRational512, y::Integer) = rem(x, XRational512(y))
Base.rem(x::Integer, y::XRational512) = rem(XRational512(x), y)
Base.rem(x::XRational512, y::Rational512) = rem(x, XRational512(y))
Base.rem(x::Rational512, y::XRational512) = rem(XRational512(x), y)
Base.mod(x::XRational512, y::Integer) = mod(x, XRational512(y))
Base.mod(x::Integer, y::XRational512) = mod(XRational512(x), y)
Base.mod(x::XRational512, y::Rational512) = mod(x, XRational512(y))
Base.mod(x::Rational512, y::XRational512) = mod(XRational512(x), y)
Base.fld(x::XRational512, y::Integer) = fld(x, XRational512(y))
Base.fld(x::Integer, y::XRational512) = fld(XRational512(x), y)
Base.fld(x::XRational512, y::Rational512) = fld(x, XRational512(y))
Base.fld(x::Rational512, y::XRational512) = fld(XRational512(x), y)
Base.cld(x::XRational512, y::Integer) = cld(x, XRational512(y))
Base.cld(x::Integer, y::XRational512) = cld(XRational512(x), y)
Base.cld(x::XRational512, y::Rational512) = cld(x, XRational512(y))
Base.cld(x::Rational512, y::XRational512) = cld(XRational512(x), y)
Base.divrem(x::XRational512, y::Integer) = divrem(x, XRational512(y))
Base.divrem(x::Integer, y::XRational512) = divrem(XRational512(x), y)
Base.divrem(x::XRational512, y::Rational512) = divrem(x, XRational512(y))
Base.divrem(x::Rational512, y::XRational512) = divrem(XRational512(x), y)
Base.fldmod(x::XRational512, y::Integer) = fldmod(x, XRational512(y))
Base.fldmod(x::Integer, y::XRational512) = fldmod(XRational512(x), y)
Base.fldmod(x::XRational512, y::Rational512) = fldmod(x, XRational512(y))
Base.fldmod(x::Rational512, y::XRational512) = fldmod(XRational512(x), y)
Base.fldmod1(x::XRational512, y::Integer) = fldmod1(x, XRational512(y))
Base.fldmod1(x::Integer, y::XRational512) = fldmod1(XRational512(x), y)
Base.fldmod1(x::XRational512, y::Rational512) = fldmod1(x, XRational512(y))
Base.fldmod1(x::Rational512, y::XRational512) = fldmod1(XRational512(x), y)

#===
Mixed fused multiply-add
===#

Base.muladd(x::XRational512, y::XRational512, z::Integer) = muladd(x, y, XRational512(z))
Base.muladd(x::XRational512, y::Integer, z::XRational512) = muladd(x, XRational512(y), z)
Base.muladd(x::Integer, y::XRational512, z::XRational512) = muladd(XRational512(x), y, z)
Base.muladd(x::XRational512, y::XRational512, z::Rational512) = muladd(x, y, XRational512(z))
Base.fma(x::XRational512, y::XRational512, z::Integer) = fma(x, y, XRational512(z))
Base.fma(x::XRational512, y::Integer, z::XRational512) = fma(x, XRational512(y), z)
Base.fma(x::Integer, y::XRational512, z::XRational512) = fma(XRational512(x), y, z)
Base.fma(x::XRational512, y::XRational512, z::Rational512) = fma(x, y, XRational512(z))

#===
Equality, ordering — uses cross-multiplication (no normalization needed)
===#

@inline function Base.:(==)(x::XRational512, y::XRational512)
    (isnan(x) || isnan(y)) && return false
    (x.den == 0 || y.den == 0) && return x.num == y.num && x.den == y.den
    return Int1024(x.num) * Int1024(y.den) == Int1024(y.num) * Int1024(x.den)
end
Base.:(==)(x::XRational512, y::Integer) = x == XRational512(y)
Base.:(==)(x::Integer, y::XRational512) = XRational512(x) == y

function Base.isless(x::XRational512, y::XRational512)
    if isnan(x)
        return false
    elseif isnan(y)
        return true
    elseif isinf(x)
        return x.num < 0 && !(isinf(y) && y.num < 0)
    elseif isinf(y)
        return y.num > 0 && !(isinf(x) && x.num > 0)
    else
        return Int1024(x.num) * Int1024(y.den) < Int1024(y.num) * Int1024(x.den)
    end
end

Base.:(<)(x::XRational512, y::XRational512) = !isnan(x) && !isnan(y) && isless(x, y)
Base.:(<=)(x::XRational512, y::XRational512) = !isnan(x) && !isnan(y) && (x == y || isless(x, y))
Base.:(>)(x::XRational512, y::XRational512) = y < x
Base.:(>=)(x::XRational512, y::XRational512) = y <= x

function Base.hash(x::XRational512, h::UInt)
    n = _normalize(x)
    return hash((n.num, n.den), h)
end

Base.float(x::XRational512) = Float64(x)

function Base.round(::Type{T}, x::XRational512) where {T<:Integer}
    isfinite(x) || throw(InexactError(:round, T, x))
    return round(T, x.num / x.den)
end

function Base.trunc(::Type{T}, x::XRational512) where {T<:Integer}
    isfinite(x) || throw(InexactError(:trunc, T, x))
    return trunc(T, x.num / x.den)
end

function Base.floor(::Type{T}, x::XRational512) where {T<:Integer}
    isfinite(x) || throw(InexactError(:floor, T, x))
    return floor(T, x.num / x.den)
end

function Base.ceil(::Type{T}, x::XRational512) where {T<:Integer}
    isfinite(x) || throw(InexactError(:ceil, T, x))
    return ceil(T, x.num / x.den)
end

Base.trunc(x::XRational512) = isfinite(x) ? XRational512(trunc(Int1024, x), 1) : nan(XRational512)
Base.floor(x::XRational512) = isfinite(x) ? XRational512(floor(Int1024, x), 1) : nan(XRational512)
Base.ceil(x::XRational512) = isfinite(x) ? XRational512(ceil(Int1024, x), 1) : nan(XRational512)

export XRational512, finite, isfinite, isinf, isnan

end # module