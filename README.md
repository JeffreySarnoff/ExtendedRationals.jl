# ExtendedRationals.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JeffreySarnoff.github.io/ExtendedRationals.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JeffreySarnoff.github.io/ExtendedRationals.jl/dev/)
[![Build Status](https://github.com/JeffreySarnoff/ExtendedRationals.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JeffreySarnoff/ExtendedRationals.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JeffreySarnoff/ExtendedRationals.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JeffreySarnoff/ExtendedRationals.jl)

Exact rational arithmetic with IEEE-like special values (NaN, Inf, -Inf) and overflow-safe saturation policy.

## Types

| Type | Alias | Backing | Overflow behavior |
| ------ | ------- | --------- | ------------------- |
| `Rational32` | `Q32` | `Int32` | Throws `OverflowError` |
| `Rational64` | `Q64` | `Int64` | Throws `OverflowError` |
| `ExtendedRational32` | `Qx32` | `Int32` | Saturates to Inf/NaN |
| `ExtendedRational64` | `Qx64` | `Int64` | Saturates to Inf/NaN |
| `ExtendedRationalFast64` | `Qxf64` | `Int64` | Saturates to Inf/NaN, lazy normalization |

## Features

- Exact rational arithmetic with no floating-point rounding
- IEEE-like NaN, Inf, -Inf encoded in the same struct (`0//0`, `1//0`, `-1//0`)
- Overflow saturates to Inf/NaN instead of crashing (extended types)
- Fused multiply-add (`fma`) with exact intermediate computation
- Cross-width conversion (Qx64 to Qx32) via best rational approximation
- Zero heap allocation: all arithmetic uses fixed-width integers (Int32/Int64/Int128/Int256/Int512)
- `typemin` rejection prevents silent negation overflow

## Benchmarks

All operations are zero-allocation unless noted. Times are minimum nanoseconds.

### 32-bit

| Operation | `Rational{Int32}` | `Q32` | `Qx32` |
| --- | --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns | 1 ns |
| a + b | 13 ns | 7 ns | 8 ns |
| a - b | 13 ns | 7 ns | 8 ns |
| a * b | 8 ns | 8 ns | 8 ns |
| a / b | 7 ns | 8 ns | 8 ns |
| -a | 1 ns | 5 ns | 5 ns |
| a < b | 1 ns | 1 ns | 2 ns |
| a == b | 1 ns | 1 ns | 1 ns |
| abs(-a) | 1 ns | 11 ns | 12 ns |
| inv(a) | 1 ns | 4 ns | 5 ns |
| a ^ 3 | 18 ns | 27 ns | 31 ns |
| a+b+c+d | 66 ns | 40 ns | 46 ns |
| a*b-c*d | 37 ns | 27 ns | 27 ns |
| muladd(a,b,a) | 24 ns | 17 ns | 20 ns |
| fma(a,b,a) | 23 ns | 168 ns | 194 ns |
| big + big | --- | --- | 19 ns |
| Inf + a | --- | --- | 3 ns |

### 64-bit

| Operation | `Rational{Int64}` | `Q64` | `Qx64` | `Qxf64` |
| --- | --- | --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns | 1 ns | 1 ns |
| a + b | 14 ns | 19 ns | 20 ns | 3 ns |
| a - b | 15 ns | 20 ns | 20 ns | 3 ns |
| a * b | 8 ns | 9 ns | 28 ns | 2 ns |
| a / b | 8 ns | 9 ns | 30 ns | 2 ns |
| -a | 1 ns | 1 ns | 1 ns | 1 ns |
| a < b | 1 ns | 1 ns | 2 ns | 2 ns |
| a == b | 1 ns | 1 ns | 2 ns | 1 ns |
| abs(-a) | 1 ns | 6 ns | 2 ns | 2 ns |
| inv(a) | 1 ns | 6 ns | 6 ns | 2 ns |
| a ^ 3 | 21 ns | 27 ns | 96 ns | 7 ns |
| a+b+c+d | 72 ns | 95 ns | 99 ns | 8 ns |
| a*b-c*d | 41 ns | 43 ns | 87 ns | 5 ns |
| muladd(a,b,a) | 27 ns | 29 ns | 61 ns | 6 ns |
| fma(a,b,a) | 27 ns | 827 ns | 845 ns | 873 ns |
| big + big | --- | --- | 83 ns | 81 ns |
| Inf + a | --- | --- | 2 ns | 2 ns |

### Qxf64 vs Rational{Int64}

`Qxf64` delays GCD normalization until display, hashing, or conversion, giving IEEE-like Inf/NaN semantics and faster arithmetic than stdlib.

| Operation | `Rational{Int64}` | `Qxf64` | Speedup |
| --- | --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns | ~1x |
| a + b | 14 ns | 3 ns | 5.3x |
| a - b | 15 ns | 3 ns | 5.5x |
| a * b | 8 ns | 2 ns | 3.8x |
| a / b | 8 ns | 2 ns | 3.1x |
| -a | 1 ns | 1 ns | ~1x |
| a < b | 1 ns | 2 ns | 0.78x |
| a == b | 1 ns | 1 ns | ~1x |
| abs(-a) | 1 ns | 1 ns | ~1x |
| inv(a) | 2 ns | 2 ns | ~1x |
| a ^ 3 | 21 ns | 7 ns | 3.1x |
| a+b+c+d | 72 ns | 8 ns | 9.4x |
| a*b-c*d | 41 ns | 5 ns | 8.2x |
| muladd(a,b,a) | 27 ns | 6 ns | 4.5x |
| fma(a,b,a) | 27 ns | 873 ns | 0.03x |
