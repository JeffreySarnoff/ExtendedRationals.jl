# API Reference

## Exported types and aliases

| Type | Alias | Description |
| ---- | ----- | ----------- |
| `XRational32` | `Qx32` | Extended rational with Inf/NaN, lazy normalization, Int64 intermediates |
| `XRational64` | `Qx64` | Extended rational with Inf/NaN, lazy normalization, Int128 intermediates |
| `XRational128` | `Qx128` | Extended rational with Inf/NaN, lazy normalization, Int256 intermediates |
| `XRational256` | `Qx256` | Extended rational with Inf/NaN, lazy normalization, Int512 intermediates |
| `XRational512` | `Qx512` | Extended rational with Inf/NaN, lazy normalization, Int1024 intermediates |

## Constructors

The exported `Qx` types share the same constructor pattern:

```julia
T(numerator, denominator)
T(integer)          # denominator defaults to 1
T(float)            # best rational approximation
T(x::Rational{<:Integer})  # from stdlib Rational
```

`typemin(Int32)`, `typemin(Int64)`, `typemin(Int128)`, `typemin(Int256)`, and `typemin(Int512)` are rejected in both numerator and denominator positions to prevent silent negation overflow.

## Special values (Qx types only)

```julia
T(1, 0)    # +Inf
T(-1, 0)   # -Inf
T(0, 0)    # NaN
```

Module-local constructors (not exported, accessed via submodule):

- `nan(T)` — returns NaN of type `T`
- `inf(T)` / `posinf(T)` — returns +Inf of type `T`
- `neginf(T)` — returns -Inf of type `T`
- `finite(x)` — returns `true` if `x` is finite (equivalent to `isfinite`)

## Complete operation list

The tables below describe the public `Qx32`, `Qx64`, `Qx128`, `Qx256`, and `Qx512` API.

### Construction and identity

| Operation | Description |
| --------- | ----------- |
| `T(num, den)` | Construct from numerator and denominator |
| `T(integer)` | Construct from integer (den = 1) |
| `T(float)` | Best rational approximation of float |
| `T(::Rational)` | Convert from stdlib Rational |
| `zero(T)` / `zero(x)` | Additive identity `0//1` |
| `one(T)` / `one(x)` | Multiplicative identity `1//1` |
| `typemin(T)` | `-Inf` |
| `typemax(T)` | `+Inf` |

### Unary arithmetic

| Operation | Description |
| --------- | ----------- |
| `-x` | Negation |
| `abs(x)` | Absolute value |
| `inv(x)` | Multiplicative inverse `den//num` |
| `sign(x)` | Sign: -1, 0, or 1 (as rational) |

### Binary arithmetic

| Operation | Description |
| --------- | ----------- |
| `x + y` | Addition |
| `x - y` | Subtraction |
| `x * y` | Multiplication |
| `x / y` | Division |
| `x ^ p` | Integer exponentiation |

All binary operations also accept mixed arguments with `Integer` and stdlib `Rational` values.

### Fused multiply-add

| Operation | Description |
| --------- | ----------- |
| `fma(x, y, z)` | Exact intermediate `x*y`, then nearest representable `x*y + z` |
| `muladd(x, y, z)` | `x*y + z` with the normal lazy arithmetic path |

Intermediate precision by type:

- Qx32: `x*y` computed in Int64, result via Stern-Brocot in Int128
- Qx64: `x*y` computed in Int128, result via Stern-Brocot in Int256
- Qx128: `x*y` computed with wider fixed-width arithmetic, result via Stern-Brocot in Int512/Int1024
- Qx256: finite arguments are routed through `Rational{Int256}` and converted back into Qx256
- Qx512: finite arguments are routed through `Rational{Int512}` and converted back into Qx512

### Quotient and remainder

| Operation | Description |
| --------- | ----------- |
| `rem(x, y)` | Remainder (truncated division) |
| `mod(x, y)` | Modulus (floored division) |
| `fld(x, y)` | Floored quotient |
| `cld(x, y)` | Ceiled quotient |
| `divrem(x, y)` | Truncated quotient and remainder |
| `fldmod(x, y)` | Floored quotient and modulus |
| `fldmod1(x, y)` | 1-based floored quotient and modulus |

For Qx types: returns NaN if either argument is NaN/Inf, or if divisor is zero. For `fld`, `cld`, `divrem`, `fldmod1`: throws `DomainError` on invalid arguments.

### Sign operations

| Operation | Description |
| --------- | ----------- |
| `signbit(x)` | `true` if numerator is negative |
| `sign(x)` | Returns -1//1, 0//1, or 1//1 |
| `copysign(x, y)` | `x` with the sign of `y` |
| `flipsign(x, y)` | `x` with sign flipped if `y` is negative |

### Predicates

| Operation | Description |
| --------- | ----------- |
| `isfinite(x)` | `true` if not Inf and not NaN |
| `isinf(x)` | `true` if +Inf or -Inf |
| `isnan(x)` | `true` if NaN |
| `iszero(x)` | `true` if `x == 0` |
| `isone(x)` | `true` if `x == 1` |
| `isinteger(x)` | `true` if denominator divides numerator |

### Comparison and ordering

| Operation | Description |
| --------- | ----------- |
| `x == y` | Equality (NaN != NaN) |
| `x < y` | Strict less-than (NaN returns false) |
| `x <= y` | Less-than-or-equal (NaN returns false) |
| `x > y` | Strict greater-than |
| `x >= y` | Greater-than-or-equal |
| `isless(x, y)` | Total order (NaN sorts last) |

Qx types use cross-multiplication for comparison — no normalization required.

### Component access

| Operation | Description |
| --------- | ----------- |
| `numerator(x)` | Canonical numerator (triggers normalization) |
| `denominator(x)` | Canonical denominator (triggers normalization) |

### Rounding

| Operation | Description |
| --------- | ----------- |
| `round(T, x)` | Round to nearest integer of type `T` |
| `trunc(T, x)` | Truncate toward zero |
| `trunc(x)` | Truncate, returning the same rational type |
| `floor(T, x)` | Round down to integer of type `T` |
| `floor(x)` | Floor, returning the same rational type |
| `ceil(T, x)` | Round up to integer of type `T` |
| `ceil(x)` | Ceil, returning the same rational type |

### Type conversion

| Operation | Description |
| --------- | ----------- |
| `convert(Float64, x)` | Convert to Float64 |
| `convert(Float32, x)` | Convert to Float32 |
| `convert(BigFloat, x)` | Convert to BigFloat |
| `convert(Rational{T}, x)` | Convert to stdlib Rational (throws on Inf/NaN) |
| `float(x)` | Convert to default float (`Float64`) |

### Type promotion

| Operation | Description |
| --------- | ----------- |
| `promote_rule` | Promotion with `Integer` and stdlib `Rational` |

### Cross-width conversion

Exact widening is constructor-first in the public API. The corresponding `convert` methods delegate to the same widening semantics, and `widen` follows the same type ladder.

| Operation | Description |
| --------- | ----------- |
| `Qx32(x::Qx64)` | Narrow Qx64 to Qx32 via Stern-Brocot best approximation |
| `Qx32(x::Qx128)` | Narrow Qx128 to Qx32 via Stern-Brocot best approximation |
| `Qx32(x::Qx256)` | Narrow Qx256 to Qx32 via Stern-Brocot best approximation |
| `Qx32(x::Qx512)` | Narrow Qx512 to Qx32 via Stern-Brocot best approximation |
| `Qx64(x::Qx32)` | Widen Qx32 to Qx64 exactly |
| `Qx64(x::Qx128)` | Narrow Qx128 to Qx64 via Stern-Brocot best approximation |
| `Qx64(x::Qx256)` | Narrow Qx256 to Qx64 via Stern-Brocot best approximation |
| `Qx64(x::Qx512)` | Narrow Qx512 to Qx64 via Stern-Brocot best approximation |
| `Qx128(x::Qx32)` | Widen Qx32 to Qx128 exactly |
| `Qx128(x::Qx64)` | Widen Qx64 to Qx128 exactly |
| `Qx128(x::Qx256)` | Narrow Qx256 to Qx128 via Stern-Brocot best approximation |
| `Qx128(x::Qx512)` | Narrow Qx512 to Qx128 via Stern-Brocot best approximation |
| `Qx256(x::Qx32)` | Widen Qx32 to Qx256 exactly |
| `Qx256(x::Qx64)` | Widen Qx64 to Qx256 exactly |
| `Qx256(x::Qx128)` | Widen Qx128 to Qx256 exactly |
| `Qx256(x::Qx512)` | Narrow Qx512 to Qx256 via Stern-Brocot best approximation |
| `Qx512(x::Qx32)` | Widen Qx32 to Qx512 exactly |
| `Qx512(x::Qx64)` | Widen Qx64 to Qx512 exactly |
| `Qx512(x::Qx128)` | Widen Qx128 to Qx512 exactly |
| `Qx512(x::Qx256)` | Widen Qx256 to Qx512 exactly |
| `widen(Qx32)` | Return `Qx64` as the next wider extended rational type |
| `widen(Qx64)` | Return `Qx128` as the next wider extended rational type |
| `widen(Qx128)` | Return `Qx256` as the next wider extended rational type |
| `widen(Qx256)` | Return `Qx512` as the next wider extended rational type |
| `widen(x::Qx32)` | Widen a Qx32 value to Qx64 |
| `widen(x::Qx64)` | Widen a Qx64 value to Qx128 |
| `widen(x::Qx128)` | Widen a Qx128 value to Qx256 |
| `widen(x::Qx256)` | Widen a Qx256 value to Qx512 |

### Hashing and display

| Operation | Description |
| --------- | ----------- |
| `hash(x, h)` | Hash value (normalizes first) |
| `show(io, x)` | Display (normalizes before printing) |
