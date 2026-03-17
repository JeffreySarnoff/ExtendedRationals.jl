using Chairmarks

println("=== Multiply two Int64 values (simulating num*den) ===")
a64, b64 = Int64(2147483647), Int64(1999999999)
print("  BigInt:  "); display(@be BigInt($a64) * BigInt($b64))
print("  Int128:  "); display(@be Int128($a64) * Int128($b64))

println("\n=== Sum of two products (simulating add numerator) ===")
c64, d64 = Int64(1999999937), Int64(1999999943)
print("  BigInt:  "); display(@be BigInt($a64) * BigInt($b64) + BigInt($c64) * BigInt($d64))
print("  Int128:  "); display(@be Int128($a64) * Int128($b64) + Int128($c64) * Int128($d64))

println("\n=== gcd on products (simulating normalize) ===")
ab = Int128(a64) * Int128(b64)
cd = Int128(c64) * Int128(d64)
s = ab + cd
print("  BigInt:  "); display(@be gcd(BigInt($s), BigInt($cd)))
print("  Int128:  "); display(@be gcd($s, $cd))

println("\n=== div + rem (simulating quotient/remainder) ===")
print("  BigInt div: "); display(@be div(BigInt($ab), BigInt($cd)))
print("  Int128 div: "); display(@be div($ab, $cd))
print("  BigInt rem: "); display(@be rem(BigInt($ab), BigInt($cd)))
print("  Int128 rem: "); display(@be rem($ab, $cd))

println("\n=== Rational muladd: BigInt vs Int128 (Int32 fma path) ===")
n1, d1, n2, d2, n3, d3 = Int32(46340), Int32(7), Int32(46339), Int32(11), Int32(12345), Int32(13)
print("  BigInt:  "); display(@be begin
    bx = BigInt($n1) // BigInt($d1)
    by = BigInt($n2) // BigInt($d2)
    bz = BigInt($n3) // BigInt($d3)
    muladd(bx, by, bz)
end)
print("  Int128:  "); display(@be begin
    num = Int128($n1)*Int128($n2)*Int128($d3) + Int128($n3)*Int128($d1)*Int128($d2)
    den = Int128($d1)*Int128($d2)*Int128($d3)
    g = gcd(num, den); div(num, g), div(den, g)
end)

println("\n=== _compare_distance pattern (Int32 path) ===")
tn, td = Int64(987654321), Int64(123456789)
an, ad = Int32(8), Int32(1)
bn, bd = Int32(7), Int32(1)
print("  BigInt:  "); display(@be begin
    t_n = BigInt($tn); t_d = BigInt($td)
    da = abs(t_n * BigInt($ad) - BigInt($an) * t_d)
    db = abs(t_n * BigInt($bd) - BigInt($bn) * t_d)
    da * BigInt($bd) < db * BigInt($ad)
end)
print("  Int128:  "); display(@be begin
    t_n = Int128($tn); t_d = Int128($td)
    da = abs(t_n * Int128($ad) - Int128($an) * t_d)
    db = abs(t_n * Int128($bd) - Int128($bn) * t_d)
    da * Int128($bd) < db * Int128($ad)
end)

println("\n=== Rational64 add: full normalize path ===")
x_num, x_den = Int64(2147483629), Int64(2147483587)
y_num, y_den = Int64(1999999973), Int64(1999999943)
print("  BigInt:  "); display(@be begin
    n = BigInt($x_num)*BigInt($y_den) + BigInt($y_num)*BigInt($x_den)
    d = BigInt($x_den)*BigInt($y_den)
    g = gcd(n, d); div(n, g), div(d, g)
end)
print("  Int128:  "); display(@be begin
    n = Int128($x_num)*Int128($y_den) + Int128($y_num)*Int128($x_den)
    d = Int128($x_den)*Int128($y_den)
    g = gcd(n, d); div(n, g), div(d, g)
end)

println("\n=== Negation ===")
v = Int64(-2147483647)
print("  BigInt:  "); display(@be -BigInt($v))
print("  Int128:  "); display(@be -Int128($v))
