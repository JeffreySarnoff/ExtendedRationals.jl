module XRationals

export Qx32, Qx64, Qx128, Qx256, Qx512

import Base: convert, promote_type, widen

import BitIntegers
using BitIntegers: Int256, Int512, Int1024

BitIntegers.@define_integers 2048

include("support.jl")

include("XRational32s.jl")
using .XRational32s
include("XRational64s.jl")
using .XRational64s
include("XRational128s.jl")
using .XRational128s
include("XRational256s.jl")
using .XRational256s
include("XRational512s.jl")
using .XRational512s

const Qx32 = XRational32s.XRational32
const Qx64 = XRational64s.XRational64
const Qx128 = XRational128s.XRational128
const Qx256 = XRational256s.XRational256
const Qx512 = XRational512s.XRational512

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

@inline function _qx128_special(x)
    if isnan(x)
        return XRational128s.nan(Qx128)
    elseif isinf(x)
        return x.num > 0 ? XRational128s.posinf(Qx128) : XRational128s.neginf(Qx128)
    end
    return nothing
end

@inline function _qx256_special(x)
    if isnan(x)
        return XRational256s.nan(Qx256)
    elseif isinf(x)
        return x.num > 0 ? XRational256s.posinf(Qx256) : XRational256s.neginf(Qx256)
    end
    return nothing
end

@inline function _widen_qx64(x::Qx32)
    return Qx64(Int64(x.num), Int64(x.den))
end

@inline function _widen_qx128(x::Union{Qx32,Qx64})
    return Qx128(Int128(x.num), Int128(x.den))
end

@inline function _widen_qx256(x::Union{Qx32,Qx64,Qx128})
    return Qx256(Int256(x.num), Int256(x.den))
end

@inline function _widen_qx512(x::Union{Qx32,Qx64,Qx128,Qx256})
    return Qx512(Int512(x.num), Int512(x.den))
end

function Qx32(x::Qx64)
    special = _qx32_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int128(typemax(Int32)) * Int128(dx)
    magnitude = abs(Int128(nx))
    if magnitude > limit
        return nx > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end

    nearest = _nearest_rational32(nx // dx)
    return Qx32(nearest)
end

function Qx32(x::Qx128)
    special = _qx32_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int256(typemax(Int32)) * Int256(dx)
    magnitude = abs(Int256(nx))
    if magnitude > limit
        return nx > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end

    nearest = _nearest_rational32(Int256(nx) // Int256(dx))
    return Qx32(nearest)
end

function Qx32(x::Qx256)
    special = _qx32_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int512(typemax(Int32)) * Int512(dx)
    magnitude = abs(Int512(nx))
    if magnitude > limit
        return nx > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end

    nearest = _nearest_rational32(nx // dx)
    return Qx32(nearest)
end

function Qx32(x::Qx512)
    special = _qx32_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int1024(typemax(Int32)) * Int1024(dx)
    magnitude = abs(Int1024(nx))
    if magnitude > limit
        return nx > 0 ? XRational32s.posinf(Qx32) : XRational32s.neginf(Qx32)
    end

    nearest = _nearest_rational32(nx // dx)
    return Qx32(nearest)
end

function Qx64(x::Qx128)
    special = _qx64_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int256(typemax(Int64)) * Int256(dx)
    magnitude = abs(Int256(nx))
    if magnitude > limit
        return nx > 0 ? XRational64s.posinf(Qx64) : XRational64s.neginf(Qx64)
    end

    nearest = _nearest_rational64(Int256(nx) // Int256(dx))
    return Qx64(nearest)
end

function Qx64(x::Qx256)
    special = _qx64_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int512(typemax(Int64)) * Int512(dx)
    magnitude = abs(Int512(nx))
    if magnitude > limit
        return nx > 0 ? XRational64s.posinf(Qx64) : XRational64s.neginf(Qx64)
    end

    nearest = _nearest_rational64(nx // dx)
    return Qx64(nearest)
end

function Qx64(x::Qx512)
    special = _qx64_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int1024(typemax(Int64)) * Int1024(dx)
    magnitude = abs(Int1024(nx))
    if magnitude > limit
        return nx > 0 ? XRational64s.posinf(Qx64) : XRational64s.neginf(Qx64)
    end

    nearest = _nearest_rational64(nx // dx)
    return Qx64(nearest)
end

function Qx128(x::Qx256)
    special = _qx128_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int512(typemax(Int128)) * Int512(dx)
    magnitude = abs(Int512(nx))
    if magnitude > limit
        return nx > 0 ? XRational128s.posinf(Qx128) : XRational128s.neginf(Qx128)
    end

    nearest = _nearest_rational128(Int512(nx) // Int512(dx))
    return Qx128(nearest)
end

function Qx128(x::Qx512)
    special = _qx128_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int1024(typemax(Int128)) * Int1024(dx)
    magnitude = abs(Int1024(nx))
    if magnitude > limit
        return nx > 0 ? XRational128s.posinf(Qx128) : XRational128s.neginf(Qx128)
    end

    nearest = _nearest_rational128(nx // dx)
    return Qx128(nearest)
end

function Qx256(x::Qx512)
    special = _qx256_special(x)
    special !== nothing && return special

    nx = x.num
    dx = x.den
    limit = Int1024(typemax(Int256)) * Int1024(dx)
    magnitude = abs(Int1024(nx))
    if magnitude > limit
        return nx > 0 ? XRational256s.posinf(Qx256) : XRational256s.neginf(Qx256)
    end

    nearest = _nearest_rational256(Int1024(nx) // Int1024(dx))
    return Qx256(nearest)
end

Qx64(x::Qx32) = _widen_qx64(x)

Qx128(x::Qx32) = _widen_qx128(x)

Qx128(x::Qx64) = _widen_qx128(x)

Qx256(x::Qx32) = _widen_qx256(x)

Qx256(x::Qx64) = _widen_qx256(x)

Qx256(x::Qx128) = _widen_qx256(x)

Qx512(x::Qx32) = _widen_qx512(x)

Qx512(x::Qx64) = _widen_qx512(x)

Qx512(x::Qx128) = _widen_qx512(x)

Qx512(x::Qx256) = _widen_qx512(x)

Base.convert(::Type{Qx32}, x::Qx64) = Qx32(x)
Base.convert(::Type{Qx32}, x::Qx128) = Qx32(x)
Base.convert(::Type{Qx32}, x::Qx256) = Qx32(x)
Base.convert(::Type{Qx32}, x::Qx512) = Qx32(x)
Base.convert(::Type{Qx64}, x::Qx32) = Qx64(x)
Base.convert(::Type{Qx64}, x::Qx128) = Qx64(x)
Base.convert(::Type{Qx64}, x::Qx256) = Qx64(x)
Base.convert(::Type{Qx64}, x::Qx512) = Qx64(x)
Base.convert(::Type{Qx128}, x::Qx32) = Qx128(x)
Base.convert(::Type{Qx128}, x::Qx64) = Qx128(x)
Base.convert(::Type{Qx128}, x::Qx256) = Qx128(x)
Base.convert(::Type{Qx128}, x::Qx512) = Qx128(x)
Base.convert(::Type{Qx256}, x::Qx32) = Qx256(x)
Base.convert(::Type{Qx256}, x::Qx64) = Qx256(x)
Base.convert(::Type{Qx256}, x::Qx128) = Qx256(x)
Base.convert(::Type{Qx256}, x::Qx512) = Qx256(x)
Base.convert(::Type{Qx512}, x::Qx32) = Qx512(x)
Base.convert(::Type{Qx512}, x::Qx64) = Qx512(x)
Base.convert(::Type{Qx512}, x::Qx128) = Qx512(x)
Base.convert(::Type{Qx512}, x::Qx256) = Qx512(x)

Base.widen(::Type{Qx32}) = Qx64
Base.widen(::Type{Qx64}) = Qx128
Base.widen(::Type{Qx128}) = Qx256
Base.widen(::Type{Qx256}) = Qx512

Base.promote_type(::Type{Qx32}, ::Type{Qx64}) = Qx64
Base.promote_type(::Type{Qx32}, ::Type{Qx128}) = Qx128
Base.promote_type(::Type{Qx32}, ::Type{Qx256}) = Qx256
Base.promote_type(::Type{Qx32}, ::Type{Qx512}) = Qx512
Base.promote_type(::Type{Qx64}, ::Type{Qx128}) = Qx128
Base.promote_type(::Type{Qx64}, ::Type{Qx256}) = Qx256
Base.promote_type(::Type{Qx64}, ::Type{Qx512}) = Qx512
Base.promote_type(::Type{Qx128}, ::Type{Qx256}) = Qx256
Base.promote_type(::Type{Qx128}, ::Type{Qx512}) = Qx512
Base.promote_type(::Type{Qx256}, ::Type{Qx512}) = Qx512

Base.promote_type(::Type{Qx32}, ::Type{Rational}) = Qx32
Base.promote_type(::Type{Qx64}, ::Type{Rational}) = Qx64
Base.promote_type(::Type{Qx128}, ::Type{Rational}) = Qx128
Base.promote_type(::Type{Qx256}, ::Type{Rational}) = Qx256
Base.promote_type(::Type{Qx512}, ::Type{Rational}) = Qx512

end # module XRationals
