#ifndef PLATFORM_SW_APP_MODEL_IO_H_
#define PLATFORM_SW_APP_MODEL_IO_H_

#include <stddef.h>

#include "tensorflow/lite/c/common.h"

void model_io_print_profile(void);
size_t model_io_sample_count(void);
void model_io_prepare_input(TfLiteTensor* input, size_t sample_index);
void model_io_verify_output(const TfLiteTensor* output, size_t sample_index);

#endif  // PLATFORM_SW_APP_MODEL_IO_H_
