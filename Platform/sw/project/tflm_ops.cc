#include "tflm_ops.h"
#include "tensorflow/lite/micro/kernels/micro_ops.h"

#ifndef TFLM_SOFTWARE_CONV
#include "depthwise_conv_int8_channel_blocked.h"
#endif

// Lab 4 resolver list (27 ops) from the course package. The only local change
// is DEPTHWISE_CONV_2D: the Lab 2 channel-blocked int8 kernel stays selected
// unless TFLM_SOFTWARE_CONV is set, matching the existing Conv mode switch.
void tflm_register_project_ops(ProjectOpResolver* resolver) {
  resolver->AddAveragePool2D();
  resolver->AddConv2D();
#ifdef TFLM_SOFTWARE_CONV
  resolver->AddDepthwiseConv2D();
#else
  // int8 x int8: project/depthwise_conv_int8_channel_blocked.cc; other types
  // fall back to the upstream kernel inside the registration.
  resolver->AddDepthwiseConv2D(
      tflite::Register_DEPTHWISE_CONV_2D_INT8_CHANNEL_BLOCKED());
#endif
  resolver->AddFullyConnected();
  resolver->AddMaxPool2D();
  resolver->AddRelu();
  resolver->AddRelu6();
  resolver->AddReshape();
  resolver->AddSoftmax();
  resolver->AddAudio_Spectrogram();
  resolver->AddQuantize();
  resolver->AddDequantize();
  resolver->AddMFCC();
  resolver->AddMul();
  resolver->AddLogistic();
  resolver->AddAdd();
  resolver->AddSub();
  resolver->AddMean();
  resolver->AddTranspose();
  resolver->AddConcatenation();
  resolver->AddPad();
  resolver->AddStridedSlice();
  resolver->AddSlice();
  resolver->AddDiv();
  resolver->AddSqrt();
  resolver->AddRsqrt();
  resolver->AddBatchMatMul();
}
