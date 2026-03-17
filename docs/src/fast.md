# Fast Extended Rationals — Qxf32 / Qxf64

`ExtendedRationalFast32` (`Qxf32`) and `ExtendedRationalFast64` (`Qxf64`) are the highest-throughput types in the package. They have the same IEEE-like semantics as Qx32/Qx64 but **delay GCD normalization** until it is actually needed.

## When to use

- You need **maximum arithmetic throughput** and are performing chains of operations.
- You want IEEE-like Inf/NaN semantics without the per-operation GCD cost.
- You are building inner loops, DSP pipelines, or iterative algorithms where intermediate normalization is wasted work.

## Advantages

- **3-13x faster than `Rational{Int}`** for chained arithmetic (add, subtract, multiply, divide).
- **Zero allocation**: Qxf32 uses native Int64 intermediates, Qxf64 uses Int128.
- **IEEE semantics**: same Inf/NaN saturation and propagation as Qx32/Qx64.
- **Correct equality**: cross-multiplication comparison works without normalization.
- **Correct hashing**: normalization is performed lazily when `hash` is called.

## How lazy normalization works

Standard rational types compute `gcd(|num|, den)` after every operation to keep the fraction reduced. The Fast types skip this step — they store the result with `den > 0` and correct sign, but may leave a common factor. Normalization happens only when needed:

- **Display** (`show`, `print`): normalizes before printing.
- **Hashing** (`hash`): normalizes so equal values hash identically.
- **Accessors** (`numerator`, `denominator`): return the canonical form.
- **Conversion** to other types: normalizes first.

Arithmetic and comparisons **never normalize**:

- `==` uses cross-multiplication: `a.num * b.den == b.num * a.den`
- `<` uses cross-multiplication: `a.num * b.den < b.num * a.den`
- `+`, `-`, `*`, `/` compute in wider integers and store the raw result.

## Performance

Typical speedups over `Rational{Int}` (minimum nanoseconds, zero allocations):

### Qxf32 vs Rational{Int32}

| Operation | `Rational{Int32}` | `Qxf32` | Speedup |
| --------- | ----------------- | ------- | ------- |
| a + b     | 13 ns             | 2 ns    | 6.5x    |
| a * b     | 8 ns              | 2 ns    | 4x      |
| a+b+c+d   | 66 ns             | 5 ns    | 13x     |
| a*b-c*d   | 37 ns             | 4 ns    | 9x      |

### Qxf64 vs Rational{Int64}

| Operation | `Rational{Int64}` | `Qxf64` | Speedup |
| --------- | ----------------- | ------- | ------- |
| a + b     | 14 ns             | 3 ns    | 5x      |
| a * b     | 8 ns              | 2 ns    | 4x      |
| a+b+c+d   | 72 ns             | 8 ns    | 9x      |
| a*b-c*d   | 41 ns             | 5 ns    | 8x      |

The speedup grows with chain length because each skipped GCD saves ~10 ns.

## Construction

```julia
using ExtendedRationals

a = Qxf32(2, 3)        # 2//3
b = Qxf64(355, 113)    # 355//113

# Special values (same encoding as Qx32/Qx64)
Qxf32(1, 0)             # Inf32f
Qxf32(-1, 0)            # -Inf32f
Qxf32(0, 0)             # NaN32f

# typemin is rejected
Qxf64(typemin(Int64), 1)  # throws OverflowError
```

## Arithmetic

```julia
a = Qxf32(2, 3)
b = Qxf32(5, 7)

a + b    # 29//21
a - b    # -1//21
a * b    # 10//21
a / b    # 14//15
a ^ 3    # 8//27

# Overflow saturates
Qxf32(typemax(Int32), 1) + 1   # Inf32f
Qxf64(typemax(Int64), 1) + 1   # Inf64f
```

## Lazy storage, correct equality

```julia
# Stored unnormalized internally
x = Qxf32(6, 8)    # stores num=6, den=8 (not reduced)

# Display normalizes
sprint(show, x)      # "3//4"

# Equality uses cross-multiply — no GCD needed
x == Qxf32(3, 4)    # true
x == Qxf32(9, 12)   # true

# numerator/denominator return canonical form
numerator(x)         # 3
denominator(x)       # 4
```

## Chained operations

This is where lazy normalization shines — each intermediate result skips GCD:

```julia
a = Qxf64(2, 3)
b = Qxf64(5, 7)
c = Qxf64(3, 13)
d = Qxf64(11, 7)

# Four additions, zero GCDs computed
a + b + c + d    # 869//273

# Mixed multiply and subtract
a * b - c * d    # 31//273
```

## Inf, NaN, and predicates

Same IEEE semantics as Qx32/Qx64:

```julia
inf = Qxf64(1, 0)
nan = Qxf64(0, 0)

isinf(inf)           # true
isnan(nan)            # true
isfinite(Qxf64(3,4)) # true

inf + Qxf64(5, 1)    # Inf64f
inf + Qxf64(-1, 0)   # NaN64f (Inf + -Inf)
nan + Qxf64(1, 1)    # NaN64f (propagates)

# Sorting: NaN sorts last
sort([nan, Qxf64(1,1), Qxf64(-1,1)])  # [-1//1, 1//1, NaN64f]
```

## Fused multiply-add

`fma` normalizes its operands before computing (to ensure exact intermediate precision), so it is slower than regular arithmetic. Use `muladd` (which is just `x*y + z`) for the fast path when you don't need the exact intermediate guarantee.

```julia
fma(Qxf64(2, 3), Qxf64(3, 4), Qxf64(1, 2))   # 1//1 (exact)

# muladd is faster (lazy, no intermediate normalization)
muladd(Qxf64(2, 3), Qxf64(3, 4), Qxf64(1, 2)) # 1//1
```

## When not to use

- If you need every intermediate result in canonical form (e.g., for serialization after each step), use Qx32/Qx64 instead.
- If you need strict overflow detection (throw, not saturate), use Q32/Q64.
- If numerator/denominator values are accessed frequently, the lazy normalization cost is paid repeatedly — consider Qx32/Qx64.
