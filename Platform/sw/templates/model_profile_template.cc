#include "model_profile.h"

#include "platform_config.h"

namespace {

const int8_t kInputData[] = {
    0,
};

const int8_t kExpectedOutput[] = {
    0,
};

}  // namespace

const ModelProfile* model_profile_get(void) {
  static const ModelProfile kProfile = {
      "template",
      "template input",
      "template output",
      0,  // Set to a custom prepare_input function if static data is not enough.
      0,  // Set to a custom verify_output function if static output is not enough.
      kInputData,
      sizeof(kInputData),
      kExpectedOutput,
      sizeof(kExpectedOutput),
      MODEL_TOLERANCE,
      1,  // Number of samples to run per invocation.
  };
  return &kProfile;
}
