# XRationals.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JeffreySarnoff.github.io/XRationals.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JeffreySarnoff.github.io/XRationals.jl/dev/)
[![Build Status](https://github.com/JeffreySarnoff/XRationals.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JeffreySarnoff/XRationals.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JeffreySarnoff/XRationals.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JeffreySarnoff/XRationals.jl)

Exact rational arithmetic with IEEE-like special values (NaN, Inf, -Inf), overflow-safe saturation, and lazy normalization for impressive throughput.

## Types

| Type | Alias | Backing | Overflow | Normalization |
| ------ | ------- | --------- | ------------------- | ------------- |
| `XRational32` | `Qx32` | `Int32` | Saturates to Inf/NaN | Lazy (Int64 intermediate) |
| `XRational64` | `Qx64` | `Int64` | Saturates to Inf/NaN | Lazy (Int128 intermediate) |

## Features

- Exact rational arithmetic with no floating-point rounding
- IEEE-like NaN, Inf, -Inf encoded in the same struct (`0//0`, `1//0`, `-1//0`)
- Overflow saturates to Inf/NaN instead of crashing (Qx types)
- Lazy GCD normalization: deferred until display, hashing, or conversion
- 3-13x faster than `Rational{Int}` for chained arithmetic
- Fused multiply-add (`fma`) with exact intermediate computation
- Cross-width conversion (Qx64 to Qx32) via best rational approximation
- Zero heap allocation: all arithmetic uses fixed-width integers (Int32/Int64/Int128/Int256)
- `typemin` rejection prevents silent negation overflow

## Examples

See Use.jl for examples.

## Benchmarks

All operations are zero-allocation unless noted. Times are minimum nanoseconds. 

Note: the fma for Qx32 and Qx64 returns the nearest rational to the true value.  Rational{Int32} and Rational{Int64} just perform a muladd.  This is the reason for slowdown in that function.  You can use muladd with Qx32 and Qx64 for improved performance.

### 32-bit

| Operation | `Rational{Int32}` | `Qx32` |
| --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns |
| a + b | 13 ns | 2 ns |
| a - b | 13 ns | 2 ns |
| a * b | 8 ns | 2 ns |
| a / b | 7 ns | 2 ns |
| -a | 1 ns | 1 ns |
| a < b | 1 ns | 2 ns |
| a == b | 1 ns | 1 ns |
| abs(-a) | 1 ns | 2 ns |
| inv(a) | 1 ns | 2 ns |
| a ^ 3 | 18 ns | 5 ns |
| a+b+c+d | 66 ns | 4 ns |
| a*b-c*d | 37 ns | 4 ns |
| muladd(a,b,a) | 23 ns | 3 ns |
| fma(a,b,a) | 23 ns | 215 ns |

### 64-bit

| Operation | `Rational{Int64}` | `Qx64` |
| --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns |
| a + b | 14 ns | 3 ns |
| a - b | 15 ns | 3 ns |
| a * b | 8 ns | 2 ns |
| a / b | 8 ns | 3 ns |
| -a | 1 ns | 1 ns |
| a < b | 1 ns | 2 ns |
| a == b | 1 ns | 1 ns |
| abs(-a) | 1 ns | 2 ns |
| inv(a) | 1 ns | 2 ns |
| a ^ 3 | 21 ns | 7 ns |
| a+b+c+d | 72 ns | 8 ns |
| a*b-c*d | 41 ns | 5 ns |
| muladd(a,b,a) | 27 ns | 6 ns |
| fma(a,b,a) | 27 ns | 859 ns |

### Qx64 vs Rational{Int64} Speedup

`Qx64` delays GCD normalization until display, hashing, or conversion, giving IEEE-like Inf/NaN semantics and faster arithmetic than stdlib.

| Operation | `Rational{Int64}` | `Qx64` | Speedup |
| --- | --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns | ~1x |
| a + b | 14 ns | 3 ns | 5.3x |
| a - b | 15 ns | 3 ns | 5.5x |
| a * b | 8 ns | 2 ns | 3.7x |
| a / b | 8 ns | 3 ns | 3.1x |
| -a | 1 ns | 1 ns | 1.1x |
| a < b | 1 ns | 2 ns | 0.84x |
| a == b | 1 ns | 1 ns | ~1x |
| abs(-a) | 1 ns | 1 ns | 0.89x |
| inv(a) | 2 ns | 2 ns | 0.91x |
| a ^ 3 | 21 ns | 7 ns | 3.1x |
| a+b+c+d | 72 ns | 8 ns | 9.4x |
| a*b-c*d | 41 ns | 5 ns | 8.3x |
| muladd(a,b,a) | 27 ns | 6 ns | 4.5x |
| fma(a,b,a) | 27 ns | 859 ns | 0.03x |
