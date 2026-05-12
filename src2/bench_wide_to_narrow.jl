using XRationals
using Chairmarks
using BitIntegers: Int256, Int512

include(joinpath(@__DIR__, "WideToNarrowOptimized.jl"))
using .WideToNarrowOptimized

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

speedup(base_sample, opt_sample) = round((minimum(base_sample).time * 1e9) / (minimum(opt_sample).time * 1e9), digits=2)

println("Wide-to-narrow benchmark")
println("Current src constructors vs src2 raw-field narrowing prototype")

rows = [
    ("Qx64 -> Qx32 exact-ish", x -> Qx32(x), x -> qx32_from_q64_fast(x), Qx64(6, 8)),
    ("Qx64 -> Qx32 approx", x -> Qx32(x), x -> qx32_from_q64_fast(x), Qx64(Int64(typemax(Int32)) + 1, Int64(typemax(Int32)) + 3)),
    ("Qx128 -> Qx32 exact-ish", x -> Qx32(x), x -> qx32_from_q128_fast(x), Qx128(6, 8)),
    ("Qx128 -> Qx32 approx", x -> Qx32(x), x -> qx32_from_q128_fast(x), Qx128(Int128(typemax(Int32)) + 1, Int128(typemax(Int32)) + 3)),
    ("Qx256 -> Qx32 exact-ish", x -> Qx32(x), x -> qx32_from_q256_fast(x), Qx256(6, 8)),
    ("Qx256 -> Qx32 approx", x -> Qx32(x), x -> qx32_from_q256_fast(x), Qx256(Int256(typemax(Int32)) + 1, Int256(typemax(Int32)) + 3)),
    ("Qx512 -> Qx32 exact-ish", x -> Qx32(x), x -> qx32_from_q512_fast(x), Qx512(6, 8)),
    ("Qx512 -> Qx32 approx", x -> Qx32(x), x -> qx32_from_q512_fast(x), Qx512(Int512(typemax(Int32)) + 1, Int512(typemax(Int32)) + 3)),
    ("Qx128 -> Qx64 exact-ish", x -> Qx64(x), x -> qx64_from_q128_fast(x), Qx128(6, 8)),
    ("Qx128 -> Qx64 approx", x -> Qx64(x), x -> qx64_from_q128_fast(x), Qx128(Int128(typemax(Int64)) + 1, Int128(typemax(Int64)) + 3)),
    ("Qx256 -> Qx64 exact-ish", x -> Qx64(x), x -> qx64_from_q256_fast(x), Qx256(6, 8)),
    ("Qx256 -> Qx64 approx", x -> Qx64(x), x -> qx64_from_q256_fast(x), Qx256(Int256(typemax(Int64)) + 1, Int256(typemax(Int64)) + 3)),
    ("Qx512 -> Qx64 exact-ish", x -> Qx64(x), x -> qx64_from_q512_fast(x), Qx512(6, 8)),
    ("Qx512 -> Qx64 approx", x -> Qx64(x), x -> qx64_from_q512_fast(x), Qx512(Int512(typemax(Int64)) + 1, Int512(typemax(Int64)) + 3)),
    ("Qx256 -> Qx128 exact-ish", x -> Qx128(x), x -> qx128_from_q256_fast(x), Qx256(6, 8)),
    ("Qx256 -> Qx128 approx", x -> Qx128(x), x -> qx128_from_q256_fast(x), Qx256(Int256(typemax(Int128)) + 1, Int256(typemax(Int128)) + 3)),
    ("Qx512 -> Qx128 exact-ish", x -> Qx128(x), x -> qx128_from_q512_fast(x), Qx512(6, 8)),
    ("Qx512 -> Qx128 approx", x -> Qx128(x), x -> qx128_from_q512_fast(x), Qx512(Int512(typemax(Int128)) + 1, Int512(typemax(Int128)) + 3)),
    ("Qx512 -> Qx256 exact-ish", x -> Qx256(x), x -> qx256_from_q512_fast(x), Qx512(6, 8)),
    ("Qx512 -> Qx256 approx", x -> Qx256(x), x -> qx256_from_q512_fast(x), Qx512(Int512(typemax(Int256)) + 1, Int512(typemax(Int256)) + 3)),
]

println("| Conversion | Current | src2 | Speedup |")
println("| --- | ---: | ---: | ---: |")
for (label, current, optimized, value) in rows
    base_sample = @be $current($value)
    opt_sample = @be $optimized($value)
    println("| $(label) | $(fmt_ns(base_sample)) | $(fmt_ns(opt_sample)) | $(speedup(base_sample, opt_sample))x |")
end