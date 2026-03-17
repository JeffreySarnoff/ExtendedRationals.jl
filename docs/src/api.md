# API Reference

## Exported types and aliases

| Type | Alias | Description |
| ---- | ----- | ----------- |
| `Rational32` | `Q32` | Strict exact rational, Int32-backed, throws on overflow |
| `Rational64` | `Q64` | Strict exact rational, Int64-backed, throws on overflow |
| `ExtendedRational32` | `Qx32` | Extended rational with Inf/NaN, Int32-backed, saturates on overflow |
| `ExtendedRational64` | `Qx64` | Extended rational with Inf/NaN, Int64-backed, saturates on overflow |
| `ExtendedRationalFast32` | `Qxf32` | Fast extended rational, lazy normalization, Int64 intermediates |
| `ExtendedRationalFast64` | `Qxf64` | Fast extended rational, lazy normalization, Int128 intermediates |

## Constructors

All types share the same two-argument constructor pattern:

```julia
T(numerator, denominator)
T(integer)          # denominator defaults to 1
T(float)            # best rational approximation
T(x::Rational{<:Integer})  # from stdlib Rational
```

`typemin(Int32)` and `typemin(Int64)` are rejected in both numerator and denominator positions to prevent silent negation overflow.

## Special values (Extended and Fast types only)

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

The table below shows every implemented operation and which type families support it.

**Legend**: Q = Q32/Q64, Qx = Qx32/Qx64, Qxf = Qxf32/Qxf64

### Construction and identity

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `T(num, den)` | Y | Y | Y | Construct from numerator and denominator |
| `T(integer)` | Y | Y | Y | Construct from integer (den = 1) |
| `T(float)` | Y | Y | Y | Best rational approximation of float |
| `T(::Rational)` | Y | Y | Y | Convert from stdlib Rational |
| `zero(T)` / `zero(x)` | Y | Y | Y | Additive identity `0//1` |
| `one(T)` / `one(x)` | Y | Y | Y | Multiplicative identity `1//1` |
| `typemin(T)` | Y | Y | Y | Minimum value (Q: smallest finite; Qx/Qxf: -Inf) |
| `typemax(T)` | Y | Y | Y | Maximum value (Q: largest finite; Qx/Qxf: +Inf) |

### Unary arithmetic

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `-x` | Y | Y | Y | Negation |
| `abs(x)` | Y | Y | Y | Absolute value |
| `inv(x)` | Y | Y | Y | Multiplicative inverse `den//num` |
| `sign(x)` | Y | Y | Y | Sign: -1, 0, or 1 (as rational) |

### Binary arithmetic

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `x + y` | Y | Y | Y | Addition |
| `x - y` | Y | Y | Y | Subtraction |
| `x * y` | Y | Y | Y | Multiplication |
| `x / y` | Y | Y | Y | Division |
| `x ^ p` | Y | Y | Y | Integer exponentiation |

All binary operations also accept mixed arguments with `Integer` and the corresponding strict `Rational` type (e.g., `Qx32 + Int`, `Qxf64 * Rational64`).

### Fused multiply-add

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `fma(x, y, z)` | Y | Y | Y | Exact intermediate `x*y`, then nearest representable `x*y + z` |
| `muladd(x, y, z)` | Y | Y | Y | `x*y + z` (Q/Qx: same as fma; Qxf: lazy, no normalization) |

Intermediate precision by type:

- Q32/Qx32/Qxf32: `x*y` computed in Int64, result via Stern-Brocot in Int128
- Q64/Qx64/Qxf64: `x*y` computed in Int128, result via Stern-Brocot in Int256

### Quotient and remainder

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `rem(x, y)` | Y | Y | Y | Remainder (truncated division) |
| `mod(x, y)` | Y | Y | Y | Modulus (floored division) |
| `fld(x, y)` | Y | Y | Y | Floored quotient |
| `cld(x, y)` | Y | Y | Y | Ceiled quotient |
| `divrem(x, y)` | Y | Y | Y | Truncated quotient and remainder |
| `fldmod(x, y)` | Y | Y | Y | Floored quotient and modulus |
| `fldmod1(x, y)` | Y | Y | Y | 1-based floored quotient and modulus |

For Qx and Qxf types: returns NaN if either argument is NaN/Inf, or if divisor is zero. For `fld`, `cld`, `divrem`, `fldmod1`: throws `DomainError` on invalid arguments.

### Sign operations

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `signbit(x)` | Y | Y | Y | `true` if numerator is negative |
| `sign(x)` | Y | Y | Y | Returns -1//1, 0//1, or 1//1 |
| `copysign(x, y)` | Y | Y | Y | `x` with the sign of `y` |
| `flipsign(x, y)` | Y | Y | Y | `x` with sign flipped if `y` is negative |

### Predicates

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `isfinite(x)` | - | Y | Y | `true` if not Inf and not NaN |
| `isinf(x)` | - | Y | Y | `true` if +Inf or -Inf |
| `isnan(x)` | - | Y | Y | `true` if NaN |
| `iszero(x)` | Y | Y | Y | `true` if `x == 0` |
| `isone(x)` | Y | Y | Y | `true` if `x == 1` |
| `isinteger(x)` | Y | Y | Y | `true` if denominator divides numerator |

Q types are always finite, so `isfinite`/`isinf`/`isnan` are not needed.

### Comparison and ordering

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `x == y` | Y | Y | Y | Equality (NaN != NaN) |
| `x < y` | Y | Y | Y | Strict less-than (NaN returns false) |
| `x <= y` | Y | Y | Y | Less-than-or-equal (NaN returns false) |
| `x > y` | Y | Y | Y | Strict greater-than |
| `x >= y` | Y | Y | Y | Greater-than-or-equal |
| `isless(x, y)` | Y | Y | Y | Total order (NaN sorts last) |

Qxf types use cross-multiplication for comparison — no normalization required.

### Component access

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `numerator(x)` | Y | Y | Y | Canonical numerator (Qxf: triggers normalization) |
| `denominator(x)` | Y | Y | Y | Canonical denominator (Qxf: triggers normalization) |

### Rounding

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `round(T, x)` | Y | Y | Y | Round to nearest integer of type `T` |
| `trunc(T, x)` | Y | Y | Y | Truncate toward zero |
| `trunc(x)` | - | Y | Y | Truncate, returning same rational type |
| `floor(T, x)` | Y | Y | Y | Round down to integer of type `T` |
| `floor(x)` | - | Y | Y | Floor, returning same rational type |
| `ceil(T, x)` | Y | Y | Y | Round up to integer of type `T` |
| `ceil(x)` | - | Y | Y | Ceil, returning same rational type |

### Type conversion

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `convert(Float64, x)` | Y | Y | Y | Convert to Float64 |
| `convert(Float32, x)` | Y | Y | Y | Convert to Float32 |
| `convert(BigFloat, x)` | Y | Y | Y | Convert to BigFloat |
| `convert(Rational{T}, x)` | - | Y | Y | Convert to stdlib Rational (throws on Inf/NaN) |
| `float(x)` | Y | Y | Y | Convert to default float (Float64) |

### Type promotion

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `promote_rule` | Y | Y | Y | Promotion with Integer and corresponding Rational |

### Cross-width conversion

| Operation | Description |
| --------- | ----------- |
| `Qx32(x::Qx64)` | Narrow Qx64 to Qx32 via Stern-Brocot best approximation |
| `Qx64(x::Qx32)` | Widen Qx32 to Qx64 (exact) |

### Hashing and display

| Operation | Q | Qx | Qxf | Description |
| --------- | - | -- | --- | ----------- |
| `hash(x, h)` | Y | Y | Y | Hash value (Qxf: normalizes first) |
| `show(io, x)` | Y | Y | Y | Display (Qxf: normalizes before printing) |
