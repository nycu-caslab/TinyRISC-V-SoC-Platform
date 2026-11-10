# Lab 4 results

## SW mode (baseline)

Source: UART log `Platform/sw/results/lab4_sw_baseline.log`, captured with `make -C Platform run TFLM_SOFTWARE_CONV=1` on the Arty A7 (menu `t`, one sample, zero input), after a clean hardware rebuild and program (`make -C Platform all_clean && make -C Platform prog`). Output status `kTfLiteOk`.

| Item | Value |
|---|---|
| Model | mobileViT_xxs.tflite (1,212,672 bytes), tensor arena 8 MiB, 50 MHz |
| Conv mode | software/reference (upstream TFLM ConvPerChannel), `TFLM_SOFTWARE_CONV=1`; depthwise = upstream kernel |
| Build flags | `-march=rv32im -mabi=ilp32 -mcmodel=medany -O3 -g -DTFLM_MODEL_ENABLED=1 -DMODEL_NAME="mobileViT_xxs.tflite" -DTENSOR_ARENA_SIZE=8*1024*1024 -DTFLM_SOFTWARE_CONV=1`; `USE_SOFTWARE_CFU=0`; no `TFLM_OPERATOR_CYCLE_PROFILE` |
| Invoke cycles | **6,533,448,017** (130,668 ms) |
| Counter 0 (Logistic) | Total 844,295,109 cycles, **Starts 37**, avg 22,818,786 |
| Counter 1 (Transpose) | Total 7,042,050 cycles, **Starts 66**, avg 106,697 |

### Shares of Invoke (counter total / Invoke cycles)

| Operator | Cycles | Share of Invoke |
|---|---:|---:|
| Logistic (counter 0) | 844,295,109 | 12.92% |
| Transpose (counter 1) | 7,042,050 | 0.108% |

### Notes

- Counter 0 Starts = 37 matches the expected value. **Counter 1 Starts measured 66, not the expected 48.** The value is recorded as measured; the discrepancy is unexplained (the counter is incremented per Transpose kernel call in `tflm_patches/.../reference/transpose.h`).
- Earlier attempts (`lab4_sw_baseline_attempt1/2/3_*.log`) failed with `Missing registration for opcode_index 24`. A per-64KB hash of `g_model` showed DDR content differing from the file (6 of 19 blocks). After `all_clean` and `prog` (new bitstream), the same flow ran correctly. The cause of the corruption was not identified.

## Logistic-only acceleration (Logistic on NPU, Transpose on CPU)

Source: UART log `Platform/sw/results/lab4_logistic_npu.log`, captured by Claude (script `scratch/lab4/board_run_lab4.py`: waits for `SYNC`, uploads `main.bin`, then drives the menu `l` > `l,a,c,b,d,e`, then main menu `t`). Bitstream `Platform/build/out.bit` (sha256 `6d998fdb0f269a6860f859db5db2468f7585eb590dc60d10b97dde7dc900a011`, built 00:51 from `npu_logistic.v` + `NPU.v`, programmed with `make -C Platform prog`); post-route WNS +0.488 ns, WHS +0.009 ns (`build/reports/post_route_timing_summary.rpt`). SYNC arrived after programming, so no CPU RESET press was needed. Software built with `make -C Platform sw_clean && make -C Platform sw_build TFLM_SOFTWARE_CONV=1` (same Conv mode, model, input, 50 MHz and flags as the SW baseline above).

| Item | SW baseline (G1) | Logistic on NPU |
|---|---:|---:|
| Counter 0 (Logistic) Total | 844,295,109 | **8,223,236** |
| Counter 0 Starts / Average | 37 / 22,818,786 | 37 / 222,249 |
| Counter 1 (Transpose) Total / Starts | 7,042,050 / 66 | 7,035,336 / 66 (CPU, unchanged) |
| Invoke cycles | 6,533,448,017 (130,668 ms) | 5,697,410,972 (113,948 ms) |
| Operator speedup (Counter 0 Total ratio) | 1x | **102.67x** |
| Model speedup (Invoke ratio) | 1x | **1.147x** |

Checks in the same log:
- `Logistic tests: 4/4 passed` (all four `[PASS] LogisticQuantizedInt8...`).
- Model output (10 bytes): -32 114 -38 52 50 127 -120 -128 -71 80, identical to the reference (every element within +-2, error 0). Invoke status `kTfLiteOk`.
- Lab1/Lab2 menu tests: `a` AXI aligned ALL PASS (32 checks), `b` AXI misaligned ALL PASS (6 checks), `c` Basic Convolution 3/3 PASS (1,065,895 cycles total), `d` Basic platform ALL PASS (32 checks), `e` SIMD MAC ALL PASS (8 checks). No FAIL string in the log.

Design: CUSTOM-0 funct3=5 (`npu_logistic.v`): funct7=0 sets zero point and range radius, funct7=1 sets multiplier and shift and builds a 256-entry int8 table (saturation, MultiplyByQuantizedMultiplier and the gemmlowp fixed-point sigmoid evaluated per table entry, bit-exact; `NPU_done` only after all 256 entries are written), funct7=2 returns 4 packed int8 outputs for 4 packed int8 inputs. `logistic.h` int8 `Logistic()` configures once per call and processes 4 elements per instruction, with single-element head/tail; timing boundaries and Counter 0 unchanged. iverilog `npu_logistic_tb`: 10,496 outputs (41 parameter sets x 256 inputs), 0 mismatches. Table-build cost per call is part of the measured Total.

Not done in this step: Transpose acceleration (Counter 1 unchanged, Starts 66 as in baseline), and the other experiment-mode rows.

## Memory-system micro-benchmarks (AXI burst read, AXI write, cbo)

Source: UART log `Platform/sw/results/lab4_bench.log`, captured by Claude with `make -C Platform run` on the Arty A7 (bitstream already programmed; the log shows `SYNC`, upload, `Jump to 0x60000000`, then the benchmark run from the temporary menu entry lab > `z`). The measurement code is preserved as text only in `Platform/sw/results/lab4_bench_source_snapshot.cc.txt` and has been removed from `Platform/sw/project` (`git diff -- Platform/sw/project` is empty). Timing is `csrr mcycle` before/after; back-to-back `mcycle` reads differ by 1 cycle (`mcycle_overhead=1`). Clock 50 MHz, build flags as in the SW baseline (`-O3`, `rv32im`).

### AXI burst read beats/cycle (NPU burst dot product, funct3=100)

Two N-byte vectors (cleaned out of the D-cache, DDR) are fetched by the engine, so beats = 2·N/4 (input + filter). Cycles include set-length + compute instruction.

| N bytes | beats | cycles (3 runs) |
|---:|---:|---|
| 64 | 32 | 94, 91, 91 |
| 256 | 128 | 188, 187, 187 |
| 1024 | 512 | 571, 572, 571 |
| 4096 | 2048 | 2113, 2114, 2114 |

- Slope 1024→4096 bytes: 1536 beats / (2114 − 571) cycles = **0.995 beats/cycle** (about 1 beat/cycle, the AXI 32-bit data limit).
- Slope 256→1024: 384 / 384 = 1.00 beat/cycle.
- Fixed overhead (intercept) ≈ 60 cycles; whole-run average at 4096 B: 2048/2114 = 0.969 beats/cycle.

### Single-word AXI write latency (CUSTOM-0 funct3=010)

`cfu_op2` to one aligned word, 8 runs: **38 cycles** every time (includes 1 cycle mcycle overhead). For reference, single-word AXI read (funct3=001): 52, 48, 48 cycles.

### cbo.clean / cbo.invalidate (unrolled 32 lines × 32 B, no loop, address immediates)

| Case | cycles per 32 lines (4 runs) | cycles per cbo |
|---|---|---:|
| cbo.clean, lines dirty | 1278, 1281, 1276, 1278 | **≈ 39.9** |
| cbo.clean, lines already clean | 566 (cold), 302, 372, 304 | ≈ 9.4 (steady, best/typical 302–304) |
| cbo.invalidate, lines resident | 515 (cold), 240, 240, 240 | **≈ 7.5** |
| cbo.invalidate, lines not resident | 574 (cold), 241, 241, 241 | ≈ 7.5 |

Per-cbo figures include the ~1–2 address-setup instructions the compiler emits per cbo (not subtracted). The first run of each case is slower due to cold instruction cache. The 372 outlier in the clean-clean case is recorded as measured, not explained.

### Notes
- The first attempt (one run) uploaded the program but printed nothing after the clear-screen escape; the `upload.py` session was killed and restarted, and the second run printed everything. The user did not need to press CPU RESET in the successful run (SYNC was received on start). Burst results show `res=0` because the buffers were zero; only timing was measured.

## Transpose-only acceleration (Transpose on NPU, Logistic on CPU)

Source: UART log `Platform/sw/results/lab4_transpose_only_npu.log`, captured by Claude (script `Platform/sw/results/board_run_lab4.py`: waits for `SYNC`, uploads `main.bin`, drives lab menu `l,t,a,b,c,d,e`, then main menu `t`). Bitstream `Platform/build/out.bit` (sha256 `35d7f5c8c31979cb968af1d94de70c037e08fab620a757c8f3dc01aaa15034e5`, built with `make -C Platform all_clean && make -C Platform prog`); post-route **WNS +0.227 ns**, WHS +0.011 ns, 0 failing endpoints (`build/reports/post_route_timing_summary.rpt`); utilization 32,832 LUTs, 16 RAMB36 + 39 RAMB18. SYNC arrived right after programming, so no CPU RESET press was needed. Software: `make -C Platform sw_clean && make -C Platform sw_build TFLM_SOFTWARE_CONV=1` with `integer_ops/logistic.h` temporarily set to the original upstream (CPU) version, so Logistic stays on the CPU; same model, zero input, 50 MHz and flags as the SW baseline above.

| Item | SW baseline (G1) | Transpose on NPU (Transpose-only) |
|---|---:|---:|
| Counter 1 (Transpose) Total | 7,042,050 | **461,371** |
| Counter 1 Starts / Average | 66 / 106,697 | 66 / 6,990 |
| Counter 0 (Logistic, CPU) Total / Starts | 844,295,109 / 37 | 820,973,388 / 37 |
| Invoke cycles | 6,533,448,017 | 6,504,622,157 |
| Operator speedup (Counter 1 Total ratio) | 1x | **15.26x** |
| Model speedup (Invoke ratio) | 1x | 1.0044x |

Counter 1 Total 461,371 is below the G1 baseline (7,042,050) and below 500,000 cycles. Checks in the same log: `Transpose tests: 14/14 passed`; model output (10 bytes) -32 114 -38 52 50 127 -120 -128 -71 80, identical to the software reference (error 0, within +-2); Invoke `kTfLiteOk`; lab menu `a` AXI aligned ALL PASS (32), `b` AXI misaligned ALL PASS (6), `c` Basic Convolution 3/3 PASS, `d` ALL PASS (32), `e` SIMD MAC ALL PASS (8), `Logistic tests: 4/4 passed`; no FAIL string in the log. (Counter 1 Starts = 66, same as the baseline; the model has 48 Transpose ops and 18 BatchMatMul ops, which is the likely source of the other 18, not verified.)

Design (two engines selected by the CPU, same CUSTOM-0 funct3=6):
- Burst engine (`hw/srcs/npu_transpose_fast.v`, funct7=5 selects it, funct7=6 starts without waiting, funct7=7 waits, funct7=4 starts and waits): for int8 tensors <= 16 KiB, word-aligned output, total % 4 == 0 and R = product of the k innermost output extents divisible by 4 (R <= 4096). The NPU (1) reads the input with AXI INCR bursts into two 4096x32 block-RAM replicas (4 read ports), (2) concurrently builds a table of input byte offsets for the R innermost output elements, (3) gathers 4 output bytes per cycle (`offset = rowbase + table[b]`, rowbase from an odometer over the outer dimensions) and (4) writes the packed words back with AXI INCR write bursts (16 words) while the gather is still running. The CPU never loads/stores a tensor element.
- Single-beat engine (`hw/srcs/npu_transpose.v`): unchanged fallback for everything else (any element size 1..255, ranks 1-6, unaligned bases, tensors > 16 KiB, R not divisible by 4); which engine each model transpose used was not instrumented (the measured Total is consistent with the burst engine handling them); the unit tests and the testbench exercise both.
- `transpose.h`: cleans the input lines (cbo.clean), cleans only the boundary lines of an unaligned output, starts the engine asynchronously (funct7=6), invalidates the output lines while the NPU is running, then waits (funct7=7).
- Simulation: `hw/sim/npu_transpose_tb.sv` (AXI slave model now supports INCR bursts, random stalls 0-85%, 4 KB-boundary, WLAST and strobe checks), log `results/npu_transpose_tb.log`: **500/500 cases pass**, 0 failures, 0 protocol errors, 238 cases ran on the burst engine (incl. two 16 KiB model shapes), the rest on the single-beat engine; mutation checks (wrong table lane, wrong WLAST) make it fail. The other testbenches (`npu_logistic_tb`, `npu_burst_dot_product_tb`, misaligned AXI read/write) still pass.
- History: the earlier single-beat-only implementation measured Counter 1 Total 11,383,822 (slower than the CPU baseline); the first burst-engine bitstream (synchronous start, invalidate before and after) measured 519,845; overlapping the output invalidate with the NPU run gave 461,371.

## Both accelerated (Logistic on NPU + Transpose on NPU)

Source: UART log `Platform/sw/results/lab4_both_npu.log`, captured by Claude (script `Platform/sw/results/board_run_lab4.py ... ltabcde`: waits for `SYNC`, uploads `main.bin`, lab menu `l,t,a,b,c,d,e`, then main menu `t`). Bitstream `Platform/build/out.bit` (sha256 `fc6af308910b1755d26c6aede40b711014909614e4f81060b3564328d27322bb`, built 11:40 with `make -C Platform all_clean && make -C Platform prog` from the current `NPU.v` containing `npu_logistic`, `npu_transpose_fast` and `npu_transpose`). SYNC arrived right after programming (no CPU RESET press was needed in the successful run). Software: `make -C Platform sw_clean && make -C Platform sw_build TFLM_SOFTWARE_CONV=1` with the NPU versions of `integer_ops/logistic.h` and `reference/transpose.h`; same model, zero input, 50 MHz and flags as the SW baseline.

**Post-route timing of this bitstream** (`build/reports/post_route_timing_summary.rpt`, excerpt in `Platform/sw/results/lab4_both_post_route_timing_summary.txt`): **WNS +0.227 ns**, TNS 0.000, WHS +0.011 ns, 0 failing endpoints; "All user specified timing constraints are met."

| Item | SW baseline | Logistic-only | Transpose-only | Both |
|---|---:|---:|---:|---:|
| Counter 0 (Logistic) Total | 844,295,109 | 8,223,236 | 820,973,388 | **8,254,347** |
| Counter 1 (Transpose) Total | 7,042,050 | 7,035,336 | 461,371 | **461,530** |
| Starts (C0 / C1) | 37 / 66 | 37 / 66 | 37 / 66 | 37 / 66 |
| Invoke cycles | 6,533,448,017 | 5,697,410,972 | 6,504,622,157 | **5,691,554,991** (113,831 ms) |
| Logistic operator speedup (C0 Total ratio) | 1x | 102.67x | 1.03x | **102.28x** |
| Transpose operator speedup (C1 Total ratio) | 1x | 1.00x | 15.26x | **15.26x** |
| Model speedup (Invoke ratio) | 1x | 1.147x | 1.0044x | **1.148x** |

Checks in the same log: `Logistic tests: 4/4 passed`, `Transpose tests: 14/14 passed`, AXI aligned ALL PASS (32), misaligned ALL PASS (6), Basic Convolution 3/3 PASS, platform ALL PASS (32), SIMD MAC ALL PASS (8); no FAIL string; `AllocateTensors: kTfLiteOk`, `Invoke status: kTfLiteOk`; output (10 bytes) -32 114 -38 52 50 127 -120 -128 -71 80, identical to the reference.

Notes / failed attempts (kept in `Platform/sw/results/`): `lab4_both_attempt1_model_corrupt.log` (key args mistake; inference failed with `Unsupported data type 77 in tensor`) and `lab4_both_attempt2_hang_model_corrupt.log` (garbled model-info output, inference hung). Both showed the same DDR/model corruption as the earlier baseline attempts when the app was re-uploaded repeatedly on one programming session; after `all_clean && prog` the third run was correct. The cause is not identified.
