# XRationals.jl

Exact rational arithmetic with IEEE-like special values (NaN, Inf, -Inf), overflow-safe saturation, lazy normalization, and zero heap allocation.

## Overview

XRationals.jl is built for exact rational arithmetic when you want fixed-width performance characteristics instead of arbitrary-precision growth. The package keeps numerators and denominators in compact integer fields, avoids heap allocation in normal arithmetic, and offers a predictable overflow story for each family of types.

The exported `Qx` types are the practical front door for most users: they preserve exact rational semantics while adding IEEE-like `Inf`, `-Inf`, and `NaN` values plus lazy normalization for faster chained operations. Alongside them, the internal strict `Rational32`, `Rational64`, and `Rational128` types provide the same width-specific API shape but throw immediately on overflow and always stay in canonical form.

XRationals.jl provides six rational number types in two families:

| Type | Int | Overflow | Normalization |
| :--- | :-- | :------- | :------------- |
| `XRational32` (`Qx32`) | `Int32` | Saturates | Lazy via `Int64` |
| `XRational64` (`Qx64`) | `Int64` | Saturates | Lazy via `Int128` |
| `XRational128` (`Qx128`) | `Int128` | Saturates | Lazy via `Int256` |
| `Rational32` | `Int32` | Throws | Eager |
| `Rational64` | `Int64` | Throws | Eager |
| `Rational128` | `Int128` | Throws | Eager |

## Choosing a type

- **Need IEEE-like robustness and speed?** Use `Qx32`, `Qx64`, or `Qx128`. Overflow saturates to Inf/NaN, and lazy normalization gives strong speedups over `Rational{Int}` for chained arithmetic.
- **Need strict error detection?** `Rational32`, `Rational64`, and `Rational128` are available internally. Overflow throws immediately.

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

- **Zero heap allocation**: all arithmetic uses fixed-width integers (Int32/Int64/Int128/Int256/Int512/Int1024)
- **Broader width coverage**: choose 32-, 64-, or 128-bit strict and extended rationals from the same API shape
- **Lazy normalization**: GCD is deferred until display, hashing, or conversion
- **`typemin` rejection**: constructors reject `typemin(Int32)`, `typemin(Int64)`, and `typemin(Int128)` to prevent silent negation overflow
- **Fused multiply-add**: `fma(x, y, z)` computes `x*y + z` with exact intermediate precision
- **Cross-width conversion**: exact widening constructors (`Qx64(x::Qx32)`, `Qx128(x::Qx32)`, `Qx128(x::Qx64)`) are the canonical widening APIs and preserve value, `widen(Qx32) == Qx64` and `widen(Qx64) == Qx128` expose the same widening ladder, and `Qx64(x::Qx128)`, `Qx32(x::Qx128)`, and `Qx32(x::Qx64)` compute the nearest representable narrower value
- **IEEE ordering**: NaN sorts last, Inf/-Inf compare correctly

## Pages

- [Extended Rationals (Qx32/Qx64/Qx128)](extended.md)
- [Strict Rationals (Rational32/Rational64/Rational128)](strict.md)
- [Usage Guide](guide.md)
- [API Reference](api.md)
