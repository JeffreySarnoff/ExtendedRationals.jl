module RationalInt64s

using BitIntegers: Int256, Int512


#===
Public type and canonical representation
===#

"""
    Rational64 <: Real

Exact rational number backed by `Int64` numerator and denominator in normalized
canonical form:

- `den > 0`
- `gcd(abs(num), den) == 1`
- zero is stored as `0//1`

Arithmetic is exact when the result fits in `Int64`; otherwise an
`OverflowError` is thrown.
"""
struct Rational64 <: Real
    num::Int64
    den::Int64

    Rational64(num::Int64, den::Int64, ::Val{:canonical}) = new(num, den)

    function Rational64(num::Integer, den::Integer)
        num == typemin(Int64) && throw(OverflowError("typemin(Int64) is not allowed"))
        den == typemin(Int64) && throw(OverflowError("typemin(Int64) is not allowed"))
        den == 0 && throw(ArgumentError("denominator must be nonzero"))

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

        typemin(Int64) < n <= typemax(Int64) || throw(OverflowError("numerator does not fit in Int64"))
        typemin(Int64) < d <= typemax(Int64) || throw(OverflowError("denominator does not fit in Int64"))

        return new(Int64(n), Int64(d))
    end
end

# Constructors
#===
Constructors and exports
===#

Rational64(n::Integer) = Rational64(n, 1)
Rational64(x::Rational{<:Integer}) = Rational64(numerator(x), denominator(x))

const ℚ64 = Rational64

export Rational64, ℚ64

# Basic properties
#===
Basic properties
===#

Base.numerator(x::Rational64) = x.num
Base.denominator(x::Rational64) = x.den
Base.zero(::Type{Rational64}) = Rational64(0)
Base.zero(::Rational64) = Rational64(0)
Base.one(::Type{Rational64}) = Rational64(1)
Base.one(::Rational64) = Rational64(1)
Base.iszero(x::Rational64) = x.num == 0
Base.isone(x::Rational64) = x.num == 1 && x.den == 1
Base.isinteger(x::Rational64) = x.den == 1
Base.abs(x::Rational64) = Rational64(abs(x.num), x.den)
Base.signbit(x::Rational64) = signbit(x.num)
Base.sign(x::Rational64) = sign(x.num)

# Display
#===
Display
===#

function Base.show(io::IO, x::Rational64)
    print(io, x.num, "//", x.den)
end

# Conversion and promotion
#===
Conversion and promotion
===#

Base.convert(::Type{Rational64}, x::Rational64) = x
Base.convert(::Type{Rational64}, x::Integer) = Rational64(x)
Base.convert(::Type{Rational64}, x::Rational{<:Integer}) = Rational64(x)
Base.convert(::Type{Float64}, x::Rational64) = Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::Rational64) = Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::Rational64) = BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational{Int64}}, x::Rational64) = x.num // x.den

Base.promote_rule(::Type{Rational64}, ::Type{<:Integer}) = Rational64
Base.promote_rule(::Type{Rational64}, ::Type{Rational64}) = Rational64

# Internal helpers
#===
Internal helpers
===#

@inline function checked_int64(x::Integer)
    typemin(Int64) < x <= typemax(Int64) || throw(OverflowError("value does not fit in Int64"))
    return Int64(x)
end

@inline function normalize64(num::Integer, den::Integer)
    den == 0 && throw(ArgumentError("denominator must be nonzero"))
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
    return checked_int64(n), checked_int64(d)
end

@inline _from_canonical64(num::Int64, den::Int64) = Rational64(num, den, Val(:canonical))

@inline function _quot_numden(x::Rational64, y::Rational64)
    iszero(y) && throw(DivideError())
    return Int128(x.num) * Int128(y.den), Int128(x.den) * Int128(y.num)
end

@inline _rational256(x::Rational64) = Int256(x.num) // Int256(x.den)

@inline function _apply_sign(x::Rational64, negative::Bool)
    return negative ? _from_canonical64(Int64(-x.num), x.den) : x
end

@inline function _tie_even(a::Rational64, b::Rational64)
    a_even = iseven(a.num)
    b_even = iseven(b.num)
    if a_even != b_even
        return a_even ? a : b
    end
    return a.den <= b.den ? a : b
end

function _compare_distance(target::Rational{Int256}, a::Rational64, b::Rational64)
    tn = Int512(numerator(target))
    td = Int512(denominator(target))

    an = abs(tn * Int512(a.den) - Int512(a.num) * td)
    bn = abs(tn * Int512(b.den) - Int512(b.num) * td)

    lhs = an * Int512(b.den)
    rhs = bn * Int512(a.den)

    if lhs < rhs
        return -1
    elseif lhs > rhs
        return 1
    else
        return 0
    end
end

function _nearest_rational64(target::Rational{Int256})
    iszero(target) && return zero(Rational64)

    limit = Int256(typemax(Int64))
    negative = target < 0
    work = negative ? -target : target

    if numerator(work) > limit * denominator(work)
        return _apply_sign(_from_canonical64(Int64(typemax(Int64)), Int64(1)), negative)
    end

    try
        exact = Rational64(numerator(target), denominator(target))
        return exact
    catch err
        if !(err isa OverflowError)
            rethrow()
        end
    end

    n = numerator(work)
    d = denominator(work)

    p0 = Int256(0)
    q0 = Int256(1)
    p1 = Int256(1)
    q1 = Int256(0)

    while true
        a = div(n, d)
        p2 = p0 + a * p1
        q2 = q0 + a * q1

        if p2 > limit || q2 > limit
            kp = iszero(p1) ? limit : div(limit - p0, p1)
            kq = iszero(q1) ? limit : div(limit - q0, q1)
            k = min(a, kp, kq)

            lower = _from_canonical64(checked_int64(p0 + k * p1), checked_int64(q0 + k * q1))
            upper = _from_canonical64(checked_int64(p1), checked_int64(q1))

            cmp = _compare_distance(work, lower, upper)
            best = cmp < 0 ? lower : cmp > 0 ? upper : _tie_even(lower, upper)
            return _apply_sign(best, negative)
        end

        if rem(n, d) == 0
            exact = _from_canonical64(checked_int64(p2), checked_int64(q2))
            return _apply_sign(exact, negative)
        end

        p0, q0, p1, q1 = p1, q1, p2, q2
        n, d = d, rem(n, d)
    end
end

# Arithmetic
#===
Arithmetic
===#

@inline function Base.:+(x::Rational64, y::Rational64)
    n, d = normalize64(Int128(x.num) * Int128(y.den) + Int128(y.num) * Int128(x.den),
        Int128(x.den) * Int128(y.den))
    return _from_canonical64(n, d)
end

@inline function Base.:-(x::Rational64, y::Rational64)
    n, d = normalize64(Int128(x.num) * Int128(y.den) - Int128(y.num) * Int128(x.den),
        Int128(x.den) * Int128(y.den))
    return _from_canonical64(n, d)
end

@inline function Base.:*(x::Rational64, y::Rational64)
    g1 = gcd(x.num, y.den)
    g2 = gcd(y.num, x.den)
    xn = div(x.num, g1)
    yd = div(y.den, g1)
    yn = div(y.num, g2)
    xd = div(x.den, g2)
    n = Int128(xn) * Int128(yn)
    n == 0 && return _from_canonical64(Int64(0), Int64(1))
    d = Int128(xd) * Int128(yd)
    return _from_canonical64(checked_int64(n), checked_int64(d))
end

@inline function Base.:/(x::Rational64, y::Rational64)
    iszero(y) && throw(DivideError())
    g1 = gcd(x.num, y.num)
    g2 = gcd(x.den, y.den)
    xn = div(x.num, g1)
    yn = div(y.num, g1)
    xd = div(x.den, g2)
    yd = div(y.den, g2)
    n = Int128(xn) * Int128(yd)
    n == 0 && return _from_canonical64(Int64(0), Int64(1))
    d = Int128(xd) * Int128(yn)
    if d < 0
        n = -n
        d = -d
    end
    return _from_canonical64(checked_int64(n), checked_int64(d))
end

Base.inv(x::Rational64) = iszero(x) ? throw(DivideError()) : Rational64(x.den, x.num)
Base.:-(x::Rational64) = _from_canonical64(-x.num, x.den)

Base.copysign(x::Rational64, y::Real) = signbit(x) == signbit(y) ? x : -x
Base.flipsign(x::Rational64, y::Real) = signbit(y) ? -x : x

function Base.rem(x::Rational64, y::Rational64)
    num, den = _quot_numden(x, y)
    rn = rem(num, den)
    rd = Int128(x.den) * Int128(y.den)
    n, d = normalize64(rn, rd)
    return _from_canonical64(n, d)
end

function Base.mod(x::Rational64, y::Rational64)
    num, den = _quot_numden(x, y)
    rn = mod(num, den)
    rd = Int128(x.den) * Int128(y.den)
    n, d = normalize64(rn, rd)
    return _from_canonical64(n, d)
end

function Base.fld(x::Rational64, y::Rational64)
    num, den = _quot_numden(x, y)
    q = fld(num, den)
    return _from_canonical64(checked_int64(q), Int64(1))
end

function Base.cld(x::Rational64, y::Rational64)
    num, den = _quot_numden(x, y)
    q = cld(num, den)
    return _from_canonical64(checked_int64(q), Int64(1))
end

function Base.divrem(x::Rational64, y::Rational64)
    num, den = _quot_numden(x, y)
    q = div(num, den)
    rn = rem(num, den)
    rd = Int128(x.den) * Int128(y.den)
    n, d = normalize64(rn, rd)
    return q, _from_canonical64(n, d)
end

function Base.fldmod(x::Rational64, y::Rational64)
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::Rational64, y::Rational64)
    iszero(y) && throw(DivideError())
    q, r = fldmod(x, y)
    if iszero(r)
        return q, abs(y)
    else
        return q + 1, r
    end
end

Base.muladd(x::Rational64, y::Rational64, z::Rational64) = x * y + z
function Base.fma(x::Rational64, y::Rational64, z::Rational64)
    exact = muladd(_rational256(x), _rational256(y), _rational256(z))
    return _nearest_rational64(exact)
end

function Base.:^(x::Rational64, p::Integer)
    if p == 0
        return one(Rational64)
    elseif p < 0
        iszero(x) && throw(DivideError())
        return inv(x)^(-p)
    end

    result = one(Rational64)
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

# Mixed arithmetic with integers
#===
Mixed arithmetic with integers
===#

for op in (:+, :-, :*, :/)
    @eval begin
        Base.$op(x::Rational64, y::Integer) = $op(x, Rational64(y))
        Base.$op(x::Integer, y::Rational64) = $op(Rational64(x), y)
    end
end

# Mixed remainder/mod with integers
#===
Mixed remainder/mod with integers
===#

Base.rem(x::Rational64, y::Integer) = rem(x, Rational64(y))
Base.rem(x::Integer, y::Rational64) = rem(Rational64(x), y)
Base.mod(x::Rational64, y::Integer) = mod(x, Rational64(y))
Base.mod(x::Integer, y::Rational64) = mod(Rational64(x), y)
Base.fld(x::Rational64, y::Integer) = fld(x, Rational64(y))
Base.fld(x::Integer, y::Rational64) = fld(Rational64(x), y)
Base.cld(x::Rational64, y::Integer) = cld(x, Rational64(y))
Base.cld(x::Integer, y::Rational64) = cld(Rational64(x), y)
Base.divrem(x::Rational64, y::Integer) = divrem(x, Rational64(y))
Base.divrem(x::Integer, y::Rational64) = divrem(Rational64(x), y)
Base.fldmod(x::Rational64, y::Integer) = fldmod(x, Rational64(y))
Base.fldmod(x::Integer, y::Rational64) = fldmod(Rational64(x), y)
Base.fldmod1(x::Rational64, y::Integer) = fldmod1(x, Rational64(y))
Base.fldmod1(x::Integer, y::Rational64) = fldmod1(Rational64(x), y)

# Mixed fused multiply-add
#===
Mixed fused multiply-add
===#

Base.muladd(x::Rational64, y::Rational64, z::Integer) = muladd(x, y, Rational64(z))
Base.muladd(x::Rational64, y::Integer, z::Rational64) = muladd(x, Rational64(y), z)
Base.muladd(x::Integer, y::Rational64, z::Rational64) = muladd(Rational64(x), y, z)
Base.fma(x::Rational64, y::Rational64, z::Integer) = fma(x, y, Rational64(z))
Base.fma(x::Rational64, y::Integer, z::Rational64) = fma(x, Rational64(y), z)
Base.fma(x::Integer, y::Rational64, z::Rational64) = fma(Rational64(x), y, z)

# Comparison
#===
Comparison and hashing
===#

Base.:(==)(x::Rational64, y::Rational64) = x.num == y.num && x.den == y.den
Base.isless(x::Rational64, y::Rational64) = Int128(x.num) * y.den < Int128(y.num) * x.den

Base.hash(x::Rational64, h::UInt) = hash((x.num, x.den), h)

# Numeric traits
#===
Numeric traits and rounding
===#

Base.:(<)(x::Rational64, y::Rational64) = isless(x, y)
Base.:(<=)(x::Rational64, y::Rational64) = !isless(y, x)
Base.:(>)(x::Rational64, y::Rational64) = isless(y, x)
Base.:(>=)(x::Rational64, y::Rational64) = !isless(x, y)

Base.float(x::Rational64) = Float64(x)

function Base.round(::Type{T}, x::Rational64) where {T<:Integer}
    return round(T, x.num / x.den)
end

Base.trunc(::Type{T}, x::Rational64) where {T<:Integer} = trunc(T, x.num / x.den)
Base.floor(::Type{T}, x::Rational64) where {T<:Integer} = floor(T, x.num / x.den)
Base.ceil(::Type{T}, x::Rational64) where {T<:Integer} = ceil(T, x.num / x.den)

Base.trunc(x::Rational64) = Rational64(trunc(Int128, x), 1)
Base.floor(x::Rational64) = Rational64(floor(Int128, x), 1)
Base.ceil(x::Rational64) = Rational64(ceil(Int128, x), 1)

end # module