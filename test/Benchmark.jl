using XRationals
using Chairmarks
using BitIntegers: Int256, Int512

function fmt_ns(sample)
    ns = minimum(sample).time * 1e9
    if ns < 1000
        return "$(round(Int, ns)) ns"
    elseif ns < 1_000_000
        return "$(round(ns / 1000, digits=1)) us"
    else
        return "$(round(ns / 1_000_000, digits=1)) ms"
    end
end

function speedup_str(base_sample, qx_sample)
    base_ns = minimum(base_sample).time * 1e9
    qx_ns = minimum(qx_sample).time * 1e9
    ratio = base_ns / qx_ns
    return ratio >= 1.05 ? "$(round(ratio, digits=1))x" : (ratio <= 0.95 ? "$(round(ratio, digits=2))x" : "~1x")
end

function run_table(label, inttype, make_rational, make_qx, qx_label)
    a_r, b_r = make_rational(7, 3), make_rational(5, 11)
    c_r, d_r = make_rational(3, 13), make_rational(11, 7)
    a_x, b_x = make_qx(7, 3), make_qx(5, 11)
    c_x, d_x = make_qx(3, 13), make_qx(11, 7)

    ops = [
        ("construct(7,3)", @be(make_rational(7, 3)), @be(make_qx(7, 3))),
        ("a + b", @be($a_r + $b_r), @be($a_x + $b_x)),
        ("a - b", @be($a_r - $b_r), @be($a_x - $b_x)),
        ("a * b", @be($a_r * $b_r), @be($a_x * $b_x)),
        ("a / b", @be($a_r / $b_r), @be($a_x / $b_x)),
        ("-a", @be(-$a_r), @be(-$a_x)),
        ("a < b", @be($a_r < $b_r), @be($a_x < $b_x)),
        ("a == b", @be($a_r == $b_r), @be($a_x == $b_x)),
        ("abs(-a)", @be(abs(-$a_r)), @be(abs(-$a_x))),
        ("inv(a)", @be(inv($a_r)), @be(inv($a_x))),
        ("a ^ 3", @be($a_r^3), @be($a_x^3)),
        ("a+b+c+d", @be($a_r + $b_r + $c_r + $d_r), @be($a_x + $b_x + $c_x + $d_x)),
        ("a*b-c*d", @be($a_r * $b_r - $c_r * $d_r), @be($a_x * $b_x - $c_x * $d_x)),
        ("muladd(a,b,a)", @be(muladd($a_r, $b_r, $a_r)), @be(muladd($a_x, $b_x, $a_x))),
        ("fma(a,b,a)", @be(fma($a_r, $b_r, $a_r)), @be(fma($a_x, $b_x, $a_x))),
    ]

    println("\n### $(label)\n")
    println("| Operation | `Rational{$(inttype)}` | `$(qx_label)` | Speedup |")
    println("| --- | --- | --- | --- |")

    for (name, base_sample, qx_sample) in ops
        println("| $(name) | $(fmt_ns(base_sample)) | $(fmt_ns(qx_sample)) | $(speedup_str(base_sample, qx_sample)) |")
    end
end

println("XRationals benchmark report")
println("Run with: julia --project=. test/Benchmark.jl")

run_table(
    "32-bit",
    Int32,
    (n, d) -> Rational{Int32}(Int32(n), Int32(d)),
    (n, d) -> Qx32(n, d),
    "Qx32",
)

run_table(
    "64-bit",
    Int64,
    (n, d) -> Rational{Int64}(Int64(n), Int64(d)),
    (n, d) -> Qx64(n, d),
    "Qx64",
)

run_table(
    "128-bit",
    Int128,
    (n, d) -> Rational{Int128}(Int128(n), Int128(d)),
    (n, d) -> Qx128(n, d),
    "Qx128",
)

run_table(
    "256-bit",
    Int256,
    (n, d) -> Rational{Int256}(Int256(n), Int256(d)),
    (n, d) -> Qx256(n, d),
    "Qx256",
)

run_table(
    "512-bit",
    Int512,
    (n, d) -> Rational{Int512}(Int512(n), Int512(d)),
    (n, d) -> Qx512(n, d),
    "Qx512",
)