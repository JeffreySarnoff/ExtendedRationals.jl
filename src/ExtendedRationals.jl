module ExtendedRationals

export Qx32, Q32

include("ExtendedRationalInt32s.jl") 
const Qx32 = ExtendedRationals.ExtendedRationalInt32s.ExtendedRational32
const Q32 = ExtendedRationals.RationalInt32s.Rational32

end # module ExtendedRationals
