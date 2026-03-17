# Extended Rationals — Qx32 / Qx64

`ExtendedRational32` (`Qx32`) and `ExtendedRational64` (`Qx64`) add IEEE-like special values to exact rational arithmetic. Overflow saturates to Inf or NaN instead of throwing, making these types suitable for numerical pipelines where graceful degradation is preferred over exceptions.

## When to use

- You need **IEEE-like robustness**: Inf, -Inf, NaN propagation, and overflow saturation.
- You are writing numerical algorithms that must not crash on edge cases (division by zero, overflow).
- You want canonical (always-normalized) storage with special-value support.

## Advantages

- **Never throws on arithmetic**: overflow saturates to Inf/NaN, division by zero returns Inf.
- **IEEE semantics**: NaN propagates, Inf arithmetic follows expected rules, NaN sorts last.
- **Always canonical**: every finite value is GCD-normalized, so equality is a simple field comparison.
- **Zero allocation**: all intermediates use fixed-width integers (Int64 for Qx32, Int128/Int256 for Qx64).

## Limitations

- Eager normalization (GCD on every operation) adds overhead compared to the Fast variants.
- Saturation to Inf means you lose the exact result — use Q32/Q64 if you need overflow detection.

## Special-value encoding

Special values are encoded in the same two-field struct:

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
Qx32(1, 0)              # Inf32
Qx32(-1, 0)             # -Inf32
Qx32(0, 0)              # NaN32

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
Qx32(typemax(Int32), 1) + 1          # Inf32
Qx64(typemin(Int64) + 1, 1) - 1      # -Inf64

# Division by zero
Qx32(1, 2) / Qx32(0, 1)             # Inf32
Qx32(0, 1) / Qx32(0, 1)             # NaN32
```

## Inf and NaN propagation

```julia
inf  = Qx32(1, 0)
ninf = Qx32(-1, 0)
nan  = Qx32(0, 0)

inf + Qx32(5, 1)    # Inf32
inf + ninf           # NaN32 (indeterminate)
inf * Qx32(0, 1)    # NaN32 (indeterminate)
nan + Qx32(1, 1)    # NaN32 (propagates)
```

## Ordering

Ordering follows IEEE conventions: NaN is unordered and sorts last.

```julia
vals = [Qx32(3, 2), Qx32(-1, 2), Qx32(1, 0), Qx32(-1, 0), Qx32(0, 1)]
sort(vals)   # [-Inf32, -1//2, 0//1, 3//2, Inf32]

sort([Qx32(0, 0), Qx32(1, 1), Qx32(-1, 1)])   # [-1//1, 1//1, NaN32]
```

## Fused multiply-add

`fma(x, y, z)` uses exact intermediate precision:

- Qx32: intermediate in Int128
- Qx64: intermediate in Int256 (via BitIntegers.jl)

The result is the nearest representable value found by Stern-Brocot mediants.

```julia
# Exact result fits
fma(Qx32(2, 3), Qx32(3, 4), Qx32(1, 2))   # 1//1

# Large arguments: exact intermediate, nearest approximation
M = Qx64(typemax(Int64), 2)
N = Qx64(typemax(Int64), 3)
Z = Qx64(typemax(Int64), 5)
fma(M, N, Z)   # nearest Qx64 to the exact result
```

## Cross-width conversion

Convert Qx64 to Qx32 with best rational approximation:

```julia
wide = Qx64(355, 113)
narrow = Qx32(wide)      # 355//113 (fits exactly)

# When the value is too large, saturates
huge = Qx64(typemax(Int64), 1)
Qx32(huge)                # Inf32
```

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
