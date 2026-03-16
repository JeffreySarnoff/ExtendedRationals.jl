module ExtendedRationals

export Qx32, Q32, Qx64, Q64

import Base: convert, promote, promote_type

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

Base.convert(::Type{Qx32}, x::Qx64) = Qx32(x.num, x.den)
Base.convert(::Type{Qx64}, x::Qx32) = Qx64(x.num, x.den)

Base.convert(::Type{Qx32}, x::Rational{I}) where {I<Integer} = Qx32(x.num, x.den)
Base.convert(::Type{Qx64}, x::Rational{I}) where {I<Integer} = Qx64(x.num, x.den)

Base.promote_type(::Type{Qx32}, ::Type{Qx64}) = Qx64
Base.promote_type(::Type{Qx32}, ::Type{Rational}) = Qx32
Base.promote_type(::Type{Qx64}, ::Type{Rational}) = Qx64

end # module ExtendedRationals
