#include "model_profile.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "platform_config.h"
#include "perf.h"

namespace {

void clear_input(TfLiteTensor* input) {
  memset(input->data.raw, 0, input->bytes);
}

void mobileViT_xxs_input(TfLiteTensor* input, size_t sample_index) {
  if (input == 0) {
    return;
  }
  clear_input(input);
  perf_result.clear_results();
}

void mobileViT_xxs_output(const TfLiteTensor* output, size_t sample_index) {
  printf("Output (%d bytes):\n", (unsigned)output->bytes);
  for(int i = 0; i < output->bytes; i++){
    printf("%02d: %d\n", i, (output->data.int8)[i]);
  }
  printf("\n");
  perf_result.print_results();
}

}  // namespace

const ModelProfile* model_profile_get(void) {
  static const ModelProfile kProfile = {
      "mobileVit_xxs",
      "zero input",
      "Print Output Value",
      mobileViT_xxs_input,
      mobileViT_xxs_output,
      0,
      0,
      0,
      0,
      0,    
      1,
  };
  return &kProfile;
}
