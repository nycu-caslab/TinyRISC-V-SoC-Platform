#include "model_io.h"

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include "model_profile.h"
#include "platform_config.h"

namespace {

int abs_int(int value) {
  return value < 0 ? -value : value;
}

const ModelProfile* active_profile(void) {
  static const ModelProfile kFallbackProfile = {
      "fallback",
      "zeros",
      "skip",
      0,
      0,
      0,
      0,
      0,
      0,
      MODEL_TOLERANCE,
      1,
  };
  const ModelProfile* profile = model_profile_get();
  return profile == 0 ? &kFallbackProfile : profile;
}

}  // namespace

void model_io_print_profile(void) {
  const ModelProfile* profile = active_profile();
  printf("Profile: %s\n", profile->name);
  printf("Input profile: %s\n", profile->input_name);
  printf("Output profile: %s, tolerance=%d\n", profile->output_name,
         profile->tolerance);
  printf("Samples: %u\n", (unsigned)model_io_sample_count());
}

size_t model_io_sample_count(void) {
  const ModelProfile* profile = active_profile();
  return profile->sample_count == 0 ? 1 : profile->sample_count;
}

void model_io_prepare_input(TfLiteTensor* input, size_t sample_index) {
  const ModelProfile* profile = active_profile();
  if (input == 0) {
    puts("Input tensor is not available.");
    return;
  }
  if (profile->prepare_input != 0) {
    profile->prepare_input(input, sample_index);
    return;
  }

  if (profile->input_data != 0 && profile->input_bytes == input->bytes) {
    memcpy(input->data.int8, profile->input_data, input->bytes);
    printf("Input: using fixture data (%u bytes).\n", (unsigned)input->bytes);
  } else {
    memset(input->data.int8, 0, input->bytes);
    if (profile->input_data == 0) {
      printf("Input: no fixture for profile; using zeros (%u bytes).\n",
             (unsigned)input->bytes);
    } else {
      printf("Input: fixture is %u bytes, tensor is %u bytes; using zeros.\n",
             (unsigned)profile->input_bytes, (unsigned)input->bytes);
    }
  }
}

void model_io_verify_output(const TfLiteTensor* output, size_t sample_index) {
  const ModelProfile* profile = active_profile();
  if (output == 0) {
    puts("Output tensor is not available.");
    return;
  }
  if (profile->verify_output != 0) {
    profile->verify_output(output, sample_index);
    return;
  }

  if (profile->expected_output == 0) {
    puts("Output: no expected output for profile; verification skipped.");
    return;
  }

  if (profile->expected_output_bytes != output->bytes) {
    printf("Output: fixture is %u bytes, tensor is %u bytes; verification skipped.\n",
           (unsigned)profile->expected_output_bytes, (unsigned)output->bytes);
    return;
  }

  int error_count = 0;
  for (size_t i = 0; i < output->bytes; ++i) {
    int8_t actual = output->data.int8[i];
    int8_t expected = profile->expected_output[i];
    int diff = abs_int((int)actual - (int)expected);
    printf("Idx %u: HW=%d, Golden=%d\n", (unsigned)i, actual, expected);
    if (diff > profile->tolerance) {
      ++error_count;
    }
  }

  if (error_count == 0) {
    printf("[Status] ALL PASS (diff <= %d accepted).\n", profile->tolerance);
  } else {
    printf("[Status] FAIL with %d errors.\n", error_count);
  }
}
