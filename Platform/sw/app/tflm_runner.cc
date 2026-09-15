#include "tflm_runner.h"

#include <stdint.h>
#include <stdio.h>

#include "model_data.h"
#include "model_io.h"
#include "perf.h"
#include "platform_config.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "tflm_ops.h"

#ifndef TENSOR_ARENA_SIZE
#define TENSOR_ARENA_SIZE PLATFORM_DEFAULT_TENSOR_ARENA_SIZE
#endif

#ifndef MODEL_NAME
#define MODEL_NAME "unknown"
#endif

namespace {

alignas(16) uint8_t tensor_arena[TENSOR_ARENA_SIZE];

void print_duration(uint64_t cycles) {
  printf("Cycles: ");
  perf_print_cycles(cycles);
  putchar('\n');
  perf_print_time_ms(cycles);
}

}  // namespace

void tflm_run_inference(void) {
  printf("\n=== TFLM Functional Verification ===\n");
  printf("Model: %s (%d bytes)\n", MODEL_NAME, g_model_len);
  printf("Tensor arena: %u bytes\n", (unsigned)sizeof(tensor_arena));
  model_io_print_profile();

  const tflite::Model* model = tflite::GetModel(g_model);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    printf("Model schema mismatch: got %d, expected %d\n", model->version(),
           TFLITE_SCHEMA_VERSION);
    return;
  }

  ProjectOpResolver resolver;
  tflm_register_project_ops(&resolver);

  tflite::MicroInterpreter interpreter(model, resolver, tensor_arena,
                                       sizeof(tensor_arena));
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    printf("AllocateTensors failed.\n");
    return;
  }

  TfLiteTensor* input = interpreter.input(0);
  TfLiteTensor* output = interpreter.output(0);
  if (input == 0 || output == 0) {
    printf("Model tensors are not available.\n");
    return;
  }

  const size_t sample_count = model_io_sample_count();
  uint64_t total_cycles = 0;
  for (size_t sample_index = 0; sample_index < sample_count; ++sample_index) {
    printf("\n--- Sample %u/%u ---\n", (unsigned)(sample_index + 1),
           (unsigned)sample_count);
    model_io_prepare_input(input, sample_index);

    printf("Running inference...\n");
    uint64_t start_cycles = perf_get_mcycle64();
    TfLiteStatus status = interpreter.Invoke();
    uint64_t cycles = perf_get_mcycle64() - start_cycles;
    total_cycles += cycles;

    if (status != kTfLiteOk) {
      printf("Invoke failed.\n");
      print_duration(cycles);
      return;
    }

    printf("Inference complete.\n");
    model_io_verify_output(output, sample_index);
    print_duration(cycles);
  }

  if (sample_count > 1) {
    printf("\nTotal for %u samples:\n", (unsigned)sample_count);
    print_duration(total_cycles);
  }
}
