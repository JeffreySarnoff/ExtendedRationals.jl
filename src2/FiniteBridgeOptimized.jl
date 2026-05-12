module FiniteBridgeOptimized

using XRationals

import XRationals.XRational32s: XRational32, Rational32
import XRationals.XRational64s: XRational64, Rational64
import XRationals.XRational128s: XRational128, Rational128
import XRationals.XRational256s: XRational256, Rational256
import XRationals.XRational512s: XRational512, Rational512

const AnyQx = Union{XRational32,XRational64,XRational128,XRational256,XRational512}

@inline finite_fast(x::XRational32) = Rational32(x.num, x.den)
@inline finite_fast(x::XRational64) = Rational64(x.num, x.den)
@inline finite_fast(x::XRational128) = Rational128(x.num, x.den)
@inline finite_fast(x::XRational256) = Rational256(x.num, x.den)
@inline finite_fast(x::XRational512) = Rational512(x.num, x.den)

@inline function convert_rational_fast(x::XRational32)
    isfinite(x) || throw(InexactError(:convert, Rational32, x))
    return Rational32(x.num, x.den)
end

@inline function convert_rational_fast(x::XRational64)
    isfinite(x) || throw(InexactError(:convert, Rational64, x))
    return Rational64(x.num, x.den)
end

@inline function convert_rational_fast(x::XRational128)
    isfinite(x) || throw(InexactError(:convert, Rational128, x))
    return Rational128(x.num, x.den)
end

@inline function convert_rational_fast(x::XRational256)
    isfinite(x) || throw(InexactError(:convert, Rational256, x))
    return Rational256(x.num, x.den)
end

@inline function convert_rational_fast(x::XRational512)
    isfinite(x) || throw(InexactError(:convert, Rational512, x))
    return Rational512(x.num, x.den)
end

@inline _finite_nonzero_divisor(x::AnyQx, y::AnyQx) = x.den != 0 && y.den != 0 && y.num != 0
@inline _invalid_divisor_args(x::AnyQx, y::AnyQx) = isnan(x) || isnan(y) || isinf(x) || isinf(y) || iszero(y)

function rem_fast(x::T, y::T) where {T<:AnyQx}
    if _finite_nonzero_divisor(x, y)
        return T(rem(finite_fast(x), finite_fast(y)))
    elseif _invalid_divisor_args(x, y)
        return T(0, 0)
    end
end

function mod_fast(x::T, y::T) where {T<:AnyQx}
    if _finite_nonzero_divisor(x, y)
        return T(mod(finite_fast(x), finite_fast(y)))
    elseif _invalid_divisor_args(x, y)
        return T(0, 0)
    end
end

function fld_fast(x::T, y::T) where {T<:AnyQx}
    if _finite_nonzero_divisor(x, y)
        return fld(finite_fast(x), finite_fast(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fld requires finite nonzero divisor"))
    end
end

function cld_fast(x::T, y::T) where {T<:AnyQx}
    if _finite_nonzero_divisor(x, y)
        return cld(finite_fast(x), finite_fast(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "cld requires finite nonzero divisor"))
    end
end

function divrem_fast(x::T, y::T) where {T<:AnyQx}
    if _finite_nonzero_divisor(x, y)
        return divrem(finite_fast(x), finite_fast(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "divrem requires finite nonzero divisor"))
    end
end

function fldmod_fast(x::T, y::T) where {T<:AnyQx}
    if _finite_nonzero_divisor(x, y)
        return fldmod(finite_fast(x), finite_fast(y))
    end
    q = fld_fast(x, y)
    return q, mod_fast(x, y)
end

function fldmod1_fast(x::T, y::T) where {T<:AnyQx}
    if _finite_nonzero_divisor(x, y)
        return fldmod1(finite_fast(x), finite_fast(y))
    elseif _invalid_divisor_args(x, y)
        throw(DomainError((x, y), "fldmod1 requires finite nonzero divisor"))
    end
end

function fma_fast(x::T, y::T, z::T) where {T<:AnyQx}
    if x.den != 0 && y.den != 0 && z.den != 0
        return T(fma(finite_fast(x), finite_fast(y), finite_fast(z)))
    end
    return muladd(x, y, z)
end

export finite_fast,
    convert_rational_fast,
    rem_fast,
    mod_fast,
    fld_fast,
    cld_fast,
    divrem_fast,
    fldmod_fast,
    fldmod1_fast,
    fma_fast

end # module FiniteBridgeOptimized