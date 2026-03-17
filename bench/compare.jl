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

function run_table(label, R, Q, Qx, make_r, make_q, make_qx; Qxf=nothing, make_qxf=nothing)
    a_r, b_r = make_r(7, 3), make_r(5, 11)
    c_r, d_r = make_r(3, 13), make_r(11, 7)
    a_q, b_q = make_q(7, 3), make_q(5, 11)
    c_q, d_q = make_q(3, 13), make_q(11, 7)
    a_x, b_x = make_qx(7, 3), make_qx(5, 11)
    c_x, d_x = make_qx(3, 13), make_qx(11, 7)

    big_x = make_qx(typemax(R) - 1, 3)

    has_fast = Qxf !== nothing && make_qxf !== nothing
    a_f = has_fast ? make_qxf(7, 3) : nothing
    b_f = has_fast ? make_qxf(5, 11) : nothing
    c_f = has_fast ? make_qxf(3, 13) : nothing
    d_f = has_fast ? make_qxf(11, 7) : nothing
    big_f = has_fast ? make_qxf(typemax(R) - 1, 3) : nothing

    ops = []

    push!(ops, ("construct(7,3)",
        @be(make_r(7, 3)),
        @be(make_q(7, 3)),
        @be(make_qx(7, 3)),
        has_fast ? @be(make_qxf(7, 3)) : nothing))

    push!(ops, ("a + b",
        @be($a_r + $b_r),
        @be($a_q + $b_q),
        @be($a_x + $b_x),
        has_fast ? @be($a_f + $b_f) : nothing))

    push!(ops, ("a - b",
        @be($a_r - $b_r),
        @be($a_q - $b_q),
        @be($a_x - $b_x),
        has_fast ? @be($a_f - $b_f) : nothing))

    push!(ops, ("a * b",
        @be($a_r * $b_r),
        @be($a_q * $b_q),
        @be($a_x * $b_x),
        has_fast ? @be($a_f * $b_f) : nothing))

    push!(ops, ("a / b",
        @be($a_r / $b_r),
        @be($a_q / $b_q),
        @be($a_x / $b_x),
        has_fast ? @be($a_f / $b_f) : nothing))

    push!(ops, ("-a",
        @be(-$a_r),
        @be(-$a_q),
        @be(-$a_x),
        has_fast ? @be(-$a_f) : nothing))

    push!(ops, ("a < b",
        @be($a_r < $b_r),
        @be($a_q < $b_q),
        @be($a_x < $b_x),
        has_fast ? @be($a_f < $b_f) : nothing))

    push!(ops, ("a == b",
        @be($a_r == $b_r),
        @be($a_q == $b_q),
        @be($a_x == $b_x),
        has_fast ? @be($a_f == $b_f) : nothing))

    push!(ops, ("abs(-a)",
        @be(abs(-$a_r)),
        @be(abs(-$a_q)),
        @be(abs(-$a_x)),
        has_fast ? @be(abs(-$a_f)) : nothing))

    push!(ops, ("inv(a)",
        @be(inv($a_r)),
        @be(inv($a_q)),
        @be(inv($a_x)),
        has_fast ? @be(inv($a_f)) : nothing))

    push!(ops, ("a ^ 3",
        @be($a_r ^ 3),
        @be($a_q ^ 3),
        @be($a_x ^ 3),
        has_fast ? @be($a_f ^ 3) : nothing))

    push!(ops, ("a+b+c+d",
        @be($a_r + $b_r + $c_r + $d_r),
        @be($a_q + $b_q + $c_q + $d_q),
        @be($a_x + $b_x + $c_x + $d_x),
        has_fast ? @be($a_f + $b_f + $c_f + $d_f) : nothing))

    push!(ops, ("a*b-c*d",
        @be($a_r * $b_r - $c_r * $d_r),
        @be($a_q * $b_q - $c_q * $d_q),
        @be($a_x * $b_x - $c_x * $d_x),
        has_fast ? @be($a_f * $b_f - $c_f * $d_f) : nothing))

    push!(ops, ("muladd(a,b,a)",
        @be(muladd($a_r, $b_r, $a_r)),
        @be(muladd($a_q, $b_q, $a_q)),
        @be(muladd($a_x, $b_x, $a_x)),
        has_fast ? @be(muladd($a_f, $b_f, $a_f)) : nothing))

    push!(ops, ("fma(a,b,a)",
        @be(fma($a_r, $b_r, $a_r)),
        @be(fma($a_q, $b_q, $a_q)),
        @be(fma($a_x, $b_x, $a_x)),
        has_fast ? @be(fma($a_f, $b_f, $a_f)) : nothing))

    push!(ops, ("big + big",
        nothing, nothing,
        @be($big_x + $big_x),
        has_fast ? @be($big_f + $big_f) : nothing))

    inf_x = make_qx(1, 0)
    inf_f = has_fast ? make_qxf(1, 0) : nothing
    push!(ops, ("Inf + a",
        nothing, nothing,
        @be($inf_x + $a_x),
        has_fast ? @be($inf_f + $a_f) : nothing))

    r_label = "Rational{$(R)}"
    q_label = R == Int32 ? "Q32" : "Q64"
    qx_label = R == Int32 ? "Qx32" : "Qx64"
    qxf_label = has_fast ? "Qxf64" : ""

    ncols = has_fast ? 5 : 4
    colw = 20
    w = 18 + ncols * colw

    println("\n$label")
    println("=" ^ w)
    header = rpad("Operation", 18) *
             rpad(r_label, colw) *
             rpad(q_label, colw) *
             rpad(qx_label, colw)
    if has_fast
        header *= rpad(qxf_label, colw)
    end
    println(header)
    println("-" ^ w)

    for (name, tr, tq, tx, tf) in ops
        r_str = tr === nothing ? lpad("---", 10) * lpad("", 6) : fmt_ns(tr) * fmt_allocs(tr)
        q_str = tq === nothing ? lpad("---", 10) * lpad("", 6) : fmt_ns(tq) * fmt_allocs(tq)
        x_str = tx === nothing ? lpad("---", 10) * lpad("", 6) : fmt_ns(tx) * fmt_allocs(tx)
        line = rpad(name, 18) * rpad(r_str, colw) * rpad(q_str, colw) * rpad(x_str, colw)
        if has_fast
            f_str = tf === nothing ? lpad("---", 10) * lpad("", 6) : fmt_ns(tf) * fmt_allocs(tf)
            line *= rpad(f_str, colw)
        end
        println(line)
    end
    println("=" ^ w)
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
    (n, d) -> Qx64(n, d);
    Qxf=ExtendedRationals.Qxf64,
    make_qxf=(n, d) -> Qxf64(n, d)
)

# --- Qxf64 vs Rational{Int64} speedup table ---

function run_speedup_table()
    make_r = (n, d) -> Rational{Int64}(Int64(n), Int64(d))
    make_f = (n, d) -> Qxf64(n, d)

    a_r, b_r = make_r(7, 3), make_r(5, 11)
    c_r, d_r = make_r(3, 13), make_r(11, 7)
    a_f, b_f = make_f(7, 3), make_f(5, 11)
    c_f, d_f = make_f(3, 13), make_f(11, 7)

    ops = [
        ("construct(7,3)", @be(make_r(7, 3)),           @be(make_f(7, 3))),
        ("a + b",          @be($a_r + $b_r),            @be($a_f + $b_f)),
        ("a - b",          @be($a_r - $b_r),            @be($a_f - $b_f)),
        ("a * b",          @be($a_r * $b_r),            @be($a_f * $b_f)),
        ("a / b",          @be($a_r / $b_r),            @be($a_f / $b_f)),
        ("-a",             @be(-$a_r),                   @be(-$a_f)),
        ("a < b",          @be($a_r < $b_r),            @be($a_f < $b_f)),
        ("a == b",         @be($a_r == $b_r),           @be($a_f == $b_f)),
        ("abs(-a)",        @be(abs(-$a_r)),              @be(abs(-$a_f))),
        ("inv(a)",         @be(inv($a_r)),               @be(inv($a_f))),
        ("a ^ 3",          @be($a_r ^ 3),               @be($a_f ^ 3)),
        ("a+b+c+d",        @be($a_r+$b_r+$c_r+$d_r),   @be($a_f+$b_f+$c_f+$d_f)),
        ("a*b-c*d",        @be($a_r*$b_r-$c_r*$d_r),   @be($a_f*$b_f-$c_f*$d_f)),
        ("muladd(a,b,a)",  @be(muladd($a_r,$b_r,$a_r)), @be(muladd($a_f,$b_f,$a_f))),
        ("fma(a,b,a)",     @be(fma($a_r,$b_r,$a_r)),    @be(fma($a_f,$b_f,$a_f))),
    ]

    colw = 22
    w = 18 + 3 * colw
    println("\nQxf64 vs Rational{Int64} Speedup")
    println("=" ^ w)
    println(rpad("Operation", 18) * rpad("Rational{Int64}", colw) * rpad("Qxf64", colw) * rpad("Speedup", colw))
    println("-" ^ w)

    for (name, tr, tf) in ops
        r_ns = minimum(tr).time * 1e9
        f_ns = minimum(tf).time * 1e9
        spd = r_ns / f_ns
        spd_str = spd >= 1.05 ? "$(round(spd, digits=1))x" : (spd <= 0.95 ? "$(round(spd, digits=2))x" : "~1x")
        println(rpad(name, 18) *
                rpad(fmt_ns(tr) * fmt_allocs(tr), colw) *
                rpad(fmt_ns(tf) * fmt_allocs(tf), colw) *
                rpad(lpad(spd_str, 10), colw))
    end
    println("=" ^ w)
end

run_speedup_table()
