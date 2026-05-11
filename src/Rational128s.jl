module Rational128s

using BitIntegers: Int256, Int512, Int1024


#===
Public type and canonical representation
===#

"""
    Rational128 <: Real

Exact rational number backed by `Int128` numerator and denominator in normalized
canonical form:

- `den > 0`
- `gcd(abs(num), den) == 1`
- zero is stored as `0//1`

Arithmetic is exact when the result fits in `Int128`; otherwise an
`OverflowError` is thrown.
"""
struct Rational128 <: Real
    num::Int128
    den::Int128

    Rational128(num::Int128, den::Int128, ::Val{:canonical}) = new(num, den)

    function Rational128(num::Integer, den::Integer)
        num == typemin(Int128) && throw(OverflowError("typemin(Int128) is not allowed"))
        den == typemin(Int128) && throw(OverflowError("typemin(Int128) is not allowed"))
        den == 0 && throw(ArgumentError("denominator must be nonzero"))

        if den < 0
            num = -num
            den = -den
        end

        if num == 0
            return new(Int128(0), Int128(1))
        end

        g = gcd(num, den)
        n = div(num, g)
        d = div(den, g)

        typemin(Int128) < n <= typemax(Int128) || throw(OverflowError("numerator does not fit in Int128"))
        typemin(Int128) < d <= typemax(Int128) || throw(OverflowError("denominator does not fit in Int128"))

        return new(Int128(n), Int128(d))
    end
end

# Constructors
#===
Constructors and exports
===#

Rational128(n::Integer) = Rational128(n, 1)
Rational128(x::Rational{<:Integer}) = Rational128(numerator(x), denominator(x))

const ℚ128 = Rational128

export Rational128, ℚ128

# Basic properties
#===
Basic properties
===#

Base.numerator(x::Rational128) = x.num
Base.denominator(x::Rational128) = x.den
Base.zero(::Type{Rational128}) = Rational128(0)
Base.zero(::Rational128) = Rational128(0)
Base.one(::Type{Rational128}) = Rational128(1)
Base.one(::Rational128) = Rational128(1)
Base.iszero(x::Rational128) = x.num == 0
Base.isone(x::Rational128) = x.num == 1 && x.den == 1
Base.isinteger(x::Rational128) = x.den == 1
Base.abs(x::Rational128) = Rational128(abs(x.num), x.den)
Base.signbit(x::Rational128) = signbit(x.num)
Base.sign(x::Rational128) = sign(x.num)

# Display
#===
Display
===#

function Base.show(io::IO, x::Rational128)
    print(io, x.num, "//", x.den)
end

# Conversion and promotion
#===
Conversion and promotion
===#

Base.convert(::Type{Rational128}, x::Rational128) = x
Base.convert(::Type{Rational128}, x::Integer) = Rational128(x)
Base.convert(::Type{Rational128}, x::Rational{<:Integer}) = Rational128(x)
Base.convert(::Type{Float64}, x::Rational128) = Float64(x.num) / Float64(x.den)
Base.convert(::Type{Float32}, x::Rational128) = Float32(x.num) / Float32(x.den)
Base.convert(::Type{BigFloat}, x::Rational128) = BigFloat(x.num) / BigFloat(x.den)
Base.convert(::Type{Rational{Int128}}, x::Rational128) = x.num // x.den

Base.promote_rule(::Type{Rational128}, ::Type{<:Integer}) = Rational128
Base.promote_rule(::Type{Rational128}, ::Type{Rational128}) = Rational128

# Internal helpers
#===
Internal helpers
===#

@inline function checked_int128(x::Integer)
    typemin(Int128) < x <= typemax(Int128) || throw(OverflowError("value does not fit in Int128"))
    return Int128(x)
end

@inline function normalize128(num::Integer, den::Integer)
    den == 0 && throw(ArgumentError("denominator must be nonzero"))
    if den < 0
        num = -num
        den = -den
    end
    if num == 0
        return Int128(0), Int128(1)
    end
    g = gcd(num, den)
    n = div(num, g)
    d = div(den, g)
    return checked_int128(n), checked_int128(d)
end

@inline _from_canonical128(num::Int128, den::Int128) = Rational128(num, den, Val(:canonical))

@inline function _quot_numden(x::Rational128, y::Rational128)
    iszero(y) && throw(DivideError())
    return Int256(x.num) * Int256(y.den), Int256(x.den) * Int256(y.num)
end

@inline _rational512(x::Rational128) = Int512(x.num) // Int512(x.den)

@inline function _apply_sign(x::Rational128, negative::Bool)
    return negative ? _from_canonical128(Int128(-x.num), x.den) : x
end

@inline function _tie_even(a::Rational128, b::Rational128)
    a_even = iseven(a.num)
    b_even = iseven(b.num)
    if a_even != b_even
        return a_even ? a : b
    end
    return a.den <= b.den ? a : b
end

function _compare_distance(target::Rational{Int512}, a::Rational128, b::Rational128)
    tn = Int1024(numerator(target))
    td = Int1024(denominator(target))

    an = abs(tn * Int1024(a.den) - Int1024(a.num) * td)
    bn = abs(tn * Int1024(b.den) - Int1024(b.num) * td)

    lhs = an * Int1024(b.den)
    rhs = bn * Int1024(a.den)

    if lhs < rhs
        return -1
    elseif lhs > rhs
        return 1
    else
        return 0
    end
end

function _nearest_rational128(target::Rational{Int512})
    iszero(target) && return zero(Rational128)

    limit = Int512(typemax(Int128))
    negative = target < 0
    work = negative ? -target : target

    if numerator(work) > limit * denominator(work)
        return _apply_sign(_from_canonical128(Int128(typemax(Int128)), Int128(1)), negative)
    end

    try
        exact = Rational128(numerator(target), denominator(target))
        return exact
    catch err
        if !(err isa OverflowError)
            rethrow()
        end
    end

    n = numerator(work)
    d = denominator(work)

    p0 = Int512(0)
    q0 = Int512(1)
    p1 = Int512(1)
    q1 = Int512(0)

    while true
        a = div(n, d)
        p2 = p0 + a * p1
        q2 = q0 + a * q1

        if p2 > limit || q2 > limit
            kp = iszero(p1) ? limit : div(limit - p0, p1)
            kq = iszero(q1) ? limit : div(limit - q0, q1)
            k = min(a, kp, kq)

            lower = _from_canonical128(checked_int128(p0 + k * p1), checked_int128(q0 + k * q1))
            upper = _from_canonical128(checked_int128(p1), checked_int128(q1))

            cmp = _compare_distance(work, lower, upper)
            best = cmp < 0 ? lower : cmp > 0 ? upper : _tie_even(lower, upper)
            return _apply_sign(best, negative)
        end

        if rem(n, d) == 0
            exact = _from_canonical128(checked_int128(p2), checked_int128(q2))
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

@inline function Base.:+(x::Rational128, y::Rational128)
    n, d = normalize128(Int256(x.num) * Int256(y.den) + Int256(y.num) * Int256(x.den),
        Int256(x.den) * Int256(y.den))
    return _from_canonical128(n, d)
end

@inline function Base.:-(x::Rational128, y::Rational128)
    n, d = normalize128(Int256(x.num) * Int256(y.den) - Int256(y.num) * Int256(x.den),
        Int256(x.den) * Int256(y.den))
    return _from_canonical128(n, d)
end

@inline function Base.:*(x::Rational128, y::Rational128)
    g1 = gcd(x.num, y.den)
    g2 = gcd(y.num, x.den)
    xn = div(x.num, g1)
    yd = div(y.den, g1)
    yn = div(y.num, g2)
    xd = div(x.den, g2)
    n = Int256(xn) * Int256(yn)
    n == 0 && return _from_canonical128(Int128(0), Int128(1))
    d = Int256(xd) * Int256(yd)
    return _from_canonical128(checked_int128(n), checked_int128(d))
end

@inline function Base.:/(x::Rational128, y::Rational128)
    iszero(y) && throw(DivideError())
    g1 = gcd(x.num, y.num)
    g2 = gcd(x.den, y.den)
    xn = div(x.num, g1)
    yn = div(y.num, g1)
    xd = div(x.den, g2)
    yd = div(y.den, g2)
    n = Int256(xn) * Int256(yd)
    n == 0 && return _from_canonical128(Int128(0), Int128(1))
    d = Int256(xd) * Int256(yn)
    if d < 0
        n = -n
        d = -d
    end
    return _from_canonical128(checked_int128(n), checked_int128(d))
end

Base.inv(x::Rational128) = iszero(x) ? throw(DivideError()) : Rational128(x.den, x.num)
Base.:-(x::Rational128) = _from_canonical128(-x.num, x.den)

Base.copysign(x::Rational128, y::Real) = signbit(x) == signbit(y) ? x : -x
Base.flipsign(x::Rational128, y::Real) = signbit(y) ? -x : x

function Base.rem(x::Rational128, y::Rational128)
    num, den = _quot_numden(x, y)
    rn = rem(num, den)
    rd = Int256(x.den) * Int256(y.den)
    n, d = normalize128(rn, rd)
    return _from_canonical128(n, d)
end

function Base.mod(x::Rational128, y::Rational128)
    num, den = _quot_numden(x, y)
    rn = mod(num, den)
    rd = Int256(x.den) * Int256(y.den)
    n, d = normalize128(rn, rd)
    return _from_canonical128(n, d)
end

function Base.fld(x::Rational128, y::Rational128)
    num, den = _quot_numden(x, y)
    q = fld(num, den)
    return _from_canonical128(checked_int128(q), Int128(1))
end

function Base.cld(x::Rational128, y::Rational128)
    num, den = _quot_numden(x, y)
    q = cld(num, den)
    return _from_canonical128(checked_int128(q), Int128(1))
end

function Base.divrem(x::Rational128, y::Rational128)
    num, den = _quot_numden(x, y)
    q = div(num, den)
    rn = rem(num, den)
    rd = Int256(x.den) * Int256(y.den)
    n, d = normalize128(rn, rd)
    return q, _from_canonical128(n, d)
end

function Base.fldmod(x::Rational128, y::Rational128)
    q = fld(x, y)
    return q, mod(x, y)
end

function Base.fldmod1(x::Rational128, y::Rational128)
    iszero(y) && throw(DivideError())
    q, r = fldmod(x, y)
    if iszero(r)
        return q, abs(y)
    else
        return q + 1, r
    end
end

Base.muladd(x::Rational128, y::Rational128, z::Rational128) = x * y + z
function Base.fma(x::Rational128, y::Rational128, z::Rational128)
    exact = muladd(_rational512(x), _rational512(y), _rational512(z))
    return _nearest_rational128(exact)
end

function Base.:^(x::Rational128, p::Integer)
    if p == 0
        return one(Rational128)
    elseif p < 0
        iszero(x) && throw(DivideError())
        return inv(x)^(-p)
    end

    result = one(Rational128)
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
        Base.$op(x::Rational128, y::Integer) = $op(x, Rational128(y))
        Base.$op(x::Integer, y::Rational128) = $op(Rational128(x), y)
    end
end

# Mixed remainder/mod with integers
#===
Mixed remainder/mod with integers
===#

Base.rem(x::Rational128, y::Integer) = rem(x, Rational128(y))
Base.rem(x::Integer, y::Rational128) = rem(Rational128(x), y)
Base.mod(x::Rational128, y::Integer) = mod(x, Rational128(y))
Base.mod(x::Integer, y::Rational128) = mod(Rational128(x), y)
Base.fld(x::Rational128, y::Integer) = fld(x, Rational128(y))
Base.fld(x::Integer, y::Rational128) = fld(Rational128(x), y)
Base.cld(x::Rational128, y::Integer) = cld(x, Rational128(y))
Base.cld(x::Integer, y::Rational128) = cld(Rational128(x), y)
Base.divrem(x::Rational128, y::Integer) = divrem(x, Rational128(y))
Base.divrem(x::Integer, y::Rational128) = divrem(Rational128(x), y)
Base.fldmod(x::Rational128, y::Integer) = fldmod(x, Rational128(y))
Base.fldmod(x::Integer, y::Rational128) = fldmod(Rational128(x), y)
Base.fldmod1(x::Rational128, y::Integer) = fldmod1(x, Rational128(y))
Base.fldmod1(x::Integer, y::Rational128) = fldmod1(Rational128(x), y)

# Mixed fused multiply-add
#===
Mixed fused multiply-add
===#

Base.muladd(x::Rational128, y::Rational128, z::Integer) = muladd(x, y, Rational128(z))
Base.muladd(x::Rational128, y::Integer, z::Rational128) = muladd(x, Rational128(y), z)
Base.muladd(x::Integer, y::Rational128, z::Rational128) = muladd(Rational128(x), y, z)
Base.fma(x::Rational128, y::Rational128, z::Integer) = fma(x, y, Rational128(z))
Base.fma(x::Rational128, y::Integer, z::Rational128) = fma(x, Rational128(y), z)
Base.fma(x::Integer, y::Rational128, z::Rational128) = fma(Rational128(x), y, z)

# Comparison
#===
Comparison and hashing
===#

Base.:(==)(x::Rational128, y::Rational128) = x.num == y.num && x.den == y.den
Base.isless(x::Rational128, y::Rational128) = Int256(x.num) * y.den < Int256(y.num) * x.den

Base.hash(x::Rational128, h::UInt) = hash((x.num, x.den), h)

# Numeric traits
#===
Numeric traits and rounding
===#

Base.:(<)(x::Rational128, y::Rational128) = isless(x, y)
Base.:(<=)(x::Rational128, y::Rational128) = !isless(y, x)
Base.:(>)(x::Rational128, y::Rational128) = isless(y, x)
Base.:(>=)(x::Rational128, y::Rational128) = !isless(x, y)

Base.float(x::Rational128) = Float64(x)

function Base.round(::Type{T}, x::Rational128) where {T<:Integer}
    return round(T, x.num / x.den)
end

Base.trunc(::Type{T}, x::Rational128) where {T<:Integer} = trunc(T, x.num / x.den)
Base.floor(::Type{T}, x::Rational128) where {T<:Integer} = floor(T, x.num / x.den)
Base.ceil(::Type{T}, x::Rational128) where {T<:Integer} = ceil(T, x.num / x.den)

Base.trunc(x::Rational128) = Rational128(trunc(Int256, x), 1)
Base.floor(x::Rational128) = Rational128(floor(Int256, x), 1)
Base.ceil(x::Rational128) = Rational128(ceil(Int256, x), 1)

end # module