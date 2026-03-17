# XRationals.jl

Exact rational arithmetic with IEEE-like special values (NaN, Inf, -Inf), overflow-safe saturation, lazy normalization, and zero heap allocation.

## Overview

XRationals.jl provides four rational number types in two families:

| Type | Alias | Backing | Overflow | Normalization |
| :---- | :----- | :------- | :-------- | :------------- |
| `Rational32` | `Q32` | `Int32` | Throws `OverflowError` | Eager (always canonical) |
| `Rational64` | `Q64` | `Int64` | Throws `OverflowError` | Eager (always canonical) |
| `XRational32` | `Qx32` | `Int32` | Saturates to Inf/NaN | Lazy (Int64 intermediate) |
| `XRational64` | `Qx64` | `Int64` | Saturates to Inf/NaN | Lazy (Int128 intermediate) |

## Choosing a type

- **Need strict error detection?** Use `Q32` / `Q64`. Overflow throws immediately.
- **Need IEEE-like robustness and speed?** Use `Qx32` / `Qx64`. Overflow saturates to Inf/NaN, and lazy normalization gives 3-13x speedups over `Rational{Int}` for chained arithmetic.

## Quick start

```julia
using XRationals

# Basic exact arithmetic
a = Qx32(2, 3)
b = Qx32(5, 7)
a + b   # 29//21
a * b   # 10//21
a ^ 3   # 8//27

# IEEE-like special values
Qx32(1, 0)   # Inf
Qx32(-1, 0)  # -Inf
Qx32(0, 0)   # NaN

# Overflow saturates instead of crashing
Qx32(typemax(Int32), 1) + 1   # Inf

# Lazy normalization: GCD deferred until display
Qx64(6, 8) == Qx64(3, 4)   # true (cross-multiply comparison)
```

## Key features

- **Zero heap allocation**: all arithmetic uses fixed-width integers (Int32/Int64/Int128/Int256)
- **Lazy normalization**: GCD is deferred until display, hashing, or conversion
- **`typemin` rejection**: constructors reject `typemin(Int32)` and `typemin(Int64)` to prevent silent negation overflow
- **Fused multiply-add**: `fma(x, y, z)` computes `x*y + z` with exact intermediate precision
- **Cross-width conversion**: `Qx32(x::Qx64)` finds the best Int32 approximation via Stern-Brocot mediants
- **IEEE ordering**: NaN sorts last, Inf/-Inf compare correctly

## Pages

- [Strict Rationals (Q32/Q64)](strict.md)
- [Extended Rationals (Qx32/Qx64)](extended.md)
- [Usage Guide](guide.md)
- [API Reference](api.md)
