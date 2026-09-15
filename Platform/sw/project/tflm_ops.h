#ifndef PLATFORM_SW_PROJECT_TFLM_OPS_H_
#define PLATFORM_SW_PROJECT_TFLM_OPS_H_

#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"

constexpr int kTflmResolverOpCount = 9;
using ProjectOpResolver = tflite::MicroMutableOpResolver<kTflmResolverOpCount>;

void tflm_register_project_ops(ProjectOpResolver* resolver);

#endif  // PLATFORM_SW_PROJECT_TFLM_OPS_H_
