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

