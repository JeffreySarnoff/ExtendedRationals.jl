module XRationals

export Qx32, Qx64

using BitIntegers: Int256, Int512
import Base: convert, promote, promote_type

include("XRational32s.jl")
include("XRational64s.jl")

const Qx32 = XRational32s.XRational32
const Qx64 = XRational64s.XRational64

function Qx32(x::Qx64)
    if isnan(x)
        return XRational32s.nan(Qx32)
    elseif isinf(x)
        return x.num > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end

    nx = numerator(x)
    dx = denominator(x)
    limit = Int128(typemax(Int32)) * Int128(dx)
    magnitude = abs(Int128(nx))
    if magnitude > limit
        return nx > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end

    nearest = XRational32s.Rational32s._nearest_rational32(nx // dx)
    return Qx32(nearest)
end

Base.convert(::Type{Qx32}, x::Qx64) = Qx32(numerator(x), denominator(x))
Base.convert(::Type{Qx64}, x::Qx32) = Qx64(numerator(x), denominator(x))

Base.promote_type(::Type{Qx32}, ::Type{Qx64}) = Qx64
Base.promote_type(::Type{Qx32}, ::Type{Rational}) = Qx32
Base.promote_type(::Type{Qx64}, ::Type{Rational}) = Qx64

end # module XRationals
