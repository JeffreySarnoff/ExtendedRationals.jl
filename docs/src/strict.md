# Strict Rationals — Rational32 / Rational64 / Rational128

`Rational32`, `Rational64`, and `Rational128` are internal exact rational types that throw `OverflowError` when a result does not fit in the backing integer type. They are always stored in canonical form: `gcd(|num|, den) == 1`, `den > 0`, and zero is `0//1`.

> **Note**: These types are not exported from `XRationals`. They are used internally by the extended rational implementations. To use them directly, import via the submodule:
>
> ```julia
> using XRationals.XRational32s.Rational32s: Rational32
> using XRationals.XRational64s.Rational64s: Rational64
> using XRationals.XRational128s.Rational128s: Rational128
> ```

## When to use

- You need **exact arithmetic** and want immediate feedback when results exceed the representable range.
- You are building verified computations where silent overflow is unacceptable.
- You want the smallest possible overhead for operations that stay within range.

## Advantages

- **Deterministic errors**: overflow is never silent — it throws immediately.
- **Always canonical**: every value has a unique representation, so `==` and `hash` are trivially correct.
- **Fixed-width options**: 8 bytes for Rational32, 16 bytes for Rational64, 32 bytes for Rational128.

## Limitations

- Overflow throws, so you must handle errors or ensure inputs stay in range.
- No representation for Inf or NaN.

## Construction

```julia
using XRationals

a = Rational32(2, 3)         # 2//3
b = Rational32(7)            # 7//1
c = Rational64(355, 113)     # 355//113
d = Rational128(170141183460469231731687303715884105727, 9)

# Negative denominator is normalized
Rational32(3, -4)            # -3//4

# Zero numerator normalizes to 0//1
Rational32(0, 42)            # 0//1

# typemin is rejected to prevent negation overflow
Rational32(typemin(Int32), 1)   # throws OverflowError
Rational64(1, typemin(Int64))   # throws OverflowError
Rational128(1, typemin(Int128)) # throws OverflowError
```

## Arithmetic

All operations are exact when the result fits. Overflow throws `OverflowError`.

```julia
a = Rational32(2, 3)
b = Rational32(5, 7)

a + b    # 29//21
a - b    # -1//21
a * b    # 10//21
a / b    # 14//15
a ^ 3    # 8//27
inv(a)   # 3//2

# Overflow detection
Rational32(typemax(Int32), 1) + Rational32(1, 1)   # throws OverflowError
```

## Fused multiply-add

`fma(x, y, z)` computes `x*y + z` with an exact intermediate product (using wider integers internally), then finds the nearest representable result via Stern-Brocot mediants.

```julia
# Exact result
fma(Rational32(2, 3), Rational32(3, 4), Rational32(1, 2))   # 1//1

# Large arguments: exact intermediate in Int64, result rounded to nearest Rational32
fma(Rational32(typemax(Int32), 2), Rational32(typemax(Int32), 3), Rational32(1, 1))

# Large arguments: exact intermediate in Int512, result rounded to nearest Rational128
fma(Rational128(typemax(Int128), 2), Rational128(typemax(Int128), 3), Rational128(1, 1))
```

## Width summary

| Type | Backing | Arithmetic intermediates | FMA support |
| ---- | ------- | ------------------------ | ----------- |
| `Rational32` | `Int32` | `Int64` | nearest representable result via wider exact arithmetic |
| `Rational64` | `Int64` | `Int128` | nearest representable result via wider exact arithmetic |
| `Rational128` | `Int128` | `Int256` | nearest representable result via `Int512`/`Int1024` search |

## Quotient and remainder

```julia
x = Rational32(7, 3)
y = Rational32(2, 3)

rem(x, y)       # 1//3
mod(x, y)       # 1//3
fld(x, y)       # 3
cld(x, y)       # 4
divrem(x, y)    # (3, 1//3)
fldmod(x, y)    # (3, 1//3)
```
