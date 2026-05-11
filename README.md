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
| `XRational128` | `Qx128` | `Int128` | Saturates to Inf/NaN | Lazy (Int256 intermediate) |

## Features

- Exact rational arithmetic with no floating-point rounding
- IEEE-like NaN, Inf, -Inf encoded in the same struct (`0//0`, `1//0`, `-1//0`)
- Overflow saturates to Inf/NaN instead of crashing (Qx types)
- Lazy GCD normalization: deferred until display, hashing, or conversion
- 3-13x faster than `Rational{Int}` for chained arithmetic
- Fused multiply-add (`fma`) with exact intermediate computation
- Cross-width narrowing (`Qx128 -> Qx64`, `Qx128 -> Qx32`, `Qx64 -> Qx32`) via best rational approximation
- Exact widening across exported extended types through constructor-first APIs (`Qx64(x::Qx32)`, `Qx128(x::Qx32)`, `Qx128(x::Qx64)`), with `convert` and `widen` following the same width ladder
- Zero heap allocation: all arithmetic uses fixed-width integers (Int32/Int64/Int128/Int256/Int512/Int1024)
- `typemin` rejection prevents silent negation overflow

## Examples

See Use.jl for examples.

## Benchmarks

The package includes a runnable benchmark harness at `test/Benchmark.jl`:

```julia
julia --project=. test/Benchmark.jl
```

It compares `Qx32`, `Qx64`, and `Qx128` against stdlib `Rational{Int32}`, `Rational{Int64}`, and `Rational{Int128}` using `Chairmarks`.

Representative local results from that harness:

### Qx32 vs Rational{Int32}

| Operation | Rational{Int32} | Qx32 | Speedup |
| --- | ---: | ---: | ---: |
| `a + b` | 13 ns | 2 ns | 7.0x |
| `a * b` | 8 ns | 2 ns | 4.2x |
| `a / b` | 7 ns | 2 ns | 3.6x |
| `muladd(a,b,a)` | 25 ns | 3 ns | 7.5x |
| `a+b+c+d` | 66 ns | 5 ns | 14.3x |
| `a*b-c*d` | 40 ns | 4 ns | 10.1x |

### Qx64 vs Rational{Int64}

| Operation | Rational{Int64} | Qx64 | Speedup |
| --- | ---: | ---: | ---: |
| `a + b` | 14 ns | 3 ns | 5.3x |
| `a * b` | 9 ns | 2 ns | 4.0x |
| `a / b` | 8 ns | 3 ns | 3.2x |
| `muladd(a,b,a)` | 28 ns | 6 ns | 4.6x |
| `a+b+c+d` | 72 ns | 8 ns | 9.4x |
| `a*b-c*d` | 43 ns | 5 ns | 8.2x |

### Qx128 vs Rational{Int128}

| Operation | Rational{Int128} | Qx128 | Speedup |
| --- | ---: | ---: | ---: |
| `a + b` | 75 ns | 7 ns | 10.4x |
| `a * b` | 65 ns | 6 ns | 10.8x |
| `a / b` | 60 ns | 7 ns | 8.9x |
| `muladd(a,b,a)` | 144 ns | 12 ns | 11.7x |
| `a+b+c+d` | 269 ns | 20 ns | 13.2x |
| `a*b-c*d` | 216 ns | 17 ns | 12.5x |

`fma` is the main exception: `Qx32`, `Qx64`, and `Qx128` compute with exact widened intermediates and then round back to the nearest representable fixed-width rational, while stdlib `Rational` just performs `muladd`. If you do not need that guarantee, `muladd` is the faster path.
