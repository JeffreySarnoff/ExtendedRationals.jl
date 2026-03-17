# ExtendedRationals.jl

Exact rational arithmetic with IEEE-like special values (NaN, Inf, -Inf), overflow-safe saturation, and zero heap allocation.

## Overview

ExtendedRationals.jl provides six rational number types organized in three families:

| Type | Alias | Backing | Overflow | Normalization |
| :---- | :----- | :------- | :-------- | :------------- |
| `Rational32` | `Q32` | `Int32` | Throws `OverflowError` | Eager (always canonical) |
| `Rational64` | `Q64` | `Int64` | Throws `OverflowError` | Eager (always canonical) |
| `ExtendedRational32` | `Qx32` | `Int32` | Saturates to Inf/NaN | Eager (always canonical) |
| `ExtendedRational64` | `Qx64` | `Int64` | Saturates to Inf/NaN | Eager (always canonical) |
| `ExtendedRationalFast32` | `Qxf32` | `Int32` | Saturates to Inf/NaN | Lazy (deferred GCD) |
| `ExtendedRationalFast64` | `Qxf64` | `Int64` | Saturates to Inf/NaN | Lazy (deferred GCD) |

## Choosing a type

- **Need strict error detection?** Use `Q32` / `Q64`. Overflow throws immediately.
- **Need IEEE-like robustness?** Use `Qx32` / `Qx64`. Overflow saturates to Inf/NaN.
- **Need maximum throughput?** Use `Qxf32` / `Qxf64`. Lazy normalization skips GCD on every operation, giving 3-13x speedups over `Rational{Int}` for chained arithmetic.

## Quick start

```julia
using ExtendedRationals

# Basic exact arithmetic
a = Qx32(2, 3)
b = Qx32(5, 7)
a + b   # 29//21
a * b   # 10//21
a ^ 3   # 8//27

# IEEE-like special values
Qx32(1, 0)   # Inf32
Qx32(-1, 0)  # -Inf32
Qx32(0, 0)   # NaN32

# Overflow saturates instead of crashing
Qx32(typemax(Int32), 1) + 1   # Inf32

# Fast lazy type for throughput-critical code
x = Qxf64(2, 3)
y = Qxf64(5, 7)
x + y   # 29//21 (GCD deferred until display)
```

## Key features

- **Zero heap allocation**: all arithmetic uses fixed-width integers (Int32/Int64/Int128/Int256)
- **`typemin` rejection**: constructors reject `typemin(Int32)` and `typemin(Int64)` to prevent silent negation overflow
- **Fused multiply-add**: `fma(x, y, z)` computes `x*y + z` with exact intermediate precision
- **Cross-width conversion**: `Qx32(x::Qx64)` finds the best Int32 approximation via Stern-Brocot mediants
- **IEEE ordering**: NaN sorts last, Inf/−Inf compare correctly

## Pages

- [Strict Rationals (Q32/Q64)](strict.md)
- [Extended Rationals (Qx32/Qx64)](extended.md)
- [Fast Extended (Qxf32/Qxf64)](fast.md)
- [Usage Guide](guide.md)
- [API Reference](api.md)
