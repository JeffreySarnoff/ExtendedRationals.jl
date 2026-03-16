module ExtendedRationals

export Qx32, Q32, Qx64, Q64, NaN, Inf, NegInf

include("ExtendedRationalInt32s.jl")
include("ExtendedRationalInt64s.jl")

const Qx32 = ExtendedRationalInt32s.ExtendedRational32
const Q32 = ExtendedRationalInt32s.Rational32
const Qx64 = ExtendedRationalInt64s.ExtendedRational64
const Q64 = ExtendedRationalInt64s.Rational64

NegInf(::Type{Qx32}) = ExtendedRationalInt32s.NegInf(Qx32)
NegInf(::Type{Qx64}) = ExtendedRationalInt64s.NegInf(Qx64)

end # module ExtendedRationals
