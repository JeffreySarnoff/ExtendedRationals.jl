XRationals benchmark report
Run with: julia --project=. test/Benchmark.jl

### 32-bit

| Operation | `Rational{Int32}` | `Qx32` | Speedup |
| --- | --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns | 0.95x |
| a + b | 13 ns | 2 ns | 6.6x |
| a - b | 13 ns | 2 ns | 6.9x |
| a * b | 8 ns | 2 ns | 4.0x |
| a / b | 7 ns | 2 ns | 3.9x |
| -a | 1 ns | 2 ns | 0.75x |
| a < b | 1 ns | 2 ns | 0.8x |
| a == b | 1 ns | 1 ns | ~1x |
| abs(-a) | 2 ns | 2 ns | 0.91x |
| inv(a) | 2 ns | 2 ns | 0.75x |
| a ^ 3 | 19 ns | 5 ns | 3.6x |
| a+b+c+d | 66 ns | 5 ns | 14.7x |
| a*b-c*d | 38 ns | 4 ns | 9.8x |
| muladd(a,b,a) | 23 ns | 3 ns | 7.3x |
| fma(a,b,a) | 23 ns | 217 ns | 0.11x |

### 64-bit

| Operation | `Rational{Int64}` | `Qx64` | Speedup |
| --- | --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns | ~1x |
| a + b | 13 ns | 3 ns | 5.2x |
| a - b | 15 ns | 3 ns | 5.2x |
| a * b | 9 ns | 2 ns | 3.9x |
| a / b | 8 ns | 3 ns | 3.2x |
| -a | 1 ns | 1 ns | 1.1x |
| a < b | 1 ns | 2 ns | 0.84x |
| a == b | 1 ns | 1 ns | 0.83x |
| abs(-a) | 1 ns | 2 ns | 0.92x |
| inv(a) | 1 ns | 2 ns | 0.8x |
| a ^ 3 | 22 ns | 7 ns | 3.0x |
| a+b+c+d | 72 ns | 8 ns | 9.4x |
| a*b-c*d | 43 ns | 5 ns | 8.6x |
| muladd(a,b,a) | 27 ns | 6 ns | 4.4x |
| fma(a,b,a) | 27 ns | 884 ns | 0.03x |

### 128-bit

| Operation | `Rational{Int128}` | `Qx128` | Speedup |
| --- | --- | --- | --- |
| construct(7,3) | 1 ns | 1 ns | ~1x |
| a + b | 76 ns | 7 ns | 10.6x |
| a - b | 80 ns | 8 ns | 10.7x |
| a * b | 65 ns | 6 ns | 10.8x |
| a / b | 58 ns | 7 ns | 8.6x |
| -a | 2 ns | 1 ns | 1.3x |
| a < b | 209 ns | 4 ns | 47.2x |
| a == b | 1 ns | 4 ns | 0.26x |
| abs(-a) | 2 ns | 2 ns | 0.9x |
| inv(a) | 2 ns | 3 ns | 0.61x |
| a ^ 3 | 179 ns | 15 ns | 11.8x |
| a+b+c+d | 271 ns | 20 ns | 13.3x |
| a*b-c*d | 216 ns | 16 ns | 13.2x |
| muladd(a,b,a) | 143 ns | 12 ns | 11.5x |
| fma(a,b,a) | 143 ns | 1.9 us | 0.07x |
