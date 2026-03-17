module ExtendedRationals

export Qx32, Q32, Qx64, Q64

using BitIntegers: Int256, Int512
import Base: convert, promote, promote_type

include("ExtendedRationalFast32s.jl")
include("ExtendedRationalFast64s.jl")

const Qx32 = ExtendedRationalFast32s.ExtendedRationalFast32
const Q32 = ExtendedRationalFast32s.RationalInt32s.Rational32
const Qx64 = ExtendedRationalFast64s.ExtendedRationalFast64
const Q64 = ExtendedRationalFast64s.RationalInt64s.Rational64

function Qx32(x::Qx64)
    if isnan(x)
        return ExtendedRationalFast32s.nan(Qx32)
    elseif isinf(x)
        return x.num > 0 ? ExtendedRationalFast32s.posinf(Qx32) : ExtendedRationalFast32s.neginf(Qx32)
    end

    nx = numerator(x)
    dx = denominator(x)
    limit = Int128(typemax(Int32)) * Int128(dx)
    magnitude = abs(Int128(nx))
    if magnitude > limit
        return nx > 0 ? ExtendedRationalFast32s.posinf(Qx32) : ExtendedRationalFast32s.neginf(Qx32)
    end

    nearest = ExtendedRationalFast32s.RationalInt32s._nearest_rational32(nx // dx)
    return Qx32(nearest)
end

Base.convert(::Type{Qx32}, x::Qx64) = Qx32(numerator(x), denominator(x))
Base.convert(::Type{Qx64}, x::Qx32) = Qx64(numerator(x), denominator(x))

Base.promote_type(::Type{Qx32}, ::Type{Qx64}) = Qx64
Base.promote_type(::Type{Qx32}, ::Type{Rational}) = Qx32
Base.promote_type(::Type{Qx64}, ::Type{Rational}) = Qx64

end # module ExtendedRationals
