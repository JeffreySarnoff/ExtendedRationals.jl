using ExtendedRationals
using Test

include("Rational32s_tests.jl")
include("Rational64s_tests.jl")
include("XRational32s_tests.jl")
include("XRational64s_tests.jl")
include("CrossWidth_tests.jl")

#@testset "ExtendedRationals.jl" begin
#    @testset "Code quality (Aqua.jl)" begin
#        Aqua.test_all(ExtendedRationals)
#    end
#end
