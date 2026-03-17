using Chairmarks

# Benchmark strategies for rejecting typemin(IntN) inputs in constructors.
#
# The goal: Rational32(typemin(Int32), x) and Rational32(x, typemin(Int32))
# must throw OverflowError. Same for Int64 variants.
#
# We benchmark only the guard itself on the hot path (valid inputs).

const TMIN32 = typemin(Int32)
const TMIN64 = typemin(Int64)

# --- Strategy A: two separate == checks ---
@inline function guard_a32(num::Int32, den::Int32)
    num == TMIN32 && throw(OverflowError("typemin disallowed"))
    den == TMIN32 && throw(OverflowError("typemin disallowed"))
    return nothing
end
@inline function guard_a64(num::Int64, den::Int64)
    num == TMIN64 && throw(OverflowError("typemin disallowed"))
    den == TMIN64 && throw(OverflowError("typemin disallowed"))
    return nothing
end

# --- Strategy B: combined OR ---
@inline function guard_b32(num::Int32, den::Int32)
    (num == TMIN32 || den == TMIN32) && throw(OverflowError("typemin disallowed"))
    return nothing
end
@inline function guard_b64(num::Int64, den::Int64)
    (num == TMIN64 || den == TMIN64) && throw(OverflowError("typemin disallowed"))
    return nothing
end

# --- Strategy C: bitwise OR then single compare ---
# typemin has only the sign bit set, so (num | den) has sign bit set iff
# at least one is negative. But that's too broad. Instead:
# typemin is the ONLY value where x == -x (besides 0), or equivalently
# where x < 0 && x == -x. But -typemin overflows to typemin in Int.
# Better: typemin is the only negative value with trailing_zeros == nbits-1.
# Simplest branchless: reinterpret and check.
@inline function guard_c32(num::Int32, den::Int32)
    # typemin(Int32) == Int32(-2147483648) == 0x80000000
    # Only value with unsigned repr 0x80000000
    (reinterpret(UInt32, num) == 0x80000000 || reinterpret(UInt32, den) == 0x80000000) && throw(OverflowError("typemin disallowed"))
    return nothing
end
@inline function guard_c64(num::Int64, den::Int64)
    (reinterpret(UInt64, num) == 0x8000000000000000 || reinterpret(UInt64, den) == 0x8000000000000000) && throw(OverflowError("typemin disallowed"))
    return nothing
end

# --- Strategy D: tighten bounds in checked_int (> typemin instead of >=) ---
# This doesn't guard the constructor input, but guards checked_int output.
# For benchmarking we compare the range check cost.
@inline function checked_d32(x::Integer)
    typemin(Int32) < x <= typemax(Int32) || throw(OverflowError("value out of range"))
    return Int32(x)
end
@inline function checked_orig32(x::Integer)
    typemin(Int32) <= x <= typemax(Int32) || throw(OverflowError("value out of range"))
    return Int32(x)
end
@inline function checked_d64(x::Integer)
    typemin(Int64) < x <= typemax(Int64) || throw(OverflowError("value out of range"))
    return Int64(x)
end
@inline function checked_orig64(x::Integer)
    typemin(Int64) <= x <= typemax(Int64) || throw(OverflowError("value out of range"))
    return Int64(x)
end

# --- Strategy E: single bitwise trick: (num & den) cannot have only sign bit ---
# Actually: use addition. typemin + typemin overflows, but we want to detect either.
# Let's try: abs-based. abs(typemin) overflows. Not helpful.
# Try: check sign bit AND all other bits zero via bitwise.
@inline function guard_e32(num::Int32, den::Int32)
    # For each: x == typemin iff (x >> 31) != 0 && (x & typemax(Int32)) == 0
    m = Int32(0)
    m |= num & ~typemax(Int32)  # extracts sign bit of num (either 0 or typemin)
    m |= den & ~typemax(Int32)  # extracts sign bit of den
    # but this fires for ANY negative... need to also check lower bits are zero
    bad_num = (num < 0) & (num & typemax(Int32) == 0)
    bad_den = (den < 0) & (den & typemax(Int32) == 0)
    (bad_num | bad_den) && throw(OverflowError("typemin disallowed"))
    return nothing
end

# === Benchmark data ===
const nums32 = Int32[-99, -7, -3, -1, 1, 3, 7, 99]
const dens32 = Int32[1, 2, 3, 5, 7, 11, 13, 97]
const pairs32 = [(n, d) for n in nums32 for d in dens32]

const nums64 = Int64[-99, -7, -3, -1, 1, 3, 7, 99]
const dens64 = Int64[1, 2, 3, 5, 7, 11, 13, 97]
const pairs64 = [(n, d) for n in nums64 for d in dens64]

const wide_vals = Int64[-99, -7, -3, -1, 0, 1, 3, 7, 99]

println("=== Int32 guard strategies (64 valid pairs) ===")
print("  A (two ==):         "); display(@be (for (n,d) in $pairs32; guard_a32(n,d); end))
print("  B (combined OR):    "); display(@be (for (n,d) in $pairs32; guard_b32(n,d); end))
print("  C (reinterpret):    "); display(@be (for (n,d) in $pairs32; guard_c32(n,d); end))
print("  E (bitwise):        "); display(@be (for (n,d) in $pairs32; guard_e32(n,d); end))

println("\n=== Int64 guard strategies (64 valid pairs) ===")
print("  A (two ==):         "); display(@be (for (n,d) in $pairs64; guard_a64(n,d); end))
print("  B (combined OR):    "); display(@be (for (n,d) in $pairs64; guard_b64(n,d); end))
print("  C (reinterpret):    "); display(@be (for (n,d) in $pairs64; guard_c64(n,d); end))

println("\n=== checked_int32: orig vs tightened (on Int64 inputs) ===")
print("  orig (>= typemin):  "); display(@be (for v in $wide_vals; checked_orig32(v); end))
print("  tight (> typemin):  "); display(@be (for v in $wide_vals; checked_d32(v); end))

println("\n=== checked_int64: orig vs tightened (on Int128 inputs) ===")
const wide_vals128 = Int128[-99, -7, -3, -1, 0, 1, 3, 7, 99]
print("  orig (>= typemin):  "); display(@be (for v in $wide_vals128; checked_orig64(v); end))
print("  tight (> typemin):  "); display(@be (for v in $wide_vals128; checked_d64(v); end))

println("\n=== Full constructor simulation: guard + normalize (Int32) ===")
# Simulate the hot path of a constructor with guard

@inline function full_orig32(num::Int32, den::Int32)
    den == 0 && throw(ArgumentError("zero"))
    if den < 0; num = -num; den = -den; end
    num == 0 && return (Int32(0), Int32(1))
    g = gcd(num, den)
    return div(num, g), div(den, g)
end

@inline function full_guarded_a32(num::Int32, den::Int32)
    num == TMIN32 && throw(OverflowError("typemin"))
    den == TMIN32 && throw(OverflowError("typemin"))
    den == 0 && throw(ArgumentError("zero"))
    if den < 0; num = -num; den = -den; end
    num == 0 && return (Int32(0), Int32(1))
    g = gcd(num, den)
    return div(num, g), div(den, g)
end

@inline function full_guarded_b32(num::Int32, den::Int32)
    (num == TMIN32 || den == TMIN32) && throw(OverflowError("typemin"))
    den == 0 && throw(ArgumentError("zero"))
    if den < 0; num = -num; den = -den; end
    num == 0 && return (Int32(0), Int32(1))
    g = gcd(num, den)
    return div(num, g), div(den, g)
end

print("\n  no guard (baseline): "); display(@be (for (n,d) in $pairs32; full_orig32(n,d); end))
print("  A (two ==):          "); display(@be (for (n,d) in $pairs32; full_guarded_a32(n,d); end))
print("  B (combined OR):     "); display(@be (for (n,d) in $pairs32; full_guarded_b32(n,d); end))

println("\n=== Full constructor simulation: guard + normalize (Int64) ===")

@inline function full_orig64(num::Int64, den::Int64)
    den == 0 && throw(ArgumentError("zero"))
    if den < 0; num = -num; den = -den; end
    num == 0 && return (Int64(0), Int64(1))
    g = gcd(num, den)
    return div(num, g), div(den, g)
end

@inline function full_guarded_a64(num::Int64, den::Int64)
    num == TMIN64 && throw(OverflowError("typemin"))
    den == TMIN64 && throw(OverflowError("typemin"))
    den == 0 && throw(ArgumentError("zero"))
    if den < 0; num = -num; den = -den; end
    num == 0 && return (Int64(0), Int64(1))
    g = gcd(num, den)
    return div(num, g), div(den, g)
end

@inline function full_guarded_b64(num::Int64, den::Int64)
    (num == TMIN64 || den == TMIN64) && throw(OverflowError("typemin"))
    den == 0 && throw(ArgumentError("zero"))
    if den < 0; num = -num; den = -den; end
    num == 0 && return (Int64(0), Int64(1))
    g = gcd(num, den)
    return div(num, g), div(den, g)
end

print("  no guard (baseline): "); display(@be (for (n,d) in $pairs64; full_orig64(n,d); end))
print("  A (two ==):          "); display(@be (for (n,d) in $pairs64; full_guarded_a64(n,d); end))
print("  B (combined OR):     "); display(@be (for (n,d) in $pairs64; full_guarded_b64(n,d); end))
