module RationalInt32s


#===
Public type and canonical representation
===#

"""
    Rational32 <: Real

Exact rational number backed by `Int32` numerator and denominator in normalized
canonical form:

- `den > 0`
- `gcd(abs(num), den) == 1`
- zero is stored as `0//1`

Arithmetic is exact when the result fits in `Int32`; otherwise an
`OverflowError` is thrown.
"""
struct Rational32 <: Real
    num::Int32
    den::Int32

    Rational32(num::Int32, den::Int32, ::Val{:canonical}) = new(num, den)

    function Rational32(num::Integer, den::Integer)
        den == 0 && throw(ArgumentError("denominator must be nonzero"))

        # Keep the sign in the numerator.
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

# Constructors
#===
Constructors and exports
===#

Rational32(n::Integer) = Rational32(n, 1)
Rational32(x::Rational{<:Integer}) = Rational32(numerator(x), denominator(x))

const ℚ32 = Rational32

export Rational32, ℚ32

# Basic properties
#===
Basic properties
===#

Base.numerator(x::Rational32) = x.num
Base.denominator(x::Rational32) = x.den
Base.zero(::Type{Rational32}) = Rational32(0)
Base.zero(::Rational32) = Rational32(0)
Base.one(::Type{Rational32}) = Rational32(1)
Base.one(::Rational32) = Rational32(1)
Base.iszero(x::Rational32) = x.num == 0
Base.isone(x::Rational32) = x.num == 1 && x.den == 1
Base.isinteger(x::Rational32) = x.den == 1
Base.abs(x::Rational32) = Rational32(abs(x.num), x.den)
Base.signbit(x::Rational32) = signbit(x.num)
Base.sign(x::Rational32) = sign(x.num)

# Display
#===
Display
===#

function Base.show(io::IO, x::Rational32)
    print(io, x.num, "//", x.den)
end

# Conversion and promotion
#===
Conversion and promotion
===#

Base.convert(::Type{Rational32}, x::Rational32) = x
Base.convert(::Type{Rational32}, x::Integer) = Rational32(x)
Base.convert(::Type{Rational32}, x::Rational{<:Integer}) = Rational32(x)
Base.convert(::Type{Float64}, x::Rational32) = Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::Rational32) = Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::Rational32) = BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational{Int32}}, x::Rational32) = x.num // x.den

Base.promote_rule(::Type{Rational32}, ::Type{<:Integer}) = Rational32
Base.promote_rule(::Type{Rational32}, ::Type{Rational32}) = Rational32

# Internal helpers
#===
Internal helpers
===#

@inline function checked_int32(x::Integer)
    typemin(Int32) <= x <= typemax(Int32) || throw(OverflowError("value does not fit in Int32"))
    return Int32(x)
end

@inline function normalize32(num::Integer, den::Integer)
    den == 0 && throw(ArgumentError("denominator must be nonzero"))
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
    return checked_int32(n), checked_int32(d)
end

@inline _from_canonical32(num::Int32, den::Int32) = Rational32(num, den, Val(:canonical))

@inline function _quot_numden(x::Rational32, y::Rational32)
    iszero(y) && throw(DivideError())
    return Int128(x.num) * Int128(y.den), Int128(x.den) * Int128(y.num)
end

@inline function _remainder_from_q(x::Rational32, y::Rational32, q::Integer)
    rn = Int128(x.num) * Int128(y.den) - Int128(q) * Int128(x.den) * Int128(y.num)
    rd = Int128(x.den) * Int128(y.den)
    n, d = normalize32(rn, rd)
    return _from_canonical32(n, d)
end

@inline _rational64(x::Rational32) = Int64(x.num) // Int64(x.den)

@inline function _apply_sign(x::Rational32, negative::Bool)
    return negative ? _from_canonical32(Int32(-x.num), x.den) : x
end

@inline function _tie_even(a::Rational32, b::Rational32)
    a_even = iseven(a.num)
    b_even = iseven(b.num)
    if a_even != b_even
        return a_even ? a : b
    end
    return a.den <= b.den ? a : b
end

function _compare_distance(target::Rational{Int64}, a::Rational32, b::Rational32)
    tn = BigInt(numerator(target))
    td = BigInt(denominator(target))

    an = abs(tn * BigInt(a.den) - BigInt(a.num) * td)
    bn = abs(tn * BigInt(b.den) - BigInt(b.num) * td)

    lhs = an * BigInt(b.den)
    rhs = bn * BigInt(a.den)

    if lhs < rhs
        return -1
    elseif lhs > rhs
        return 1
    else
        return 0
    end
end

function _nearest_rational32(target::Rational{Int64})
    iszero(target) && return zero(Rational32)

    limit = Int128(typemax(Int32))
    negative = target < 0
    work = negative ? -target : target

    # Clamp values outside the finite Rational32 range.
    if BigInt(numerator(work)) > BigInt(limit) * BigInt(denominator(work))
        return _apply_sign(_from_canonical32(Int32(limit), Int32(1)), negative)
    end

    try
        exact = Rational32(numerator(target), denominator(target))
        return exact
    catch err
        if !(err isa OverflowError)
            rethrow()
        end
    end

    n = Int128(numerator(work))
    d = Int128(denominator(work))

    p0 = Int128(0)
    q0 = Int128(1)
    p1 = Int128(1)
    q1 = Int128(0)

    while true
        a = div(n, d)
        p2 = p0 + a * p1
        q2 = q0 + a * q1

        if p2 > limit || q2 > limit
            kp = p1 == 0 ? limit : div(limit - p0, p1)
            kq = q1 == 0 ? limit : div(limit - q0, q1)
            k = min(a, kp, kq)

            lower = _from_canonical32(checked_int32(p0 + k * p1), checked_int32(q0 + k * q1))
            upper = _from_canonical32(checked_int32(p1), checked_int32(q1))

            cmp = _compare_distance(work, lower, upper)
            best = cmp < 0 ? lower : cmp > 0 ? upper : _tie_even(lower, upper)
            return _apply_sign(best, negative)
        end

        if rem(n, d) == 0
            exact = _from_canonical32(checked_int32(p2), checked_int32(q2))
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

@inline function Base.:+(x::Rational32, y::Rational32)
    n, d = normalize32(Int64(x.num) * y.den + Int64(y.num) * x.den,
        Int64(x.den) * y.den)
    return _from_canonical32(n, d)
end

@inline function Base.:-(x::Rational32, y::Rational32)
    n, d = normalize32(Int64(x.num) * y.den - Int64(y.num) * x.den,
        Int64(x.den) * y.den)
    return _from_canonical32(n, d)
end

@inline function Base.:*(x::Rational32, y::Rational32)
    # Cross-cancel first to reduce overflow pressure.
    g1 = gcd(x.num, y.den)
    g2 = gcd(y.num, x.den)
    xn = div(x.num, g1)
    yd = div(y.den, g1)
    yn = div(y.num, g2)
    xd = div(x.den, g2)
    n = Int64(xn) * Int64(yn)
    n == 0 && return _from_canonical32(Int32(0), Int32(1))
    d = Int64(xd) * Int64(yd)
    return _from_canonical32(checked_int32(n), checked_int32(d))
end

@inline function Base.:/(x::Rational32, y::Rational32)
    iszero(y) && throw(DivideError())
    g1 = gcd(x.num, y.num)
    g2 = gcd(x.den, y.den)
    xn = div(x.num, g1)
    yn = div(y.num, g1)
    xd = div(x.den, g2)
    yd = div(y.den, g2)
    n = Int64(xn) * Int64(yd)
    n == 0 && return _from_canonical32(Int32(0), Int32(1))
    d = Int64(xd) * Int64(yn)
    if d < 0
        n = -n
        d = -d
    end
    return _from_canonical32(checked_int32(n), checked_int32(d))
end

Base.inv(x::Rational32) = iszero(x) ? throw(DivideError()) : Rational32(x.den, x.num)
Base.:-(x::Rational32) = Rational32(-Int64(x.num), x.den)

Base.copysign(x::Rational32, y::Real) = signbit(x) == signbit(y) ? x : -x
Base.flipsign(x::Rational32, y::Real) = signbit(y) ? -x : x

function Base.rem(x::Rational32, y::Rational32)
    num, den = _quot_numden(x, y)
    q = div(num, den)
    return _remainder_from_q(x, y, q)
end

function Base.mod(x::Rational32, y::Rational32)
    num, den = _quot_numden(x, y)
    q = fld(num, den)
    return _remainder_from_q(x, y, q)
end

function Base.fld(x::Rational32, y::Rational32)
    num, den = _quot_numden(x, y)
    q = fld(num, den)
    return _from_canonical32(checked_int32(q), Int32(1))
end

function Base.cld(x::Rational32, y::Rational32)
    num, den = _quot_numden(x, y)
    q = cld(num, den)
    return _from_canonical32(checked_int32(q), Int32(1))
end

function Base.divrem(x::Rational32, y::Rational32)
    num, den = _quot_numden(x, y)
    q = div(num, den)
    return q, _remainder_from_q(x, y, q)
end

function Base.fldmod(x::Rational32, y::Rational32)
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::Rational32, y::Rational32)
    iszero(y) && throw(DivideError())
    q, r = fldmod(x, y)
    if iszero(r)
        return q, abs(y)
    else
        return q + 1, r
    end
end

Base.muladd(x::Rational32, y::Rational32, z::Rational32) = x * y + z
function Base.fma(x::Rational32, y::Rational32, z::Rational32)
    exact = muladd(_rational64(x), _rational64(y), _rational64(z))
    return _nearest_rational32(exact)
end

function Base.:^(x::Rational32, p::Integer)
    if p == 0
        return one(Rational32)
    elseif p < 0
        iszero(x) && throw(DivideError())
        return inv(x)^(-p)
    end

    result = one(Rational32)
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
        Base.$op(x::Rational32, y::Integer) = $op(x, Rational32(y))
        Base.$op(x::Integer, y::Rational32) = $op(Rational32(x), y)
    end
end

# Mixed remainder/mod with integers
#===
Mixed remainder/mod with integers
===#

Base.rem(x::Rational32, y::Integer) = rem(x, Rational32(y))
Base.rem(x::Integer, y::Rational32) = rem(Rational32(x), y)
Base.mod(x::Rational32, y::Integer) = mod(x, Rational32(y))
Base.mod(x::Integer, y::Rational32) = mod(Rational32(x), y)
Base.fld(x::Rational32, y::Integer) = fld(x, Rational32(y))
Base.fld(x::Integer, y::Rational32) = fld(Rational32(x), y)
Base.cld(x::Rational32, y::Integer) = cld(x, Rational32(y))
Base.cld(x::Integer, y::Rational32) = cld(Rational32(x), y)
Base.divrem(x::Rational32, y::Integer) = divrem(x, Rational32(y))
Base.divrem(x::Integer, y::Rational32) = divrem(Rational32(x), y)
Base.fldmod(x::Rational32, y::Integer) = fldmod(x, Rational32(y))
Base.fldmod(x::Integer, y::Rational32) = fldmod(Rational32(x), y)
Base.fldmod1(x::Rational32, y::Integer) = fldmod1(x, Rational32(y))
Base.fldmod1(x::Integer, y::Rational32) = fldmod1(Rational32(x), y)

# Mixed fused multiply-add
#===
Mixed fused multiply-add
===#

Base.muladd(x::Rational32, y::Rational32, z::Integer) = muladd(x, y, Rational32(z))
Base.muladd(x::Rational32, y::Integer, z::Rational32) = muladd(x, Rational32(y), z)
Base.muladd(x::Integer, y::Rational32, z::Rational32) = muladd(Rational32(x), y, z)
Base.fma(x::Rational32, y::Rational32, z::Integer) = fma(x, y, Rational32(z))
Base.fma(x::Rational32, y::Integer, z::Rational32) = fma(x, Rational32(y), z)
Base.fma(x::Integer, y::Rational32, z::Rational32) = fma(Rational32(x), y, z)

# Comparison
#===
Comparison and hashing
===#

Base.:(==)(x::Rational32, y::Rational32) = x.num == y.num && x.den == y.den
Base.isless(x::Rational32, y::Rational32) = Int64(x.num) * y.den < Int64(y.num) * x.den

# Hash consistent with value semantics.
Base.hash(x::Rational32, h::UInt) = hash((x.num, x.den), h)

# Numeric traits
#===
Numeric traits and rounding
===#

Base.:(<)(x::Rational32, y::Rational32) = isless(x, y)
Base.:(<=)(x::Rational32, y::Rational32) = !isless(y, x)
Base.:(>)(x::Rational32, y::Rational32) = isless(y, x)
Base.:(>=)(x::Rational32, y::Rational32) = !isless(x, y)

Base.float(x::Rational32) = Float64(x)

function Base.round(::Type{T}, x::Rational32) where {T<:Integer}
    return round(T, x.num / x.den)
end

Base.trunc(::Type{T}, x::Rational32) where {T<:Integer} = trunc(T, x.num / x.den)
Base.floor(::Type{T}, x::Rational32) where {T<:Integer} = floor(T, x.num / x.den)
Base.ceil(::Type{T}, x::Rational32) where {T<:Integer} = ceil(T, x.num / x.den)

Base.trunc(x::Rational32) = Rational32(trunc(Int64, x), 1)
Base.floor(x::Rational32) = Rational32(floor(Int64, x), 1)
Base.ceil(x::Rational32) = Rational32(ceil(Int64, x), 1)

end # module
