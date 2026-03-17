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
| a + b | 13 ns | 7 ns | 9 ns |
| a - b | 14 ns | 7 ns | 10 ns |
| a * b | 8 ns | 8 ns | 10 ns |
| a / b | 7 ns | 8 ns | 11 ns |
| -a | 1 ns | 5 ns | 5 ns |
| a < b | 1 ns | 1 ns | 2 ns |
| a == b | 1 ns | 1 ns | 2 ns |
| abs(-a) | 1 ns | 11 ns | 12 ns |
| inv(a) | 1 ns | 4 ns | 5 ns |
| a ^ 3 | 18 ns | 27 ns | 34 ns |
| muladd(a,b,a) | 23 ns | 17 ns | 22 ns |
| fma(a,b,a) | 23 ns | 166 ns | 204 ns |
| big + big | --- | --- | 20 ns |
| Inf + a | --- | --- | 3 ns |

### 64-bit

| Operation | `Rational{Int64}` | `Q64` | `Qx64` |
| --- | --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns | 1 ns |
| a + b | 13 ns | 19 ns | 24 ns |
| a - b | 15 ns | 20 ns | 22 ns |
| a * b | 8 ns | 9 ns | 32 ns |
| a / b | 8 ns | 9 ns | 36 ns |
| -a | 1 ns | 1 ns | 2 ns |
| a < b | 1 ns | 1 ns | 2 ns |
| a == b | 1 ns | 1 ns | 2 ns |
| abs(-a) | 1 ns | 6 ns | 2 ns |
| inv(a) | 2 ns | 6 ns | 6 ns |
| a ^ 3 | 21 ns | 27 ns | 104 ns |
| muladd(a,b,a) | 27 ns | 29 ns | 63 ns |
| fma(a,b,a) | 27 ns | 826 ns | 843 ns |
| big + big | --- | --- | 83 ns |
| Inf + a | --- | --- | 3 ns |
