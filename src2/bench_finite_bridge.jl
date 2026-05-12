using XRationals
using Chairmarks
using BitIntegers: Int256, Int512

include(joinpath(@__DIR__, "FiniteBridgeOptimized.jl"))
using .FiniteBridgeOptimized

function fmt_ns(sample)
    ns = minimum(sample).time * 1e9
    if ns < 1000
        return "$(round(ns, digits=1)) ns"
    elseif ns < 1_000_000
        return "$(round(ns / 1000, digits=1)) us"
    else
        return "$(round(ns / 1_000_000, digits=1)) ms"
    end
end

function speedup(base_sample, opt_sample)
    round((minimum(base_sample).time * 1e9) / (minimum(opt_sample).time * 1e9), digits=2)
end

println("Finite bridge benchmark")
println("Current src behavior vs src2 one-pass finite-conversion prototype")

conversion_cases = [
    ("Qx32", Qx32(6, 8), x -> convert(Rational{Int32}, x), x -> convert_rational_fast(x)),
    ("Qx64", Qx64(6, 8), x -> convert(Rational{Int64}, x), x -> convert_rational_fast(x)),
    ("Qx128", Qx128(6, 8), x -> convert(Rational{Int128}, x), x -> convert_rational_fast(x)),
    ("Qx256", Qx256(6, 8), x -> convert(Rational{Int256}, x), x -> convert_rational_fast(x)),
    ("Qx512", Qx512(6, 8), x -> convert(Rational{Int512}, x), x -> convert_rational_fast(x)),
]

println("\n## Rational conversion")
println("| Type | Current | src2 | Speedup |")
println("| --- | ---: | ---: | ---: |")
for (label, x, current, optimized) in conversion_cases
    base_sample = @be $current($x)
    opt_sample = @be $optimized($x)
    println("| $(label) | $(fmt_ns(base_sample)) | $(fmt_ns(opt_sample)) | $(speedup(base_sample, opt_sample))x |")
end

fma_cases = [
    ("Qx32", Qx32(7, 3), Qx32(5, 11), Qx32(7, 3)),
    ("Qx64", Qx64(7, 3), Qx64(5, 11), Qx64(7, 3)),
    ("Qx128", Qx128(7, 3), Qx128(5, 11), Qx128(7, 3)),
    ("Qx256", Qx256(7, 3), Qx256(5, 11), Qx256(7, 3)),
    ("Qx512", Qx512(7, 3), Qx512(5, 11), Qx512(7, 3)),
]

println("\n## fma")
println("| Type | Current | src2 | Speedup |")
println("| --- | ---: | ---: | ---: |")
for (label, x, y, z) in fma_cases
    base_sample = @be fma($x, $y, $z)
    opt_sample = @be fma_fast($x, $y, $z)
    println("| $(label) | $(fmt_ns(base_sample)) | $(fmt_ns(opt_sample)) | $(speedup(base_sample, opt_sample))x |")
end