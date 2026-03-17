# Usage Guide

## Installation

```julia
using Pkg
Pkg.add("ExtendedRationals")
```

## Type selection decision tree

```text
Do you need Inf/NaN support?
├── No  → Do you need overflow detection?
│         ├── Yes → Q32 or Q64
│         └── No  → Rational{Int32} or Rational{Int64} (stdlib)
└── Yes → Qx32 or Qx64
```

**32-bit vs 64-bit**: Use 32-bit types when values fit in Int32 range and you want compact storage or are memory-bound. Use 64-bit when you need the full Int64 range. Qx32 is the fastest type because Int32 intermediates use native Int64 arithmetic.

## Common patterns

### Accumulation without overflow crashes

```julia
using ExtendedRationals

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
using ExtendedRationals

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

1. **Prefer Qx32/Qx64** for chains of arithmetic. The GCD savings compound with every operation.
2. **Avoid accessing `numerator`/`denominator` in hot loops** — each call triggers normalization.
3. **Use `muladd` instead of `fma`** unless you specifically need the exact intermediate guarantee. `muladd` is `x*y + z` with lazy normalization; `fma` must normalize first.
4. **Qx32 is the fastest type** because Int32 intermediates use native Int64 arithmetic (single machine instruction), while Qx64 intermediates use Int128 (multi-word).
5. **Use Q32/Q64** when you want to detect overflow early rather than propagating Inf through a long computation.
