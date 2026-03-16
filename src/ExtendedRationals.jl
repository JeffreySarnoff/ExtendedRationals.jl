module ExtendedRationals

export Qx32, Q32, Qx64, Q64, NaN, Inf, NegInf

using Base: NaN, Inf

include("ExtendedRationalInt32s.jl")
include("ExtendedRationalInt64s.jl")

const Qx32 = ExtendedRationalInt32s.ExtendedRational32
const Q32 = ExtendedRationalInt32s.Rational32
const Qx64 = ExtendedRationalInt64s.ExtendedRational64
const Q64 = ExtendedRationalInt64s.Rational64

function Qx32(x::Qx64)
    if ExtendedRationalInt64s.isnan(x)
        return ExtendedRationalInt32s.nan(Qx32)
    elseif ExtendedRationalInt64s.isinf(x)
        return x.num > 0 ? ExtendedRationalInt32s.posinf(Qx32) : ExtendedRationalInt32s.neginf(Qx32)
    end

    limit = BigInt(typemax(Int32)) * BigInt(x.den)
    magnitude = abs(BigInt(x.num))
    if magnitude > limit
        return x.num > 0 ? ExtendedRationalInt32s.posinf(Qx32) : ExtendedRationalInt32s.neginf(Qx32)
    end

    nearest = ExtendedRationalInt32s.RationalInt32s._nearest_rational32(x.num // x.den)
    return Qx32(nearest)
end

Base.convert(::Type{Qx32}, x::Qx64) = Qx32(x)

end # module ExtendedRationals
