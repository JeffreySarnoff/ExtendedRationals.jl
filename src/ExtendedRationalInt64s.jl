module ExtendedRationalInt64s

include("RationalInt64s.jl")
using .RationalInt64s: Rational64

#===
Public type and canonical representation
===#

"""
    ExtendedRational64 <: Real

An `Int64`-backed rational type extended with IEEE-like special values using the
following compact encodings:

- `0//0`   => `NaN`
- `1//0`   => `Inf`
- `-1//0`  => `-Inf`
- `n//d` with `d > 0` => finite normalized rational value

Finite values are stored canonically:

- `den > 0`
- `gcd(abs(num), den) == 1`
- zero is stored as `0//1`

Arithmetic on finite values is exact when the result fits in `Int64`; otherwise
a policy value is returned: `Inf64`, `-Inf64`, or `NaN64` as appropriate.
"""
struct ExtendedRational64 <: Real
    num::Int64
    den::Int64

    ExtendedRational64(num::Int64, den::Int64, ::Val{:canonical}) = new(num, den)

    function ExtendedRational64(num::Integer, den::Integer)
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

        g = gcd(num, den)
        n = div(num, g)
        d = div(den, g)

        typemin(Int64) <= n <= typemax(Int64) || throw(OverflowError("numerator does not fit in Int64"))
        typemin(Int64) <= d <= typemax(Int64) || throw(OverflowError("denominator does not fit in Int64"))

        return new(Int64(n), Int64(d))
    end
end

const ℚx64 = ExtendedRational64

NaN(::Type{ExtendedRational64}) = ExtendedRational64(0, 0)
Inf(::Type{ExtendedRational64}) = ExtendedRational64(1, 0)
NegInf(::Type{ExtendedRational64}) = ExtendedRational64(-1, 0)

ExtendedRational64(n::Integer) = ExtendedRational64(n, 1)
ExtendedRational64(x::Rational64) = ExtendedRational64(x.num, x.den)
ExtendedRational64(x::Rational{<:Integer}) = ExtendedRational64(numerator(x), denominator(x))

#===
Predicates and basic properties
===#

finite(x::ExtendedRational64) = x.den != 0
Base.isfinite(x::ExtendedRational64) = x.den != 0
Base.isinf(x::ExtendedRational64) = x.den == 0 && x.num != 0
Base.isnan(x::ExtendedRational64) = x.den == 0 && x.num == 0
Base.iszero(x::ExtendedRational64) = x.den != 0 && x.num == 0
Base.isone(x::ExtendedRational64) = x.den == 1 && x.num == 1
Base.isinteger(x::ExtendedRational64) = isfinite(x) && x.den == 1
Base.signbit(x::ExtendedRational64) = x.num < 0
Base.sign(x::ExtendedRational64) = isnan(x) ? x : (iszero(x) ? zero(x) : ExtendedRational64(sign(x.num), 1))

Base.zero(::Type{ExtendedRational64}) = ExtendedRational64(0, 1)
Base.zero(::ExtendedRational64) = ExtendedRational64(0, 1)
Base.one(::Type{ExtendedRational64}) = ExtendedRational64(1, 1)
Base.one(::ExtendedRational64) = ExtendedRational64(1, 1)
Base.typemin(::Type{ExtendedRational64}) = ExtendedRational64(-1, 0)
Base.typemax(::Type{ExtendedRational64}) = ExtendedRational64(1, 0)

Base.numerator(x::ExtendedRational64) = x.num
Base.denominator(x::ExtendedRational64) = x.den

nan(::Type{ExtendedRational64}) = ExtendedRational64(0, 0)
posinf(::Type{ExtendedRational64}) = ExtendedRational64(1, 0)
neginf(::Type{ExtendedRational64}) = ExtendedRational64(-1, 0)

#===
Internal helpers
===#

@inline function _checked_int64(x::Integer)
    typemin(Int64) <= x <= typemax(Int64) || throw(OverflowError("value does not fit in Int64"))
    return Int64(x)
end

@inline function _normalize64(num::Integer, den::Integer)
    den == 0 && throw(ArgumentError("finite normalization requires nonzero denominator"))
    if den < 0
        num = -num
        den = -den
    end
    if num == 0
        return Int64(0), Int64(1)
    end
    g = gcd(num, den)
    n = div(num, g)
    d = div(den, g)
    return _checked_int64(n), _checked_int64(d)
end

@inline _from_canonical64(num::Int64, den::Int64) = ExtendedRational64(num, den, Val(:canonical))

@inline function _overflow_policy64(num::Integer, den::Integer)
    if den == 0
        return num == 0 ? nan(ExtendedRational64) : ExtendedRational64(sign(num), 0)
    end
    if den < 0
        num = -num
        den = -den
    end
    return num == 0 ? zero(ExtendedRational64) : ExtendedRational64(sign(num), 0)
end

@inline function _normalize_or_policy64(num::Integer, den::Integer)
    try
        nn, dd = _normalize64(num, den)
        return _from_canonical64(nn, dd)
    catch err
        if err isa OverflowError
            return _overflow_policy64(num, den)
        end
        rethrow()
    end
end

@inline function _canonical_or_policy64(num::Integer, den::Integer)
    try
        return _from_canonical64(_checked_int64(num), _checked_int64(den))
    catch err
        if err isa OverflowError
            return _overflow_policy64(num, den)
        end
        rethrow()
    end
end

@inline _finite64(x::ExtendedRational64) = Rational64(x.num, x.den)
@inline _signnum(x::ExtendedRational64) = x.num > 0 ? 1 : (x.num < 0 ? -1 : 0)
@inline _both_finite(x::ExtendedRational64, y::ExtendedRational64) = x.den != 0 && y.den != 0
@inline _finite_nonzero_divisor(x::ExtendedRational64, y::ExtendedRational64) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::ExtendedRational64, y::ExtendedRational64) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)
@inline _abs128(x::Int64) = abs(Int128(x))

@inline function _negate_or_policy64(x::ExtendedRational64)
    if isnan(x)
        return x
    elseif isinf(x)
        return ExtendedRational64(-x.num, 0)
    elseif x.num == typemin(Int64)
        return posinf(ExtendedRational64)
    end
    return _from_canonical64(-x.num, x.den)
end

#===
Display
===#

function Base.show(io::IO, x::ExtendedRational64)
    if isnan(x)
        print(io, "NaN64")
    elseif isinf(x)
        print(io, x.num > 0 ? "Inf64" : "-Inf64")
    else
        print(io, x.num, "//", x.den)
    end
end

#===
Conversion and promotion
===#

Base.convert(::Type{ExtendedRational64}, x::ExtendedRational64) = x
Base.convert(::Type{ExtendedRational64}, x::Integer) = ExtendedRational64(x)
Base.convert(::Type{ExtendedRational64}, x::Rational64) = ExtendedRational64(x)
Base.convert(::Type{ExtendedRational64}, x::Rational{<:Integer}) = ExtendedRational64(x)
Base.convert(::Type{Float64}, x::ExtendedRational64) = isnan(x) ? NaN : isinf(x) ? (x.num > 0 ? Inf : -Inf) : Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::ExtendedRational64) = isnan(x) ? Float32(NaN) : isinf(x) ? (x.num > 0 ? Float32(Inf) : Float32(-Inf)) : Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::ExtendedRational64) = isnan(x) ? BigFloat(NaN) : isinf(x) ? (x.num > 0 ? BigFloat(Inf) : BigFloat(-Inf)) : BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational64}, x::ExtendedRational64) = isfinite(x) ? Rational64(x.num, x.den) : throw(InexactError(:convert, Rational64, x))
Base.convert(::Type{Rational{Int64}}, x::ExtendedRational64) = isfinite(x) ? (x.num // x.den) : throw(InexactError(:convert, Rational{Int64}, x))

Base.promote_rule(::Type{ExtendedRational64}, ::Type{<:Integer}) = ExtendedRational64
Base.promote_rule(::Type{ExtendedRational64}, ::Type{Rational64}) = ExtendedRational64
Base.promote_rule(::Type{ExtendedRational64}, ::Type{ExtendedRational64}) = ExtendedRational64

#===
Unary operations
===#

Base.abs(x::ExtendedRational64) = isnan(x) ? x : isinf(x) ? posinf(ExtendedRational64) : signbit(x) ? -x : x
Base.:-(x::ExtendedRational64) = _negate_or_policy64(x)
Base.inv(x::ExtendedRational64) = isnan(x) ? x : isinf(x) ? zero(ExtendedRational64) : iszero(x) ? posinf(ExtendedRational64) : ExtendedRational64(x.den, x.num)
Base.copysign(x::ExtendedRational64, y::Real) = isnan(x) ? x : (signbit(x) == signbit(y) ? x : -x)
Base.flipsign(x::ExtendedRational64, y::Real) = isnan(x) ? x : (signbit(y) ? -x : x)

#===
Arithmetic
===#

function Base.:+(x::ExtendedRational64, y::ExtendedRational64)
    if x.den != 0 && y.den != 0
        n = Int128(x.num) * Int128(y.den) + Int128(y.num) * Int128(x.den)
        d = Int128(x.den) * Int128(y.den)
        return _normalize_or_policy64(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRational64)
    elseif isinf(x) || isinf(y)
        return isinf(x) && isinf(y) && _signnum(x) != _signnum(y) ? nan(ExtendedRational64) : (isinf(x) ? x : y)
    end
end

@inline function Base.:-(x::ExtendedRational64, y::ExtendedRational64)
    if x.den != 0 && y.den != 0
        n = Int128(x.num) * Int128(y.den) - Int128(y.num) * Int128(x.den)
        d = Int128(x.den) * Int128(y.den)
        return _normalize_or_policy64(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRational64)
    elseif isinf(x)
        return isinf(y) && _signnum(x) == _signnum(y) ? nan(ExtendedRational64) : x
    elseif isinf(y)
        return ExtendedRational64(-_signnum(y), 0)
    end
end

@inline function Base.:*(x::ExtendedRational64, y::ExtendedRational64)
    if x.den != 0 && y.den != 0
        g1 = gcd(_abs128(x.num), Int128(y.den))
        g2 = gcd(_abs128(y.num), Int128(x.den))

        n1 = div(x.num, g1)
        d2 = div(y.den, g1)
        n2 = div(y.num, g2)
        d1 = div(x.den, g2)

        n = Int128(n1) * Int128(n2)
        n == 0 && return _from_canonical64(Int64(0), Int64(1))

        d = Int128(d1) * Int128(d2)
        return _canonical_or_policy64(n, d)
    elseif (x.den == 0 && x.num == 0) || (y.den == 0 && y.num == 0)
        return nan(ExtendedRational64)
    elseif (x.den == 0 && x.num != 0 && y.den != 0 && y.num == 0) ||
           (y.den == 0 && y.num != 0 && x.den != 0 && x.num == 0)
        return nan(ExtendedRational64)
    else
        return ExtendedRational64(_signnum(x) * _signnum(y), 0)
    end
end

function Base.:/(x::ExtendedRational64, y::ExtendedRational64)
    if x.den != 0 && y.den != 0 && y.num != 0
        g1 = gcd(_abs128(x.num), _abs128(y.num))
        g2 = gcd(Int128(x.den), Int128(y.den))

        n1 = div(x.num, g1)
        d2 = div(y.num, g1)
        n2 = div(y.den, g2)
        d1 = div(x.den, g2)

        n = Int128(n1) * Int128(n2)
        n == 0 && return _from_canonical64(Int64(0), Int64(1))

        d = Int128(d1) * Int128(d2)
        if d < 0
            n = -n
            d = -d
        end

        return _canonical_or_policy64(n, d)
    elseif isnan(x) || isnan(y)
        return nan(ExtendedRational64)
    elseif isinf(x) && isinf(y)
        return nan(ExtendedRational64)
    elseif iszero(y)
        return iszero(x) ? nan(ExtendedRational64) : ExtendedRational64(_signnum(x), 0)
    elseif isinf(y)
        return isinf(x) ? nan(ExtendedRational64) : zero(ExtendedRational64)
    elseif isinf(x)
        return ExtendedRational64(_signnum(x) * _signnum(y), 0)
    end
end

function Base.rem(x::ExtendedRational64, y::ExtendedRational64)
    if _finite_nonzero_divisor(x, y)
        return rem(_finite64(x), _finite64(y))
    elseif _invalid_divisor_args(x, y)
        return nan(ExtendedRational64)
    end
end

function Base.mod(x::ExtendedRational64, y::ExtendedRational64)
    if _finite_nonzero_divisor(x, y)
        return mod(_finite64(x), _finite64(y))
    elseif _invalid_divisor_args(x, y)
        return nan(ExtendedRational64)
    end
end

function Base.fld(x::ExtendedRational64, y::ExtendedRational64)
    if _finite_nonzero_divisor(x, y)
        return fld(_finite64(x), _finite64(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function Base.cld(x::ExtendedRational64, y::ExtendedRational64)
    if _finite_nonzero_divisor(x, y)
        return cld(_finite64(x), _finite64(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function Base.divrem(x::ExtendedRational64, y::ExtendedRational64)
    if _finite_nonzero_divisor(x, y)
        q, r = divrem(_finite64(x), _finite64(y))
        return q, r
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function Base.fldmod(x::ExtendedRational64, y::ExtendedRational64)
    if _finite_nonzero_divisor(x, y)
        q, r = fldmod(_finite64(x), _finite64(y))
        return q, r
    end
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::ExtendedRational64, y::ExtendedRational64)
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

Base.muladd(x::ExtendedRational64, y::ExtendedRational64, z::ExtendedRational64) = x * y + z
function Base.fma(x::ExtendedRational64, y::ExtendedRational64, z::ExtendedRational64)
    if _both_finite(x, y) && z.den != 0
        return ExtendedRational64(fma(_finite64(x), _finite64(y), _finite64(z)))
    end
    return muladd(x, y, z)
end

function Base.:^(x::ExtendedRational64, p::Integer)
    if p == 0
        return one(ExtendedRational64)
    elseif p < 0
        return inv(x)^(-p)
    end

    result = one(ExtendedRational64)
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
        Base.$op(x::ExtendedRational64, y::Integer) = $op(x, ExtendedRational64(y))
        Base.$op(x::Integer, y::ExtendedRational64) = $op(ExtendedRational64(x), y)
        Base.$op(x::ExtendedRational64, y::Rational64) = $op(x, ExtendedRational64(y))
        Base.$op(x::Rational64, y::ExtendedRational64) = $op(ExtendedRational64(x), y)
    end
end

#===
Mixed quotient/remainder with integers and Rational64
===#

Base.rem(x::ExtendedRational64, y::Integer) = rem(x, ExtendedRational64(y))
Base.rem(x::Integer, y::ExtendedRational64) = rem(ExtendedRational64(x), y)
Base.rem(x::ExtendedRational64, y::Rational64) = rem(x, ExtendedRational64(y))
Base.rem(x::Rational64, y::ExtendedRational64) = rem(ExtendedRational64(x), y)
Base.mod(x::ExtendedRational64, y::Integer) = mod(x, ExtendedRational64(y))
Base.mod(x::Integer, y::ExtendedRational64) = mod(ExtendedRational64(x), y)
Base.mod(x::ExtendedRational64, y::Rational64) = mod(x, ExtendedRational64(y))
Base.mod(x::Rational64, y::ExtendedRational64) = mod(ExtendedRational64(x), y)
Base.fld(x::ExtendedRational64, y::Integer) = fld(x, ExtendedRational64(y))
Base.fld(x::Integer, y::ExtendedRational64) = fld(ExtendedRational64(x), y)
Base.fld(x::ExtendedRational64, y::Rational64) = fld(x, ExtendedRational64(y))
Base.fld(x::Rational64, y::ExtendedRational64) = fld(ExtendedRational64(x), y)
Base.cld(x::ExtendedRational64, y::Integer) = cld(x, ExtendedRational64(y))
Base.cld(x::Integer, y::ExtendedRational64) = cld(ExtendedRational64(x), y)
Base.cld(x::ExtendedRational64, y::Rational64) = cld(x, ExtendedRational64(y))
Base.cld(x::Rational64, y::ExtendedRational64) = cld(ExtendedRational64(x), y)
Base.divrem(x::ExtendedRational64, y::Integer) = divrem(x, ExtendedRational64(y))
Base.divrem(x::Integer, y::ExtendedRational64) = divrem(ExtendedRational64(x), y)
Base.divrem(x::ExtendedRational64, y::Rational64) = divrem(x, ExtendedRational64(y))
Base.divrem(x::Rational64, y::ExtendedRational64) = divrem(ExtendedRational64(x), y)
Base.fldmod(x::ExtendedRational64, y::Integer) = fldmod(x, ExtendedRational64(y))
Base.fldmod(x::Integer, y::ExtendedRational64) = fldmod(ExtendedRational64(x), y)
Base.fldmod(x::ExtendedRational64, y::Rational64) = fldmod(x, ExtendedRational64(y))
Base.fldmod(x::Rational64, y::ExtendedRational64) = fldmod(ExtendedRational64(x), y)
Base.fldmod1(x::ExtendedRational64, y::Integer) = fldmod1(x, ExtendedRational64(y))
Base.fldmod1(x::Integer, y::ExtendedRational64) = fldmod1(ExtendedRational64(x), y)
Base.fldmod1(x::ExtendedRational64, y::Rational64) = fldmod1(x, ExtendedRational64(y))
Base.fldmod1(x::Rational64, y::ExtendedRational64) = fldmod1(ExtendedRational64(x), y)

#===
Mixed fused multiply-add
===#

Base.muladd(x::ExtendedRational64, y::ExtendedRational64, z::Integer) = muladd(x, y, ExtendedRational64(z))
Base.muladd(x::ExtendedRational64, y::Integer, z::ExtendedRational64) = muladd(x, ExtendedRational64(y), z)
Base.muladd(x::Integer, y::ExtendedRational64, z::ExtendedRational64) = muladd(ExtendedRational64(x), y, z)
Base.muladd(x::ExtendedRational64, y::ExtendedRational64, z::Rational64) = muladd(x, y, ExtendedRational64(z))
Base.fma(x::ExtendedRational64, y::ExtendedRational64, z::Integer) = fma(x, y, ExtendedRational64(z))
Base.fma(x::ExtendedRational64, y::Integer, z::ExtendedRational64) = fma(x, ExtendedRational64(y), z)
Base.fma(x::Integer, y::ExtendedRational64, z::ExtendedRational64) = fma(ExtendedRational64(x), y, z)
Base.fma(x::ExtendedRational64, y::ExtendedRational64, z::Rational64) = fma(x, y, ExtendedRational64(z))

#===
Equality, ordering, and numeric traits
===#

Base.:(==)(x::ExtendedRational64, y::ExtendedRational64) = !isnan(x) && !isnan(y) && x.num == y.num && x.den == y.den
Base.:(==)(x::ExtendedRational64, y::Integer) = x == ExtendedRational64(y)
Base.:(==)(x::Integer, y::ExtendedRational64) = ExtendedRational64(x) == y

function Base.isless(x::ExtendedRational64, y::ExtendedRational64)
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
        return Int128(x.num) * y.den < Int128(y.num) * x.den
    end
end

Base.:(<)(x::ExtendedRational64, y::ExtendedRational64) = !isnan(x) && !isnan(y) && isless(x, y)
Base.:(<=)(x::ExtendedRational64, y::ExtendedRational64) = !isnan(x) && !isnan(y) && (x == y || isless(x, y))
Base.:(>)(x::ExtendedRational64, y::ExtendedRational64) = y < x
Base.:(>=)(x::ExtendedRational64, y::ExtendedRational64) = y <= x

Base.hash(x::ExtendedRational64, h::UInt) = hash((x.num, x.den), h)
Base.float(x::ExtendedRational64) = Float64(x)

function Base.round(::Type{T}, x::ExtendedRational64) where {T<:Integer}
    isfinite(x) || throw(InexactError(:round, T, x))
    return round(T, x.num / x.den)
end

function Base.trunc(::Type{T}, x::ExtendedRational64) where {T<:Integer}
    isfinite(x) || throw(InexactError(:trunc, T, x))
    return trunc(T, x.num / x.den)
end

function Base.floor(::Type{T}, x::ExtendedRational64) where {T<:Integer}
    isfinite(x) || throw(InexactError(:floor, T, x))
    return floor(T, x.num / x.den)
end

function Base.ceil(::Type{T}, x::ExtendedRational64) where {T<:Integer}
    isfinite(x) || throw(InexactError(:ceil, T, x))
    return ceil(T, x.num / x.den)
end

Base.trunc(x::ExtendedRational64) = isfinite(x) ? ExtendedRational64(trunc(Int128, x), 1) : nan(ExtendedRational64)
Base.floor(x::ExtendedRational64) = isfinite(x) ? ExtendedRational64(floor(Int128, x), 1) : nan(ExtendedRational64)
Base.ceil(x::ExtendedRational64) = isfinite(x) ? ExtendedRational64(ceil(Int128, x), 1) : nan(ExtendedRational64)

export ExtendedRational64, ℚx64, finite, isfinite, isinf, isnan

end # module