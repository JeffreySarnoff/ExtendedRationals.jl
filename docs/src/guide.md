# Usage Guide

## Installation

```julia
using Pkg
Pkg.add("XRationals")
```

## Type selection decision tree

```text
Do you need Inf/NaN support?
├── No  → Rational{Int32}, Rational{Int64}, Rational{Int128}, Rational{Int256}, or Rational{Int512}
└── Yes → Qx32, Qx64, Qx128, Qx256, or Qx512
```

**32-bit vs 64-bit vs 128-bit vs 256-bit vs 512-bit**: Use 32-bit types when values fit in Int32 range and you want compact storage or are memory-bound. Use 64-bit for the usual full-machine-width range. Use 128-bit when you need much larger exact numerators and denominators. Use 256-bit when you need another large jump in exact finite range while keeping the same API. Use 512-bit when you need the widest fixed-width exported range and can afford slower multi-word arithmetic. Qx32 is still the fastest type because Int32-backed arithmetic stays on the smallest widened intermediates.

## Common patterns

### Accumulation without overflow crashes

```julia
using XRationals

function safe_mean(values::Vector{Qx32})
    s = Qx32(0, 1)
    for v in values
        s += v
    end
    return s / length(values)
end

# Even if intermediate sums overflow, result is Inf rather than an exception
data = [Qx32(typemax(Int32), 1), Qx32(typemax(Int32), 1)]
safe_mean(data)   # Inf (graceful saturation)
```

### High-throughput inner loop

```julia
using XRationals

function dot_product(xs::Vector{Qx64}, ys::Vector{Qx64})
    s = Qx64(0, 1)
    for i in eachindex(xs, ys)
        s += xs[i] * ys[i]
    end
    return s
end

# Each multiply and add skips GCD — only final display normalizes
xs = [Qx64(i, i+1) for i in 1:100]
ys = [Qx64(i+1, i+2) for i in 1:100]
dot_product(xs, ys)
```

### Exact fused multiply-add

When computing `x*y + z`, use `fma` for exact intermediate precision and `muladd` for speed:

```julia
x = Qx64(typemax(Int64), 2)
y = Qx64(typemax(Int64), 3)
z = Qx64(typemax(Int64), 5)

# fma: exact x*y in Int256, then nearest Qx64
fma(x, y, z)

# muladd: just x*y + z with normal overflow rules (faster)
muladd(x, y, z)
```

### Narrowing conversion

Convert a wide rational to the nearest representable narrow rational:

```julia
wide = Qx64(7, 22)     # exact
narrow = Qx32(wide)     # 7//22 (fits exactly)

# When the value needs approximation
big_ratio = Qx64(typemax(Int64) - 1, typemax(Int64))
Qx32(big_ratio)          # best Int32 approximation (near 1//1)

wide128 = Qx128(1, Int128(2) * Int128(typemax(Int64)) + 1)
Qx64(wide128)            # nearest Qx64, here 0//1
Qx32(wide128)            # nearest Qx32, also 0//1

wide256 = Qx256(wide128)
Qx128(wide256)           # nearest Qx128, here still exact

wide512 = Qx512(wide256)
Qx256(wide512)           # nearest Qx256, here still exact
```

### Exact widening conversion

Widen a smaller extended rational exactly into a larger one:

```julia
small32 = Qx32(6, 8)
mid64 = Qx64(small32)    # exact widening, raw 6//8 layout preserved
wide128 = Qx128(mid64)   # exact widening again
wide256 = Qx256(wide128) # exact widening into Int256-backed storage
wide512 = Qx512(wide256) # exact widening into Int512-backed storage
same_mid64 = convert(Qx64, small32)  # same constructor-first widening semantics
next_type = widen(Qx32)  # Qx64
same_widened = widen(small32)  # same as Qx64(small32)
widest_type = widen(Qx128)  # Qx256
widest_exported_type = widen(Qx256)  # Qx512

Qx128(Qx32(7, 3))        # 7//3
Qx128(Qx64(1, 0))        # Inf
Qx256(Qx128(7, 3))       # 7//3
Qx512(Qx256(7, 3))       # 7//3
```

## Interoperability with stdlib Rational

```julia
# Convert to stdlib
r = Rational{Int64}(numerator(Qx64(3, 4)), denominator(Qx64(3, 4)))

# Convert from stdlib
x = Qx64(r)

# Convert from float
Qx32(0.75)   # 3//4
Qx64(3.14)   # best Int64 rational approximation of pi
```

## Performance tips

1. **Prefer Qx32/Qx64/Qx128/Qx256/Qx512** for chains of arithmetic. The GCD savings compound with every operation.
2. **Avoid accessing `numerator`/`denominator` in hot loops** — each call triggers normalization.
3. **Use `muladd` instead of `fma`** unless you specifically need the exact intermediate guarantee. `muladd` is `x*y + z` with lazy normalization; `fma` must normalize first.
4. **Qx32 is the fastest type** because Int32 intermediates use native Int64 arithmetic (single machine instruction), while Qx64, Qx128, Qx256, and Qx512 require progressively wider multi-word arithmetic.
5. **Use Qx128, Qx256, or Qx512 only when you need the extra range.** They preserve the API shape, but wider intermediates cost more than the 32- and 64-bit variants.

## Benchmark harness

The repository ships with a runnable benchmark script:

```julia
julia --project=. test/Benchmark.jl
```

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

### Qx256 vs Rational{Int256}

| Operation | Rational{Int256} | Qx256 | Speedup |
| --- | ---: | ---: | ---: |
| `a + b` | 267 ns | 23 ns | 11.4x |
| `a * b` | 230 ns | 16 ns | 14.3x |
| `a / b` | 208 ns | 19 ns | 11.1x |
| `muladd(a,b,a)` | 438 ns | 38 ns | 11.4x |
| `a+b+c+d` | 996 ns | 69 ns | 14.5x |
| `a*b-c*d` | 791 ns | 53 ns | 14.8x |

### Qx512 vs Rational{Int512}

| Operation | Rational{Int512} | Qx512 | Speedup |
| --- | ---: | ---: | ---: |
| `a + b` | 583 ns | 93 ns | 6.3x |
| `a * b` | 461 ns | 59 ns | 7.9x |
| `a / b` | 417 ns | 64 ns | 6.5x |
| `muladd(a,b,a)` | 941 ns | 156 ns | 6.0x |
| `a+b+c+d` | 2.1 us | 310 ns | 6.8x |
| `a*b-c*d` | 1.7 us | 222 ns | 7.9x |

`fma` remains slower than stdlib `Rational` because it routes finite fused multiply-add through a slower exact-or-canonical path before converting back to the fixed-width result. Use `muladd` when you want the faster lazy path.
