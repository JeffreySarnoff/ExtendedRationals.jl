module WideToNarrowOptimized

using XRationals
using BitIntegers: Int256, Int512, Int1024

import XRationals: Qx32, Qx64, Qx128, Qx256, Qx512

@inline function qx32_special(x)
    if isnan(x)
        return XRationals.XRational32s.nan(Qx32)
    elseif isinf(x)
        return x.num > 0 ? XRationals.XRational32s.posinf(Qx32) : XRationals.XRational32s.neginf(Qx32)
    end
    return nothing
end

@inline function qx64_special(x)
    if isnan(x)
        return XRationals.XRational64s.nan(Qx64)
    elseif isinf(x)
        return x.num > 0 ? XRationals.XRational64s.posinf(Qx64) : XRationals.XRational64s.neginf(Qx64)
    end
    return nothing
end

@inline function qx128_special(x)
    if isnan(x)
        return XRationals.XRational128s.nan(Qx128)
    elseif isinf(x)
        return x.num > 0 ? XRationals.XRational128s.posinf(Qx128) : XRationals.XRational128s.neginf(Qx128)
    end
    return nothing
end

@inline function qx256_special(x)
    if isnan(x)
        return XRationals.XRational256s.nan(Qx256)
    elseif isinf(x)
        return x.num > 0 ? XRationals.XRational256s.posinf(Qx256) : XRationals.XRational256s.neginf(Qx256)
    end
    return nothing
end

function qx32_from_q64_fast(x::Qx64)
    special = qx32_special(x)
    special !== nothing && return special

    limit = Int128(typemax(Int32)) * Int128(x.den)
    magnitude = abs(Int128(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational32s.posinf(Qx32) : XRationals.XRational32s.neginf(Qx32)
    end

    return Qx32(XRationals._nearest_rational32(x.num // x.den))
end

function qx32_from_q128_fast(x::Qx128)
    special = qx32_special(x)
    special !== nothing && return special

    limit = Int256(typemax(Int32)) * Int256(x.den)
    magnitude = abs(Int256(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational32s.posinf(Qx32) : XRationals.XRational32s.neginf(Qx32)
    end

    return Qx32(XRationals._nearest_rational32(Int256(x.num) // Int256(x.den)))
end

function qx32_from_q256_fast(x::Qx256)
    special = qx32_special(x)
    special !== nothing && return special

    limit = Int512(typemax(Int32)) * Int512(x.den)
    magnitude = abs(Int512(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational32s.posinf(Qx32) : XRationals.XRational32s.neginf(Qx32)
    end

    return Qx32(XRationals._nearest_rational32(x.num // x.den))
end

function qx32_from_q512_fast(x::Qx512)
    special = qx32_special(x)
    special !== nothing && return special

    limit = Int1024(typemax(Int32)) * Int1024(x.den)
    magnitude = abs(Int1024(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational32s.posinf(Qx32) : XRationals.XRational32s.neginf(Qx32)
    end

    return Qx32(XRationals._nearest_rational32(x.num // x.den))
end

function qx64_from_q128_fast(x::Qx128)
    special = qx64_special(x)
    special !== nothing && return special

    limit = Int256(typemax(Int64)) * Int256(x.den)
    magnitude = abs(Int256(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational64s.posinf(Qx64) : XRationals.XRational64s.neginf(Qx64)
    end

    return Qx64(XRationals._nearest_rational64(Int256(x.num) // Int256(x.den)))
end

function qx64_from_q256_fast(x::Qx256)
    special = qx64_special(x)
    special !== nothing && return special

    limit = Int512(typemax(Int64)) * Int512(x.den)
    magnitude = abs(Int512(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational64s.posinf(Qx64) : XRationals.XRational64s.neginf(Qx64)
    end

    return Qx64(XRationals._nearest_rational64(x.num // x.den))
end

function qx64_from_q512_fast(x::Qx512)
    special = qx64_special(x)
    special !== nothing && return special

    limit = Int1024(typemax(Int64)) * Int1024(x.den)
    magnitude = abs(Int1024(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational64s.posinf(Qx64) : XRationals.XRational64s.neginf(Qx64)
    end

    return Qx64(XRationals._nearest_rational64(x.num // x.den))
end

function qx128_from_q256_fast(x::Qx256)
    special = qx128_special(x)
    special !== nothing && return special

    limit = Int512(typemax(Int128)) * Int512(x.den)
    magnitude = abs(Int512(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational128s.posinf(Qx128) : XRationals.XRational128s.neginf(Qx128)
    end

    return Qx128(XRationals._nearest_rational128(Int512(x.num) // Int512(x.den)))
end

function qx128_from_q512_fast(x::Qx512)
    special = qx128_special(x)
    special !== nothing && return special

    limit = Int1024(typemax(Int128)) * Int1024(x.den)
    magnitude = abs(Int1024(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational128s.posinf(Qx128) : XRationals.XRational128s.neginf(Qx128)
    end

    return Qx128(XRationals._nearest_rational128(x.num // x.den))
end

function qx256_from_q512_fast(x::Qx512)
    special = qx256_special(x)
    special !== nothing && return special

    limit = Int1024(typemax(Int256)) * Int1024(x.den)
    magnitude = abs(Int1024(x.num))
    if magnitude > limit
        return x.num > 0 ? XRationals.XRational256s.posinf(Qx256) : XRationals.XRational256s.neginf(Qx256)
    end

    return Qx256(XRationals._nearest_rational256(Int1024(x.num) // Int1024(x.den)))
end

export qx32_from_q64_fast,
    qx32_from_q128_fast,
    qx32_from_q256_fast,
    qx32_from_q512_fast,
    qx64_from_q128_fast,
    qx64_from_q256_fast,
    qx64_from_q512_fast,
    qx128_from_q256_fast,
    qx128_from_q512_fast,
    qx256_from_q512_fast

end # module WideToNarrowOptimized