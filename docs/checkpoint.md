# XRationals Checkpoint

Saved: 2026-05-11

## Current state

`XRational512` / `Qx512` has been added and fully validated.

The first production performance pass is also complete:

- the finite-to-`Rational` bridge optimization has been promoted into all five production width modules under `src/`
- the wide-to-narrow conversion optimization has also been promoted into `src/XRationals.jl`

Completed in code:

- added `src/XRational512s.jl`
- exported `Qx512` from `src/XRationals.jl`
- added `BitIntegers.@define_integers 2048` at the root-module level to provide `Int2048`
- wired exact widening to `Qx512`
- wired narrowing from `Qx512` to `Qx256`, `Qx128`, `Qx64`, and `Qx32`
- extended `src/support.jl` with the `Int2048`-backed nearest-rational helper path used by `Qx512 -> Qx256`
- added `test/XRational512s_tests.jl`
- extended `test/CrossWidth_tests.jl` for `Qx512`
- extended `test/Benchmark.jl` for `Qx512`
- updated `README.md` and docs pages to mention `Qx512`
- promoted the one-pass finite bridge into:
  - `src/XRational32s.jl`
  - `src/XRational64s.jl`
  - `src/XRational128s.jl`
  - `src/XRational256s.jl`
  - `src/XRational512s.jl`
- promoted the raw-field narrowing path into `src/XRationals.jl` for:
  - `Qx64 -> Qx32`
  - `Qx128 -> Qx32`
  - `Qx256 -> Qx32`
  - `Qx512 -> Qx32`
  - `Qx128 -> Qx64`
  - `Qx256 -> Qx64`
  - `Qx512 -> Qx64`
  - `Qx256 -> Qx128`
  - `Qx512 -> Qx128`
  - `Qx512 -> Qx256`
- removed the temporary `src2/` prototypes after promotion

## Validation completed

- smoke load passed:
  - `using XRationals`
  - `Qx512(7, 3)`
  - `widen(Qx256)`
  - `Qx256(Qx512(7, 3))`
- focused tests passed:
  - `test/XRational512s_tests.jl`
  - `test/CrossWidth_tests.jl`
- benchmark harness passed:
  - `julia --project=. test/Benchmark.jl`
- full test suite passed:
  - `julia --project=. test/runtests.jl`
- docs build passed:
  - `julia --project=docs docs/make.jl`
- full test suite passed again after the wide-to-narrow promotion:
  - `julia --project=. test/runtests.jl`

## Representative local 512-bit benchmark results

| Operation | Rational{Int512} | Qx512 | Speedup |
| --- | ---: | ---: | ---: |
| `a + b` | 583 ns | 93 ns | 6.3x |
| `a * b` | 461 ns | 59 ns | 7.9x |
| `a / b` | 417 ns | 64 ns | 6.5x |
| `muladd(a,b,a)` | 941 ns | 156 ns | 6.0x |
| `a+b+c+d` | 2.1 us | 310 ns | 6.8x |
| `a*b-c*d` | 1.7 us | 222 ns | 7.9x |

## Production optimization promoted

The finite bridge optimization is now in production `src/` and matches the former `src2` prototype.

Comparative benchmark after promotion (`src` vs `src2` prototype):

### Rational conversion

| Type | Current src | src2 | Result |
| --- | ---: | ---: | ---: |
| `Qx32` | 3.7 ns | 3.7 ns | parity |
| `Qx64` | 4.0 ns | 4.0 ns | parity |
| `Qx128` | 14.8 ns | 14.8 ns | parity |
| `Qx256` | 81.0 ns | 81.0 ns | parity |
| `Qx512` | 154.3 ns | 154.5 ns | parity |

### `fma`

| Type | Current src | src2 | Result |
| --- | ---: | ---: | ---: |
| `Qx32` | 36.9 ns | 36.7 ns | parity |
| `Qx64` | 44.8 ns | 44.4 ns | parity |
| `Qx128` | 192.9 ns | 192.0 ns | parity |
| `Qx256` | 687.8 ns | 687.2 ns | parity |
| `Qx512` | 1.4 us | 1.4 us | parity |

## Wide-to-narrow review

The public narrowing constructors in `src/XRationals.jl` no longer normalize via `numerator(x)` / `denominator(x)` before entering the nearest-rational helpers. They now use raw `num` / `den` fields directly for the special-value check, range check, and helper input construction.

Pre-promotion benchmark results that justified the change were:

| Conversion | Current src | src2 | Speedup |
| --- | ---: | ---: | ---: |
| `Qx64 -> Qx32` exact-ish | 18.1 ns | 10.8 ns | 1.68x |
| `Qx256 -> Qx32` approx | 659.5 ns | 272.4 ns | 2.42x |
| `Qx512 -> Qx32` approx | 1.4 us | 590.9 ns | 2.38x |
| `Qx256 -> Qx64` approx | 1.0 us | 432.3 ns | 2.38x |
| `Qx512 -> Qx64` approx | 2.5 us | 1.0 us | 2.39x |
| `Qx256 -> Qx128` approx | 3.1 us | 2.0 us | 1.56x |
| `Qx512 -> Qx128` approx | 4.6 us | 2.0 us | 2.33x |
| `Qx512 -> Qx256` approx | 16.5 us | 11.6 us | 1.42x |

Status:

- benchmarked and confirmed as a real candidate
- promoted into production `src/`
- `src2/` prototypes removed after promotion

Post-promotion parity benchmark (`src` vs former `src2` behavior) showed the production path now matches the optimized implementation:

| Conversion | Current src | Former src2 | Result |
| --- | ---: | ---: | ---: |
| `Qx64 -> Qx32` exact-ish | 10.7 ns | 10.6 ns | parity |
| `Qx256 -> Qx32` approx | 259.2 ns | 258.6 ns | parity |
| `Qx512 -> Qx32` approx | 587.0 ns | 584.1 ns | parity |
| `Qx256 -> Qx64` approx | 431.3 ns | 430.6 ns | parity |
| `Qx512 -> Qx64` approx | 1.0 us | 1.0 us | parity |
| `Qx256 -> Qx128` approx | 1.9 us | 1.9 us | parity |
| `Qx512 -> Qx128` approx | 1.9 us | 1.9 us | parity |
| `Qx512 -> Qx256` approx | 11.4 us | 11.4 us | parity |

## Notes

- `Int2048` is intentionally defined only in the root module. Earlier attempts to define shared widths inside feature submodules produced incompatible integer types.
- No `XRational512` type docstring was added, to avoid changing the existing Documenter warning baseline unless the canonical-doc issue is addressed separately.
- Current docs warning baseline remains unchanged:
  - 3 uncaptured type docstrings (`XRational32`, `XRational64`, `XRational128`)
  - navbar repo-link warning
  - deployment-environment warning
- The docs build has not been rerun after the wide-to-narrow promotion because that change only touched runtime conversion logic in `src/XRationals.jl`; the last docs build remained clean at the existing warning baseline.