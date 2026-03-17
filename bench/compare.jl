using ExtendedRationals
using Chairmarks

function fmt_ns(t)
    ns = minimum(t).time * 1e9
    if ns < 1000
        return lpad("$(round(Int, ns)) ns", 10)
    else
        return lpad("$(round(ns/1000, digits=1)) μs", 10)
    end
end

function fmt_allocs(t)
    a = minimum(t).allocs
    return lpad(a == 0 ? "0" : "$a", 6)
end

function run_table(label, R, Q, Qx, make_r, make_q, make_qx)
    a_r, b_r = make_r(7, 3), make_r(5, 11)
    a_q, b_q = make_q(7, 3), make_q(5, 11)
    a_x, b_x = make_qx(7, 3), make_qx(5, 11)

    big_r = make_r(typemax(R) - 1, 3)
    big_q = make_q(typemax(R) - 1, 3)
    big_x = make_qx(typemax(R) - 1, 3)

    small_r = make_r(1, typemax(R))
    small_q = make_q(1, typemax(R))
    small_x = make_qx(1, typemax(R))

    ops = []

    # Construction
    push!(ops, ("construct(7,3)",
        @be(make_r(7, 3)),
        @be(make_q(7, 3)),
        @be(make_qx(7, 3))))

    # Addition
    push!(ops, ("a + b",
        @be($a_r + $b_r),
        @be($a_q + $b_q),
        @be($a_x + $b_x)))

    # Subtraction
    push!(ops, ("a - b",
        @be($a_r - $b_r),
        @be($a_q - $b_q),
        @be($a_x - $b_x)))

    # Multiplication
    push!(ops, ("a * b",
        @be($a_r * $b_r),
        @be($a_q * $b_q),
        @be($a_x * $b_x)))

    # Division
    push!(ops, ("a / b",
        @be($a_r / $b_r),
        @be($a_q / $b_q),
        @be($a_x / $b_x)))

    # Negation
    push!(ops, ("-a",
        @be(-$a_r),
        @be(-$a_q),
        @be(-$a_x)))

    # Comparison
    push!(ops, ("a < b",
        @be($a_r < $b_r),
        @be($a_q < $b_q),
        @be($a_x < $b_x)))

    # Equality
    push!(ops, ("a == b",
        @be($a_r == $b_r),
        @be($a_q == $b_q),
        @be($a_x == $b_x)))

    # abs
    push!(ops, ("abs(-a)",
        @be(abs(-$a_r)),
        @be(abs(-$a_q)),
        @be(abs(-$a_x))))

    # inv
    push!(ops, ("inv(a)",
        @be(inv($a_r)),
        @be(inv($a_q)),
        @be(inv($a_x))))

    # Power
    push!(ops, ("a ^ 3",
        @be($a_r ^ 3),
        @be($a_q ^ 3),
        @be($a_x ^ 3)))

    # muladd
    push!(ops, ("muladd(a,b,a)",
        @be(muladd($a_r, $b_r, $a_r)),
        @be(muladd($a_q, $b_q, $a_q)),
        @be(muladd($a_x, $b_x, $a_x))))

    # fma
    push!(ops, ("fma(a,b,a)",
        @be(fma($a_r, $b_r, $a_r)),
        @be(fma($a_q, $b_q, $a_q)),
        @be(fma($a_x, $b_x, $a_x))))

    # Large value addition (overflow-prone)
    push!(ops, ("big + big",
        nothing,
        nothing,
        @be($big_x + $big_x)))

    # Inf arithmetic (Qx only)
    inf_x = make_qx(1, 0)
    push!(ops, ("Inf + a",
        nothing,
        nothing,
        @be($inf_x + $a_x)))

    r_label = "Rational{$(R)}"
    q_label = R == Int32 ? "Q32" : "Q64"
    qx_label = R == Int32 ? "Qx32" : "Qx64"

    println("\n$label")
    println("=" ^ 80)
    header = rpad("Operation", 18) *
             rpad(r_label, 20) *
             rpad(q_label, 20) *
             rpad(qx_label, 20)
    println(header)
    println("-" ^ 80)

    for (name, tr, tq, tx) in ops
        r_str = tr === nothing ? lpad("---", 10) * lpad("", 6) : fmt_ns(tr) * fmt_allocs(tr)
        q_str = tq === nothing ? lpad("---", 10) * lpad("", 6) : fmt_ns(tq) * fmt_allocs(tq)
        x_str = tx === nothing ? lpad("---", 10) * lpad("", 6) : fmt_ns(tx) * fmt_allocs(tx)
        println(rpad(name, 18) * rpad(r_str, 20) * rpad(q_str, 20) * rpad(x_str, 20))
    end
    println("=" ^ 80)
    println("  (time = min ns, allocs = min allocations)")
end

# --- 32-bit table ---

run_table(
    "32-bit Rational Comparison",
    Int32,
    ExtendedRationals.Q32,
    ExtendedRationals.Qx32,
    (n, d) -> Rational{Int32}(Int32(n), Int32(d)),
    (n, d) -> Q32(n, d),
    (n, d) -> Qx32(n, d)
)

# --- 64-bit table ---

run_table(
    "64-bit Rational Comparison",
    Int64,
    ExtendedRationals.Q64,
    ExtendedRationals.Qx64,
    (n, d) -> Rational{Int64}(Int64(n), Int64(d)),
    (n, d) -> Q64(n, d),
    (n, d) -> Qx64(n, d)
)
