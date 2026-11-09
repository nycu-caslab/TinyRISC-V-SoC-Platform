#include <stdio.h>
#include <stdint.h>

#include "tensorflow/lite/c/builtin_op_data.h"
#include "tensorflow/lite/c/common.h"
#include "tensorflow/lite/micro/kernels/kernel_runner.h"
#include "tensorflow/lite/micro/test_helpers.h"

// Our own failure flag (replaces micro_test::did_test_fail).
static bool g_logistic_test_failed = false;

#define LOGISTIC_EXPECT_NEAR_INT8(x, y, epsilon)                              \
  do {                                                                        \
    int8_t vx = (x);                                                          \
    int8_t vy = (y);                                                          \
    int8_t delta = ((vx) > (vy)) ? ((vx) - (vy)) : ((vy) - (vx));             \
    if (vx != vy && delta > epsilon) {                                        \
      printf(#x " (%d) near " #y " (%d) failed at %s:%d\n",                   \
             vx, vy, __FILE__, __LINE__);                                     \
      g_logistic_test_failed = true;                                          \
    }                                                                         \
  } while (false)

#define LOGISTIC_EXPECT_EQ(x, y)                                              \
  do {                                                                        \
    if ((x) != (y)) {                                                         \
      printf(#x " == " #y " failed at %s:%d\n", __FILE__, __LINE__);          \
      g_logistic_test_failed = true;                                          \
    }                                                                         \
  } while (false)

namespace tflite {
namespace testing {
namespace {

// The Logistic kernel assumes an output in the range [0, 1.0], leading to these
// quantization parameters.
const float quantized_output_scale_int8 = 1.0 / 255.0;
const int quantized_output_zero_point_int8 = -128;

const int flat_size_around_zero = 11;
int shape_around_zero[] = {2, 1, 11};
const float input_data_around_zero[] = {
    0, 0.005, 0.01, 0.02, 0.05, 0.1, -0.005, -0.01, -0.02, -0.05, -0.1
};
const float golden_around_zero[] = {
    0.50000000, 0.50125000, 0.50249998, 0.50499983, 0.51249740, 0.52497919, 0.49875000, 0.49750002, 0.49500017, 0.48750260, 0.47502081
};

const int flat_size_narrow_range = 10;
int shape_narrow_range[] = {2, 2, 5};
const float input_data_narrow_range[] = {
    0.15, 0.2, 0.3, 0.4, 0.5, -0.15, -0.2, -0.3, -0.4, -0.5
};
const float golden_narrow_range[] = {
    0.53742985, 0.54983400, 0.57444252, 0.59868766, 0.62245933, 0.46257015, 0.45016600, 0.42555748, 0.40131234, 0.37754067
};

const int flat_size_basic = 10;
int shape_basic[] = {2, 2, 5};
const float input_data_basic[] = {
    0.25, 0.45, 0.65, 0.85, 1, -0.25, -0.45, -0.65, -0.85, -1
};
const float golden_basic[] = {
    0.56217650, 0.61063923, 0.65701046, 0.70056714, 0.73105858, 0.43782350, 0.38936077, 0.34298954, 0.29943286, 0.26894142
};

const int flat_size_wide_range = 10;
int shape_wide_range[] = {2, 2, 5};
const float input_data_wide_range[] = {
    0.32, 0.52, 0.92, 1.02, 1.22, -0.32, -0.52, -0.92, -1.05, -1.22
};
const float golden_wide_range[] = {
    0.57932425, 0.62714777, 0.71504211, 0.73497260, 0.77206355, 0.42067575, 0.37285223, 0.28495789, 0.25922510, 0.22793645
};

template <typename T>
void ValidateLogisticGoldens(TfLiteTensor* tensors, const int tensor_count,
                             T* output_data, const T* golden,
                             int output_dims_count, float tolerance) {
  int inputs_array_data[] = {1, 0};
  TfLiteIntArray* inputs_array = IntArrayFromInts(inputs_array_data);
  int outputs_array_data[] = {1, 1};
  TfLiteIntArray* outputs_array = IntArrayFromInts(outputs_array_data);

  const TfLiteRegistration registration = tflite::Register_LOGISTIC();
  micro::KernelRunner runner(registration, tensors, tensor_count, inputs_array,
                             outputs_array, nullptr);

  LOGISTIC_EXPECT_EQ(kTfLiteOk, runner.InitAndPrepare());
  LOGISTIC_EXPECT_EQ(kTfLiteOk, runner.Invoke());

  for (int i = 0; i < output_dims_count; ++i) {
    LOGISTIC_EXPECT_NEAR_INT8(golden[i], output_data[i], tolerance);
  }
}

template <typename T>
void TestLogisticQuantized(int* input_dims_data, const float* input_data,
                           T* input_quantized, const float input_scale,
                           const int input_zero_point, const float* golden,
                           T* golden_quantized, int* output_dims_data,
                           const float output_scale,
                           const int output_zero_point, T* output_data,
                           float tolerance) {
  TfLiteIntArray* input_dims = IntArrayFromInts(input_dims_data);
  TfLiteIntArray* output_dims = IntArrayFromInts(output_dims_data);
  const int output_elements_count = ElementCount(*output_dims);

  constexpr int inputs_size = 1;
  constexpr int outputs_size = 1;
  constexpr int tensors_size = inputs_size + outputs_size;
  TfLiteTensor tensors[tensors_size] = {
      CreateQuantizedTensor(input_data, input_quantized, input_dims,
                            input_scale, input_zero_point),
      CreateQuantizedTensor(output_data, output_dims, output_scale,
                            output_zero_point),
  };

  tflite::Quantize(golden, golden_quantized, output_elements_count,
                   output_scale, output_zero_point);
  ValidateLogisticGoldens(tensors, tensors_size, output_data, golden_quantized,
                          output_elements_count, tolerance);
}

// Runs one int8 test case and returns true if it passed.
// kSize must equal the flat size of the test data.
template <int kSize>
bool RunInt8Case(const char* name, int* shape, const float* input_data,
                 const float* golden, float input_scale,
                 int input_zero_point, float tolerance) {
  int8_t input_quantized[kSize];
  int8_t golden_quantized[kSize];
  int8_t output_data[kSize];

  g_logistic_test_failed = false;

  TestLogisticQuantized<int8_t>(
      shape, input_data, input_quantized, input_scale, input_zero_point,
      golden, golden_quantized, shape, quantized_output_scale_int8,
      quantized_output_zero_point_int8, output_data, tolerance);

  const bool passed = !g_logistic_test_failed;
  printf("[%s] %s\n", passed ? "PASS" : "FAIL", name);
  return passed;
}

}  // namespace
}  // namespace testing
}  // namespace tflite

// Runs all logistic (sigmoid) int8 tests and prints the results.
void run_logistic_test() {
  using namespace tflite::testing;

  int failed = 0;

  if (!RunInt8Case<flat_size_around_zero>(
          "LogisticQuantizedInt8AroundZeroShouldMatchGolden",
          shape_around_zero, input_data_around_zero, golden_around_zero,
          /*input_scale=*/0.005f, /*input_zero_point=*/0, /*tolerance=*/1)) {
    ++failed;
  }

  if (!RunInt8Case<flat_size_narrow_range>(
          "LogisticQuantizedInt8NarrowRangeShouldMatchGolden",
          shape_narrow_range, input_data_narrow_range, golden_narrow_range,
          0.01f, 0, 1)) {
    ++failed;
  }

  if (!RunInt8Case<flat_size_basic>(
          "LogisticQuantizedInt8BasicShouldMatchGolden",
          shape_basic, input_data_basic, golden_basic,
          0.01f, 0, 1)) {
    ++failed;
  }

  if (!RunInt8Case<flat_size_wide_range>(
          "LogisticQuantizedInt8WideRangeShouldMatchGolden",
          shape_wide_range, input_data_wide_range, golden_wide_range,
          0.02f, 0, 1)) {
    ++failed;
  }

  printf("Logistic tests: %d/4 passed\n", 4 - failed);
}