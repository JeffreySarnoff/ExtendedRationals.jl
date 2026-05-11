# XRationals Checkpoint

Saved: 2026-05-11

## Current state

`XRational512` / `Qx512` has been added following the same pattern as `XRational256`.

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

## Representative local 512-bit benchmark results

| Operation | Rational{Int512} | Qx512 | Speedup |
| --- | ---: | ---: | ---: |
| `a + b` | 583 ns | 93 ns | 6.3x |
| `a * b` | 461 ns | 59 ns | 7.9x |
| `a / b` | 417 ns | 64 ns | 6.5x |
| `muladd(a,b,a)` | 941 ns | 156 ns | 6.0x |
| `a+b+c+d` | 2.1 us | 310 ns | 6.8x |
| `a*b-c*d` | 1.7 us | 222 ns | 7.9x |

## Remaining work

The final full-repo validation pass is still pending:

- `julia --project=. test/runtests.jl`
- `julia --project=docs docs/make.jl`

## Notes

- `Int2048` is intentionally defined only in the root module. Earlier attempts to define shared widths inside feature submodules produced incompatible integer types.
- No `XRational512` type docstring was added, to avoid changing the existing Documenter warning baseline unless the canonical-doc issue is addressed separately.