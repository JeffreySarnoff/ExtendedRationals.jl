module ExtendedRationals

export Qx32

include("ExtendedRationalInt32s.jl") 
const Qx32 = ExtendedRationals.ExtendedRationalInt32s.ExtendedRational32

end # module ExtendedRationals
