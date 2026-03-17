using ExtendedRationals

# --- Exact rational arithmetic (no floating-point error) ---

a = Qx32(2, 3)          # 2//3
b = Qx32(5, 7)          # 5//7

println("Exact arithmetic:")
println("  $a + $b = $(a + b)")       # 29//21
println("  $a * $b = $(a * b)")       # 10//21
println("  $a / $b = $(a / b)")       # 14//15
println("  $a ^ 3  = $(a ^ 3)")       # 8//27
println()

# --- IEEE-like special values: NaN, Inf, -Inf ---

inf = Qx32(1, 0)       # Inf32
ninf = Qx32(-1, 0)      # -Inf32
nan = Qx32(0, 0)       # NaN32

println("Special values:")
println("  Inf:  $inf    isinf = $(isinf(inf))")
println("  -Inf: $ninf   signbit = $(signbit(ninf))")
println("  NaN:  $nan    isnan = $(isnan(nan))")
println()

# --- Overflow saturates to Inf instead of crashing ---

big_val = Qx32(typemax(Int32), 1)
println("Overflow policy (saturates to Inf):")
println("  $(big_val) + 1 = $(big_val + 1)")             # Inf32
println("  Inf + 5 = $(inf + Qx32(5, 1))")               # Inf32
println("  Inf + (-Inf) = $(inf + ninf)")                 # NaN32
println("  Inf * 0 = $(inf * Qx32(0, 1))")               # NaN32
println("  1/0 = $(Qx32(1, 2) / Qx32(0, 1))")           # Inf32
println("  0/0 = $(Qx32(0, 1) / Qx32(0, 1))")           # NaN32
println()

# --- 64-bit for more range ---

x = Qx64(typemax(Int64) - 1, 3)
y = Qx64(1, typemax(Int64))
println("64-bit precision:")
println("  x = $x")
println("  y = $y")
println("  x * y = $(x * y)")
println()

# --- Cross-width conversion (Qx64 -> Qx32 with best approximation) ---

wide = Qx64(355, 113)   # excellent pi approximation
narrow = Qx32(wide)
println("Cross-width conversion:")
println("  Qx64: $wide")
println("  Qx32: $narrow")
println()

# --- Fused multiply-add (exact intermediate, rounded result) ---

println("Fused multiply-add:")
println("  fma(2//3, 3//4, 1//2) = $(fma(Qx32(2,3), Qx32(3,4), Qx32(1,2)))")  # 1//1
println()

# --- Ordering respects IEEE semantics ---

vals = [Qx32(3, 2), Qx32(-1, 2), inf, ninf, Qx32(0, 1)]
println("Sorting: $(sort(vals))")
println("  NaN sorts last: $(sort([nan, Qx32(1,1), Qx32(-1,1)]))")
println()

# --- Strict (non-extended) rationals throw on overflow ---

println("Strict rationals (Q32/Q64) throw on overflow:")
try
    Q32(typemax(Int32), 1) + Q32(1, 1)
catch e
    println("  Q32 overflow: $(typeof(e))")
end
try
    Q32(typemin(Int32), 1)
catch e
    println("  Q32 rejects typemin: $(typeof(e))")
end
println()

# --- Zero-allocation arithmetic (no BigInt, all fixed-width) ---

println("Zero-allocation fixed-width arithmetic:")
println("  All operations use Int32/Int64/Int128/Int256/Int512 internally")
println("  No heap-allocated BigInt anywhere in the hot path")
println()

# fma with large args: exact intermediate in Int128 (Q32) or Int256 (Q64)
M32 = Qx32(typemax(Int32), 2)
println("  Qx32 fma (Int128 intermediate):")
println("    fma($M32, $M32, $(Qx32(1,1))) = $(fma(M32, M32, Qx32(1,1)))")

M64 = Qx64(typemax(Int64), 2)
N64 = Qx64(typemax(Int64), 3)
Z64 = Qx64(typemax(Int64), 5)
println("  Qx64 fma (Int256 intermediate):")
println("    fma($M64, $N64, $Z64) = $(fma(M64, N64, Z64))")
println()

# Nearest rational approximation: Stern-Brocot in Int128 (Q32) or Int256 (Q64)
println("  Nearest-rational approximation (Stern-Brocot with Int256 convergents):")
r = fma(Qx64(typemax(Int64)-1, 1), Qx64(1, typemax(Int64)), Qx64(1, typemax(Int64)))
println("    fma($(typemax(Int64)-1)//1, 1//$(typemax(Int64)), 1//$(typemax(Int64))) = $r")

# Show the speed advantage with a timed comparison
println()
using Chairmarks
t = @be fma($M64, $N64, $Z64)
println("  fma(Qx64, Qx64, Qx64) benchmark: $(round(minimum(t).time * 1e9, digits=0))ns median, 0 allocations")
println()

# --- Lazy normalization for maximum throughput ---

println("Lazy normalization (Qx32/Qx64):")
println("  Qx32 uses Int64 intermediates (native 64-bit ops)")
println("  Qx64 uses Int128 intermediates")
println("  GCD normalization is deferred until display, hashing, or conversion")
println()

# Lazy storage: 6//8 stays unnormalized internally, normalizes on display
raw = Qx32(6, 8)
println("  Qx32(6, 8) displays as: $raw  (normalized on output)")
println("  Qx32(6, 8) == Qx32(3, 4)? $(raw == Qx32(3, 4))  (cross-multiply comparison)")
println()

# Chained operations show the biggest speedup (no intermediate GCDs)
println("  Chained operations (where lazy normalization shines):")
c32, d32 = Qx32(3, 13), Qx32(11, 7)
println("    Qx32: a+b+c+d = $(a + b + c32 + d32)")
println("    Qx32: a*b-c*d = $(a * b - c32 * d32)")

a64, b64 = Qx64(2, 3), Qx64(5, 7)
c64, d64 = Qx64(3, 13), Qx64(11, 7)
println("    Qx64: a+b+c+d = $(a64 + b64 + c64 + d64)")
println("    Qx64: a*b-c*d = $(a64 * b64 - c64 * d64)")
println()

# Benchmark: Qx32 vs Rational{Int32}
println("  Speed comparison (chained a+b+c+d):")
ar32, br32, cr32, dr32 = Rational{Int32}(Int32(2),Int32(3)), Rational{Int32}(Int32(5),Int32(7)), Rational{Int32}(Int32(3),Int32(13)), Rational{Int32}(Int32(11),Int32(7))
t_std32 = @be $ar32 + $br32 + $cr32 + $dr32
t_qx32 = @be $a + $b + $c32 + $d32
println("    Rational{Int32}: $(round(minimum(t_std32).time * 1e9, digits=0))ns")
println("    Qx32:            $(round(minimum(t_qx32).time * 1e9, digits=0))ns")
println("    Speedup:         $(round(minimum(t_std32).time / minimum(t_qx32).time, digits=1))x")

ar64, br64, cr64, dr64 = Rational{Int64}(7,3), Rational{Int64}(5,11), Rational{Int64}(3,13), Rational{Int64}(11,7)
t_std64 = @be $ar64 + $br64 + $cr64 + $dr64
t_qx64 = @be $a64 + $b64 + $c64 + $d64
println("    Rational{Int64}: $(round(minimum(t_std64).time * 1e9, digits=0))ns")
println("    Qx64:            $(round(minimum(t_qx64).time * 1e9, digits=0))ns")
println("    Speedup:         $(round(minimum(t_std64).time / minimum(t_qx64).time, digits=1))x")
