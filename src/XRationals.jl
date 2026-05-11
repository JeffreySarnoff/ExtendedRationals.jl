module XRationals

export Qx32, Qx64, Qx128

import Base: convert, promote, promote_type, widen

using BitIntegers: Int256

include("XRational32s.jl")
using .XRational32s
include("XRational64s.jl")
using .XRational64s
include("XRational128s.jl")
using .XRational128s

const Qx32 = XRational32s.XRational32
const Qx64 = XRational64s.XRational64
const Qx128 = XRational128s.XRational128

@inline function _qx32_special(x)
    if isnan(x)
        return XRational32s.nan(Qx32)
    elseif isinf(x)
        return x.num > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end
    return nothing
end

@inline function _qx64_special(x)
    if isnan(x)
        return XRational64s.nan(Qx64)
    elseif isinf(x)
        return x.num > 0 ? XRational64s.posinf(Qx64) : XRational64s.neginf(Qx64)
    end
    return nothing
end

@inline function _widen_qx64(x::Qx32)
    return Qx64(Int64(x.num), Int64(x.den))
end

@inline function _widen_qx128(x::Union{Qx32,Qx64})
    return Qx128(Int128(x.num), Int128(x.den))
end

function Qx32(x::Qx64)
    special = _qx32_special(x)
    special !== nothing && return special

    nx = numerator(x)
    dx = denominator(x)
    limit = Int128(typemax(Int32)) * Int128(dx)
    magnitude = abs(Int128(nx))
    if magnitude > limit
        return nx > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end

    nearest = XRational32s._nearest_rational32(nx // dx)
    return Qx32(nearest)
end

function Qx32(x::Qx128)
    special = _qx32_special(x)
    special !== nothing && return special

    nx = numerator(x)
    dx = denominator(x)
    limit = Int256(typemax(Int32)) * Int256(dx)
    magnitude = abs(Int256(nx))
    if magnitude > limit
        return nx > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end

    nearest = XRational32s._nearest_rational32(Int256(nx) // Int256(dx))
    return Qx32(nearest)
end

function Qx64(x::Qx128)
    special = _qx64_special(x)
    special !== nothing && return special

    nx = numerator(x)
    dx = denominator(x)
    limit = Int256(typemax(Int64)) * Int256(dx)
    magnitude = abs(Int256(nx))
    if magnitude > limit
        return nx > 0 ? XRational64s.posinf(Qx64) : XRational64s.neginf(Qx64)
    end

    nearest = XRational64s.Rational64s._nearest_rational64(Int256(nx) // Int256(dx))
    return Qx64(nearest)
end

Qx64(x::Qx32) = _widen_qx64(x)

Qx128(x::Qx32) = _widen_qx128(x)

Qx128(x::Qx64) = _widen_qx128(x)

Base.convert(::Type{Qx32}, x::Qx64) = Qx32(x)
Base.convert(::Type{Qx32}, x::Qx128) = Qx32(x)
Base.convert(::Type{Qx64}, x::Qx32) = Qx64(x)
Base.convert(::Type{Qx64}, x::Qx128) = Qx64(x)
Base.convert(::Type{Qx128}, x::Qx32) = Qx128(x)
Base.convert(::Type{Qx128}, x::Qx64) = Qx128(x)

Base.widen(::Type{Qx32}) = Qx64
Base.widen(::Type{Qx64}) = Qx128

Base.promote_type(::Type{Qx32}, ::Type{Qx64}) = Qx64
Base.promote_type(::Type{Qx32}, ::Type{Qx128}) = Qx128
Base.promote_type(::Type{Qx64}, ::Type{Qx128}) = Qx128

Base.promote_type(::Type{Qx32}, ::Type{Rational}) = Qx32
Base.promote_type(::Type{Qx64}, ::Type{Rational}) = Qx64
Base.promote_type(::Type{Qx128}, ::Type{Rational}) = Qx128

end # module XRationals
