# Extended Rationals — Qx32 / Qx64

`XRational32` (`Qx32`) and `XRational64` (`Qx64`) combine IEEE-like special values with lazy GCD normalization for maximum throughput. Overflow saturates to Inf or NaN instead of throwing.

## When to use

- You need **IEEE-like robustness**: Inf, -Inf, NaN propagation, and overflow saturation.
- You need **maximum arithmetic throughput** for chains of operations.
- You want zero-allocation arithmetic with special-value support.

## Advantages

- **3-13x faster than `Rational{Int}`** for chained arithmetic.
- **Never throws on arithmetic**: overflow saturates to Inf/NaN, division by zero returns Inf.
- **IEEE semantics**: NaN propagates, Inf arithmetic follows expected rules, NaN sorts last.
- **Zero allocation**: Qx32 uses native Int64 intermediates, Qx64 uses Int128.
- **Correct equality**: cross-multiplication comparison works without normalization.

## How lazy normalization works

Standard rational types compute `gcd(|num|, den)` after every operation. Qx32/Qx64 skip this step — they store the result with `den > 0` and correct sign, but may leave a common factor. Normalization happens only when needed:

- **Display** (`show`, `print`): normalizes before printing.
- **Hashing** (`hash`): normalizes so equal values hash identically.
- **Accessors** (`numerator`, `denominator`): return the canonical form.
- **Conversion** to other types: normalizes first.

Arithmetic and comparisons **never normalize**:

- `==` uses cross-multiplication: `a.num * b.den == b.num * a.den`
- `<` uses cross-multiplication: `a.num * b.den < b.num * a.den`
- `+`, `-`, `*`, `/` compute in wider integers and store the raw result.

## Special-value encoding

| Value | `num` | `den` |
| ----- | ----- | ----- |
| NaN   | 0     | 0     |
| +Inf  | 1     | 0     |
| -Inf  | -1    | 0     |

## Construction

```julia
using ExtendedRationals

a = Qx32(2, 3)         # 2//3
b = Qx64(355, 113)     # 355//113

# Special values
Qx32(1, 0)              # Inf
Qx32(-1, 0)             # -Inf
Qx32(0, 0)              # NaN

# From floats
Qx64(3.14)              # best Int64 rational approximation

# typemin is rejected
Qx32(typemin(Int32), 1) # throws OverflowError
```

## Arithmetic with saturation

```julia
a = Qx32(2, 3)
b = Qx32(5, 7)

a + b    # 29//21
a * b    # 10//21
a ^ 3    # 8//27

# Overflow saturates
Qx32(typemax(Int32), 1) + 1          # Inf
Qx64(typemin(Int64) + 1, 1) - 1      # -Inf

# Division by zero
Qx32(1, 2) / Qx32(0, 1)             # Inf
Qx32(0, 1) / Qx32(0, 1)             # NaN
```

## Lazy storage, correct equality

```julia
# Stored unnormalized internally
x = Qx32(6, 8)    # stores num=6, den=8 (not reduced)

# Display normalizes
sprint(show, x)    # "3//4"

# Equality uses cross-multiply — no GCD needed
x == Qx32(3, 4)   # true
x == Qx32(9, 12)  # true

# numerator/denominator return canonical form
numerator(x)       # 3
denominator(x)     # 4
```

## Chained operations

Each intermediate result skips GCD — this is where the speedup compounds:

```julia
a = Qx64(2, 3)
b = Qx64(5, 7)
c = Qx64(3, 13)
d = Qx64(11, 7)

a + b + c + d    # 869//273 (zero GCDs computed)
a * b - c * d    # 31//273
```

## Inf and NaN propagation

```julia
inf  = Qx32(1, 0)
ninf = Qx32(-1, 0)
nan  = Qx32(0, 0)

inf + Qx32(5, 1)    # Inf
inf + ninf           # NaN (indeterminate)
inf * Qx32(0, 1)    # NaN (indeterminate)
nan + Qx32(1, 1)    # NaN (propagates)
```

## Ordering

Ordering follows IEEE conventions: NaN is unordered and sorts last.

```julia
vals = [Qx32(3, 2), Qx32(-1, 2), Qx32(1, 0), Qx32(-1, 0), Qx32(0, 1)]
sort(vals)   # [-Inf, -1//2, 0//1, 3//2, Inf]

sort([Qx32(0, 0), Qx32(1, 1), Qx32(-1, 1)])   # [-1//1, 1//1, NaN]
```

## Fused multiply-add

`fma(x, y, z)` normalizes operands first, then uses exact intermediate precision:

- Qx32: intermediate in Int64, result via Stern-Brocot in Int128
- Qx64: intermediate in Int128, result via Stern-Brocot in Int256

Use `muladd(x, y, z)` (which is just `x*y + z`) for the fast path when you don't need the exact intermediate guarantee.

```julia
fma(Qx32(2, 3), Qx32(3, 4), Qx32(1, 2))   # 1//1

# muladd is faster (lazy, no intermediate normalization)
muladd(Qx32(2, 3), Qx32(3, 4), Qx32(1, 2)) # 1//1
```

## Cross-width conversion

Convert Qx64 to Qx32 with best rational approximation:

```julia
wide = Qx64(355, 113)
narrow = Qx32(wide)      # 355//113 (fits exactly)

huge = Qx64(typemax(Int64), 1)
Qx32(huge)                # Inf (saturates)
```

## Performance

Typical speedups over `Rational{Int}` (minimum nanoseconds, zero allocations):

### Qx32 vs Rational{Int32}

| Operation | `Rational{Int32}` | `Qx32` | Speedup |
| --------- | ----------------- | ------- | ------- |
| a + b     | 13 ns             | 2 ns    | 6.5x    |
| a * b     | 8 ns              | 2 ns    | 4x      |
| a+b+c+d   | 66 ns             | 5 ns    | 13x     |
| a*b-c*d   | 37 ns             | 4 ns    | 9x      |

### Qx64 vs Rational{Int64}

| Operation | `Rational{Int64}` | `Qx64` | Speedup |
| --------- | ----------------- | ------- | ------- |
| a + b     | 14 ns             | 3 ns    | 5x      |
| a * b     | 8 ns              | 2 ns    | 4x      |
| a+b+c+d   | 72 ns             | 8 ns    | 9x      |
| a*b-c*d   | 41 ns             | 5 ns    | 8x      |

## Predicates

```julia
x = Qx32(3, 4)

isfinite(x)       # true
isinf(Qx32(1,0))  # true
isnan(Qx32(0,0))  # true
iszero(Qx32(0,1)) # true
isone(Qx32(1,1))  # true
isinteger(Qx32(4,1))  # true
signbit(Qx32(-3,4))   # true
```
