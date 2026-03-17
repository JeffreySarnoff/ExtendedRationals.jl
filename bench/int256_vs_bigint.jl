using Chairmarks, BitIntegers

println("=== Max bit-width analysis for each BigInt site ===\n")

M64 = typemax(Int64)  # 2^63-1
M32 = typemax(Int32)  # 2^31-1

# RationalInt32s _compare_distance: target is Rational{Int128} from fma
# target num/den up to ~2^93 (Int32^3 products after gcd)
# an = |tn * a.den - a.num * td| ≈ 2^93 * 2^31 = 2^124
# lhs = an * b.den ≈ 2^124 * 2^31 = 2^155
println("RationalInt32s _compare_distance:")
println("  max product: 2^155 → fits Int256 (255 bits)? true")

# RationalInt32s _nearest_rational32 clamp: limit * den(work)
# limit = 2^31, den up to 2^93
println("RationalInt32s clamp: 2^124 → fits Int128? true")

# RationalInt64s fma muladd: num = x.num*y.num*z.den + z.num*x.den*y.den
# each triple product ≈ (2^63)^3 = 2^189, sum ≈ 2^190
println("\nRationalInt64s fma muladd:")
println("  max intermediate: 2^190 → fits Int256? true")

# RationalInt64s _nearest_rational64 Stern-Brocot:
# a = div(n, d) where n ≈ 2^190; p1 ≈ 2^63
# a * p1 ≈ 2^253
println("\nRationalInt64s Stern-Brocot convergents:")
println("  max a*p1: 2^253 → fits Int256? true")

# RationalInt64s _compare_distance: target from fma
# tn ≈ 2^190, a.den ≈ 2^63, product ≈ 2^253
# cross-multiply: 2^253 * 2^63 = 2^316
println("\nRationalInt64s _compare_distance:")
println("  |diff| * den: 2^253 * 2^63 = 2^316")
println("  fits Int256? false (need Int512)")

println("\n=== Benchmarks ===\n")

# --- Stern-Brocot style: large multiply + compare ---
n256 = Int256(M64)^2 * Int256(3)     # ~2^127
d256 = Int256(M64) * Int256(12345)    # ~2^77
p1_256 = Int256(M64)

println("Stern-Brocot: div + multiply (2^190 scale)")
n_big = BigInt(M64)^3; d_big = BigInt(M64)^2
n_256 = Int256(M64)^3; d_256 = Int256(M64)^2
print("  BigInt: "); display(@be begin a = div($n_big, $d_big); $p1_256 + a * $p1_256; end)
n_i = Int256(n_256); d_i = Int256(d_256); p1_i = Int256(M64)
print("  Int256: "); display(@be begin a = div($n_i, $d_i); $p1_i + a * $p1_i; end)

println("\nfma muladd (3 × Int64 products + sum)")
xn, xd, yn, yd, zn, zd = Int64(M64), Int64(2), Int64(M64-1), Int64(3), Int64(M64-2), Int64(5)
print("  BigInt: "); display(@be begin
    num = BigInt($xn)*BigInt($yn)*BigInt($zd) + BigInt($zn)*BigInt($xd)*BigInt($yd)
    den = BigInt($xd)*BigInt($yd)*BigInt($zd)
    g = gcd(num, den); div(num, g), div(den, g)
end)
print("  Int256: "); display(@be begin
    num = Int256($xn)*Int256($yn)*Int256($zd) + Int256($zn)*Int256($xd)*Int256($yd)
    den = Int256($xd)*Int256($yd)*Int256($zd)
    g = gcd(num, den); div(num, g), div(den, g)
end)

println("\n_compare_distance (Int32 path, products ≤ 2^155)")
tn128 = Int128(M32)^2 * Int128(3)  # ~2^93 simulating fma target
td128 = Int128(M32)^2              # ~2^62
an32, ad32, bn32, bd32 = Int32(M32-1), Int32(M32-2), Int32(M32-3), Int32(M32-4)
print("  BigInt: "); display(@be begin
    tn = BigInt($tn128); td = BigInt($td128)
    da = abs(tn * BigInt($ad32) - BigInt($an32) * td)
    db = abs(tn * BigInt($bd32) - BigInt($bn32) * td)
    da * BigInt($bd32) < db * BigInt($ad32)
end)
print("  Int256: "); display(@be begin
    tn = Int256($tn128); td = Int256($td128)
    da = abs(tn * Int256($ad32) - Int256($an32) * td)
    db = abs(tn * Int256($bd32) - Int256($bn32) * td)
    da * Int256($bd32) < db * Int256($ad32)
end)

println("\n_compare_distance (Int64 path, products ≤ 2^316, needs Int512)")
tn_big = BigInt(M64)^3    # ~2^189 simulating fma target
td_big = BigInt(M64)^2    # ~2^126
an64, ad64, bn64, bd64 = Int64(M64-1), Int64(M64-2), Int64(M64-3), Int64(M64-4)
print("  BigInt: "); display(@be begin
    tn = BigInt($tn_big); td = BigInt($td_big)
    da = abs(tn * BigInt($ad64) - BigInt($an64) * td)
    db = abs(tn * BigInt($bd64) - BigInt($bn64) * td)
    da * BigInt($bd64) < db * BigInt($ad64)
end)
tn_512 = Int512(tn_big); td_512 = Int512(td_big)
print("  Int512: "); display(@be begin
    tn = Int512($tn_512); td = Int512($td_512)
    da = abs(tn * Int512($ad64) - Int512($an64) * td)
    db = abs(tn * Int512($bd64) - Int512($bn64) * td)
    da * Int512($bd64) < db * Int512($ad64)
end)

println("\nRational{Int256} creation (fma result) vs Rational{BigInt}")
num_val = Int256(M64)^2 * Int256(5) + Int256(M64) * Int256(6)
den_val = Int256(30)
print("  BigInt //: "); display(@be BigInt($num_val) // BigInt($den_val))
print("  Int256 //: "); display(@be $num_val // $den_val)
