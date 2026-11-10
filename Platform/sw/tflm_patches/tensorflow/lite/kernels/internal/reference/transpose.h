/* Copyright 2020 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/
#ifndef TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_TRANSPOSE_H_
#define TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_TRANSPOSE_H_

#include <array>

#include "tensorflow/lite/kernels/internal/types.h"
#include "perf.h"
#include "cfu.h"
#include "cbo.h"
#include <stdio.h>

namespace tflite {

namespace reference_ops {

// Transpose on the NPU (CUSTOM-0 funct3 = 6, see hw/srcs/npu_transpose.v).
//
// The accelerator walks the output tensor in row-major order and fetches /
// stores every element itself over AXI, so the CPU never touches tensor
// elements. The CPU only programs, per output dimension, the extent and the
// signed input byte delta applied when that dimension is the one that
// advances:  delta[d] = stride[d] - sum_{e>d} (extent[e] - 1) * stride[e].
// Dimensions are right-aligned into the 6 hardware dimensions (extent 1).
//
// The NPU reads and writes DDR directly, so the input is cleaned out of the
// D-cache first and the output range is cleaned + invalidated before the run
// (preserving unrelated bytes that share a boundary line) and invalidated
// afterwards.
//
// Burst mode (CUSTOM-0 funct3 = 6, funct7 = 5, hw/srcs/npu_transpose_fast.v):
// for int8 tensors of at most 16 KiB the NPU first reads the whole input with
// AXI burst reads into on-chip RAM, gathers 4 output bytes per cycle and writes
// them back with AXI burst writes. It needs a word aligned output, total % 4 == 0
// and the product R of the k innermost output extents to be a multiple of 4
// (R <= 4096); otherwise the single-beat engine above is used.
//
// Note: template parameter N is not used; it is kept for API compatibility.
namespace transpose_internal {

constexpr int kHwDims = 6;
static_assert(kTransposeMaxDimensions <= kHwDims,
              "NPU transpose supports at most 6 dimensions");

inline void CacheClean(const void* ptr, uintptr_t bytes) {
  uintptr_t a = reinterpret_cast<uintptr_t>(ptr) & ~static_cast<uintptr_t>(31);
  const uintptr_t end = reinterpret_cast<uintptr_t>(ptr) + bytes;
  for (; a + 128 <= end; a += 128) {
    cbo_clean(reinterpret_cast<void*>(a));
    cbo_clean(reinterpret_cast<void*>(a + 32));
    cbo_clean(reinterpret_cast<void*>(a + 64));
    cbo_clean(reinterpret_cast<void*>(a + 96));
  }
  for (; a < end; a += 32) cbo_clean(reinterpret_cast<void*>(a));
}

inline void CacheInvalidate(const void* ptr, uintptr_t bytes) {
  uintptr_t a = reinterpret_cast<uintptr_t>(ptr) & ~static_cast<uintptr_t>(31);
  const uintptr_t end = reinterpret_cast<uintptr_t>(ptr) + bytes;
  for (; a + 128 <= end; a += 128) {
    cbo_invalidate(reinterpret_cast<void*>(a));
    cbo_invalidate(reinterpret_cast<void*>(a + 32));
    cbo_invalidate(reinterpret_cast<void*>(a + 64));
    cbo_invalidate(reinterpret_cast<void*>(a + 96));
  }
  for (; a < end; a += 32) cbo_invalidate(reinterpret_cast<void*>(a));
}

}  // namespace transpose_internal

// Copies a tensor to an other buffer and permutes its dimensions.
template <typename T, int N = kTransposeMaxDimensions>
void Transpose(const TransposeParams& params, const RuntimeShape& input_shape,
               const T* input_data, const RuntimeShape& output_shape,
               T* output_data) {

  // perf reccord
  // TIMING START - DO NOT MODIFY OR MOVE.
  // --------------------------------------------------
  uint64_t start = perf_get_mcycle64();
  // --------------------------------------------------

  using namespace transpose_internal;
  const int dims = input_shape.DimensionsCount();
  const int32_t* const in_dims = input_shape.DimsData();
  const int32_t* const out_dims = output_shape.DimsData();
  const int32_t esize = static_cast<int32_t>(sizeof(T));

  // Input strides in elements (reverse partial product of the input shape).
  int32_t in_stride[kTransposeMaxDimensions];
  in_stride[dims - 1] = 1;
  for (int i = dims - 2; i >= 0; --i) {
    in_stride[i] = in_stride[i + 1] * in_dims[i + 1];
  }

  int32_t total = 1;
  for (int d = 0; d < dims; ++d) total *= out_dims[d];

  if (total > 0) {
    const uintptr_t bytes = static_cast<uintptr_t>(total) * esize;
    const int pad = kHwDims - dims;

    // Burst mode eligibility (see the comment at the top of this file).
    int32_t fast_r = 1;
    int32_t fast_k = 0;
    bool fast = (esize == 1) && ((total & 3) == 0) &&
                ((reinterpret_cast<uintptr_t>(output_data) & 3) == 0) &&
                (((reinterpret_cast<uintptr_t>(input_data) & 3) + bytes) <= 16384);
    if (fast) {
      fast = false;
      for (int h = kHwDims - 1; h >= 0; --h) {
        const int d = h - pad;
        fast_r *= (d < 0) ? 1 : out_dims[d];
        ++fast_k;
        if ((fast_r & 3) == 0) {
          fast = (fast_r <= 4096);
          break;
        }
        if (fast_r > 4096) break;
      }
    }

    CacheClean(input_data, bytes);
    if (fast) {
      // The NPU overwrites every output byte: only lines shared with
      // neighbouring data must be written back first.
      const uintptr_t o = reinterpret_cast<uintptr_t>(output_data);
      if (o & 31) cbo_clean(output_data);
      if ((o + bytes) & 31) cbo_clean(reinterpret_cast<void*>(o + bytes - 1));
    } else {
      CacheClean(output_data, bytes);
      CacheInvalidate(output_data, bytes);
    }

    cfu_raw_op_hw(6, 0, reinterpret_cast<uintptr_t>(input_data),
                  reinterpret_cast<uintptr_t>(output_data));
    cfu_raw_op_hw(6, 1, esize, 0);
    for (int h = 0; h < kHwDims; ++h) {
      const int d = h - pad;
      if (d < 0) {
        cfu_raw_op_hw(6, 2, h, 1);
        cfu_raw_op_hw(6, 3, h, 0);
      } else {
        int32_t delta = in_stride[params.perm[d]] * esize;
        for (int e = d + 1; e < dims; ++e) {
          delta -= (out_dims[e] - 1) * in_stride[params.perm[e]] * esize;
        }
        cfu_raw_op_hw(6, 2, h, out_dims[d]);
        cfu_raw_op_hw(6, 3, h, delta);
      }
    }
    if (fast) {
      cfu_raw_op_hw(6, 5, static_cast<uint32_t>(total),
                    (static_cast<uint32_t>(fast_k) << 16) |
                        static_cast<uint32_t>(fast_r));
    }
    if (fast) {
      // Start without waiting; the output lines are invalidated while the NPU
      // runs (the CPU does not touch the output range meanwhile), then wait.
      cfu_raw_op_hw(6, 6, 0, 0);
      CacheInvalidate(output_data, bytes);
      cfu_raw_op_hw(6, 7, 0, 0);
    } else {
      cfu_raw_op_hw(6, 4, 0, 0);
      CacheInvalidate(output_data, bytes);
    }
  }

  // record cycles
  // TIMING END AND STATISTICS - DO NOT MODIFY OR MOVE.
  // --------------------------------------------------
  perf_result.add_start(1);
  perf_result.add_result(1, perf_get_mcycle64() - start);
  // --------------------------------------------------
}

}  // namespace reference_ops
}  // namespace tflite

#endif  // TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_TRANSPOSE_H_
