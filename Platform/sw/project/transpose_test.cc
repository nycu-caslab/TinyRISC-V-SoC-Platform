#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "tensorflow/lite/kernels/internal/types.h"
#include "tensorflow/lite/kernels/internal/reference/transpose.h"
#include "cbo.h"   // cbo_clean / cbo_invalidate

namespace {

constexpr int kMaxDims    = 6;     // == tflite::kTransposeMaxDimensions
constexpr int kMaxElems   = 128;   // multiple of 32 bytes for int8
constexpr int kGuardBytes = 32;    // one cache line after the output
constexpr int8_t kSentinel = (int8_t)0xA5;

// Cache-line aligned buffers: the transpose code cleans/invalidates in 32-byte
// lines, so the buffers must not share lines with unrelated data.
alignas(32) int8_t g_in[kMaxElems];
alignas(32) int8_t g_out[kMaxElems + kGuardBytes];
alignas(32) int8_t g_golden[kMaxElems];

struct TransposeCase {
  const char* name;
  int dims;
  int32_t in_shape[kMaxDims];
  int32_t perm[kMaxDims];
  const int8_t* hand_golden;   // optional (nullptr = none); input is 1..N
};

// Hand-computed goldens (input data is 1, 2, 3, ... N).
const int8_t kGolden2x3[]     = {1, 4, 2, 5, 3, 6};
const int8_t kGolden2x2x2_210[] = {1, 5, 3, 7, 2, 6, 4, 8};

const TransposeCase kCases[] = {
  // name,                     dims, in_shape,            perm,              hand golden
  {"2D_2x3_perm10",            2, {2, 3},               {1, 0},            kGolden2x3},
  {"2D_4x5_perm10",            2, {4, 5},               {1, 0},            nullptr},
  {"2D_1x8_perm10",            2, {1, 8},               {1, 0},            nullptr},
  {"2D_identity_3x4_perm01",   2, {3, 4},               {0, 1},            nullptr},
  {"3D_2x2x2_perm210",         3, {2, 2, 2},            {2, 1, 0},         kGolden2x2x2_210},
  {"3D_2x3x4_perm201",         3, {2, 3, 4},            {2, 0, 1},         nullptr},
  {"3D_2x3x4_perm021",         3, {2, 3, 4},            {0, 2, 1},         nullptr},
  {"3D_3x2x5_perm102",         3, {3, 2, 5},            {1, 0, 2},         nullptr},
  {"3D_identity_2x3x4_perm012",3, {2, 3, 4},            {0, 1, 2},         nullptr},
  {"4D_NHWC_to_NCHW_1x3x4x2",  4, {1, 3, 4, 2},         {0, 3, 1, 2},      nullptr},
  {"4D_NCHW_to_NHWC_2x2x3x4",  4, {2, 2, 3, 4},         {0, 2, 3, 1},      nullptr},
  {"4D_reverse_2x3x2x3_perm3210", 4, {2, 3, 2, 3},      {3, 2, 1, 0},      nullptr},
  {"5D_2x2x2x2x3_perm43210",   5, {2, 2, 2, 2, 3},      {4, 3, 2, 1, 0},   nullptr},
  {"6D_2x2x2x2x2x2_perm543210",6, {2, 2, 2, 2, 2, 2},   {5, 4, 3, 2, 1, 0},nullptr},
};

// Simple, obviously-correct transpose used to produce the golden output.
// out_shape[d] = in_shape[perm[d]],  out(c0..cn) = in(...) where output dim d
// corresponds to input dim perm[d].
void ReferenceTranspose(const int8_t* in, int8_t* out, int dims,
                        const int32_t* in_shape, const int32_t* perm) {
  int in_stride[kMaxDims];
  in_stride[dims - 1] = 1;
  for (int i = dims - 2; i >= 0; --i) {
    in_stride[i] = in_stride[i + 1] * in_shape[i + 1];
  }

  int out_shape[kMaxDims];
  int total = 1;
  for (int d = 0; d < dims; ++d) {
    out_shape[d] = in_shape[perm[d]];
    total *= out_shape[d];
  }

  int coord[kMaxDims] = {0};
  for (int o = 0; o < total; ++o) {
    int in_idx = 0;
    for (int d = 0; d < dims; ++d) {
      in_idx += coord[d] * in_stride[perm[d]];
    }
    out[o] = in[in_idx];

    // Increment output coordinate (last dimension runs fastest).
    for (int d = dims - 1; d >= 0; --d) {
      if (++coord[d] < out_shape[d]) break;
      coord[d] = 0;
    }
  }
}

// Write cached data back to memory so the CFU sees it / sentinel is in DRAM.
void CleanRange(const void* ptr, uintptr_t bytes) {
  uintptr_t start = (uintptr_t)ptr & ~(uintptr_t)0x1f;
  uintptr_t end   = (uintptr_t)ptr + bytes;
  for (uintptr_t a = start; a < end; a += 32) {
    cbo_clean((void*)a);
  }
}

bool RunTransposeCase(const TransposeCase& c) {
  const int dims = c.dims;

  int total = 1;
  for (int d = 0; d < dims; ++d) total *= c.in_shape[d];
  if (total > kMaxElems) {
    printf("[FAIL] %s (needs %d elems, buffer holds %d)\n", c.name, total,
           kMaxElems);
    return false;
  }

  // Input: 1, 2, 3, ... (all distinct, so any misplacement is detected).
  for (int i = 0; i < total; ++i) g_in[i] = (int8_t)(i + 1);

  // Golden output.
  ReferenceTranspose(g_in, g_golden, dims, c.in_shape, c.perm);

  bool ok = true;

  // Check the reference itself against the hand-computed golden, if given.
  if (c.hand_golden != nullptr) {
    for (int i = 0; i < total; ++i) {
      if (g_golden[i] != c.hand_golden[i]) {
        printf("  (test bug) reference != hand golden at %d: %d vs %d\n", i,
               g_golden[i], c.hand_golden[i]);
        ok = false;
      }
    }
  }

  // Output buffer (and guard) = sentinel, and make sure it's in memory,
  // so stale dirty lines can't overwrite the CFU's result later.
  memset(g_out, kSentinel, sizeof(g_out));
  CleanRange(g_in, sizeof(g_in));
  CleanRange(g_out, sizeof(g_out));

  // Build parameters and shapes.
  tflite::TransposeParams params;
  params.perm_count = dims;
  int32_t out_dims[kMaxDims];
  for (int d = 0; d < dims; ++d) {
    params.perm[d] = c.perm[d];
    out_dims[d] = c.in_shape[c.perm[d]];
  }
  tflite::RuntimeShape input_shape(dims, c.in_shape);
  tflite::RuntimeShape output_shape(dims, out_dims);

  // Run the function under test.
  tflite::reference_ops::Transpose<int8_t>(params, input_shape, g_in,
                                           output_shape, g_out);

  // Compare output.
  int mismatches = 0;
  for (int i = 0; i < total; ++i) {
    if (g_out[i] != g_golden[i]) {
      if (mismatches < 5) {
        printf("  mismatch at %d: expected %d, got %d\n", i, g_golden[i],
               g_out[i]);
      }
      ++mismatches;
    }
  }
  if (mismatches > 0) {
    printf("  total mismatches: %d / %d\n", mismatches, total);
    ok = false;
  }

  // Check nothing was written past the end of the output.
  for (int i = total; i < kMaxElems + kGuardBytes; ++i) {
    if (g_out[i] != kSentinel) {
      printf("  out-of-range write at index %d (value %d)\n", i, g_out[i]);
      ok = false;
      break;
    }
  }

  printf("[%s] %s\n", ok ? "PASS" : "FAIL", c.name);
  return ok;
}

}  // namespace

// Runs all transpose (int8) tests and prints the results.
void run_transpose_test() {
  const int num_cases = (int)(sizeof(kCases) / sizeof(kCases[0]));
  int failed = 0;

  for (int i = 0; i < num_cases; ++i) {
    if (!RunTransposeCase(kCases[i])) ++failed;
  }

  printf("Transpose tests: %d/%d passed\n", num_cases - failed, num_cases);
}