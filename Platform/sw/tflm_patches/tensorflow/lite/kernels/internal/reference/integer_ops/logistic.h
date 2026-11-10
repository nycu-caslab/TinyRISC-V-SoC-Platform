/* Copyright 2019 The TensorFlow Authors. All Rights Reserved.

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
#ifndef TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_LOGISTIC_H_
#define TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_LOGISTIC_H_

#include <algorithm>
#include <limits>

#include "tensorflow/lite/kernels/internal/common.h"
#include "perf.h"
#include "cfu.h"

namespace tflite {
namespace reference_integer_ops {

inline void Logistic(int32_t input_zero_point, int32_t input_range_radius,
                     int32_t input_multiplier, int32_t input_left_shift,
                     int32_t input_size, const int8_t* input_data,
                     int8_t* output_data) {
  
  // perf result
  // TIMING START - DO NOT MODIFY OR MOVE.
  // --------------------------------------------------
  uint64_t start = perf_get_mcycle64();
  // --------------------------------------------------

  // ================= DESIGN REGION BEGIN =================
  // int8 Logistic on the NPU (CUSTOM-0, funct3 = 5):
  //   funct7 0: rs1 = input zero point, rs2 = input range radius
  //   funct7 1: rs1 = input multiplier, rs2 = input left shift; the NPU
  //             builds the 256-entry int8 table for this call (the
  //             saturation branch, MultiplyByQuantizedMultiplier and the
  //             gemmlowp sigmoid are evaluated in hardware per table entry)
  //   funct7 2: rs1 = 4 packed int8 inputs, rd = 4 packed int8 outputs
  cfu_raw_op_hw(5, 0, input_zero_point, input_range_radius);
  cfu_raw_op_hw(5, 1, input_multiplier, input_left_shift);

  int i = 0;
  // Head: single elements until the input and output are word aligned.
  while (i < input_size && ((reinterpret_cast<uintptr_t>(input_data + i) |
                             reinterpret_cast<uintptr_t>(output_data + i)) &
                            3u)) {
    const uint32_t r = cfu_raw_op_hw(5, 2, static_cast<uint32_t>(
                                               static_cast<uint8_t>(input_data[i])),
                                     0);
    output_data[i] = static_cast<int8_t>(r & 0xff);
    ++i;
    if (((reinterpret_cast<uintptr_t>(input_data + i) ^
          reinterpret_cast<uintptr_t>(output_data + i)) & 3u) == 0)
      continue;
    // Different alignments: no common aligned point; fall through to tail.
    break;
  }
  const uint32_t* in_w = reinterpret_cast<const uint32_t*>(input_data + i);
  uint32_t* out_w = reinterpret_cast<uint32_t*>(output_data + i);
  if (((reinterpret_cast<uintptr_t>(input_data + i) |
        reinterpret_cast<uintptr_t>(output_data + i)) & 3u) == 0) {
    for (; i + 4 <= input_size; i += 4) {
      *out_w++ = cfu_raw_op_hw(5, 2, *in_w++, 0);
    }
  }
  // Tail (and misaligned fallback): one element per call, lane 0 only.
  for (; i < input_size; ++i) {
    const uint32_t r = cfu_raw_op_hw(5, 2, static_cast<uint32_t>(
                                               static_cast<uint8_t>(input_data[i])),
                                     0);
    output_data[i] = static_cast<int8_t>(r & 0xff);
  }
  // ================== DESIGN REGION END ==================

  // record cycles
  // TIMING END AND STATISTICS - DO NOT MODIFY OR MOVE.
  // --------------------------------------------------
  perf_result.add_start(0);
  perf_result.add_result(0, perf_get_mcycle64() - start);
  // --------------------------------------------------
}

inline void Logistic(int32_t input_multiplier, int32_t input_left_shift,
                     int32_t input_size, const int16_t* ptr_input_data,
                     int16_t* ptr_output_data) {
  // We use the LUT for sigmoid and take into account, that
  // tanh(x) = 2*sigmoid(2*x) - 1

  // We scale by 3/4 to expand range [-8,8]->[-10.7,10.7].
  // In case of general parameter scale, multiplier 3 is taken into account
  // in TanhPrepare function and it is included in
  // input_multiplier already.

  TFLITE_DCHECK_GE(input_left_shift, 0);
  if (input_multiplier == 0) {  // power of two case
    input_multiplier = 3 << input_left_shift;
    input_left_shift = 0;
  }

  int32_t round = (input_left_shift > 0) ? 1 << (input_left_shift - 1) : 0;

  for (int i = 0; i < input_size; ++i, ptr_input_data++, ptr_output_data++) {
    int32_t input_data =
        ((*ptr_input_data) * input_multiplier + round) >> input_left_shift;

    // We do interpolation on unsigned values.
    uint32_t abs_input_data = abs(input_data);

    // We divide by 2 power of 9, because
    // we need to divide by 2 in power of 7 for
    // the input conversion + 1/4 from the scale above.

    // Define uh as uint32_t type not to make this function overflow.
    uint32_t uh = abs_input_data >> 9;
    uint32_t result;

    if (uh >= 255) {
      // Saturate to maximum.
      result = 0x7FFF << 10;
    } else {
      uint32_t ua = sigmoid_table_uint16[uh];
      uint32_t ub = sigmoid_table_uint16[uh + 1];
      uint32_t ut = abs_input_data & 0x1ff;
      // Interpolation is done using the fractional bit.
      result = (ua << 9) + ut * (ub - ua);
    }

    result = (input_data >= 0) ? (result + (1 << 9))
                               : ((1 << (16 + 9)) - result + (1 << 9) - 1);

    // Back to 16-bit.
    result >>= 10;

    *ptr_output_data = result;
  }
}

}  // namespace reference_integer_ops
}  // namespace tflite

#endif  // TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_LOGISTIC_H_
