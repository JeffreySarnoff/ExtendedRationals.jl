module ExtendedRationals

export Qx32, Q32, NaN, Inf, NegInf

include("ExtendedRationalInt32s.jl")

const Qx32 = ExtendedRationalInt32s.ExtendedRational32
const Q32 = ExtendedRationalInt32s.Rational32

end # module ExtendedRationals
