#include "tflm_ops.h"

void tflm_register_project_ops(ProjectOpResolver* resolver) {
  resolver->AddAveragePool2D();
  resolver->AddConv2D();
  resolver->AddDepthwiseConv2D();
  resolver->AddFullyConnected();
  resolver->AddMaxPool2D();
  resolver->AddRelu();
  resolver->AddRelu6();
  resolver->AddReshape();
  resolver->AddSoftmax();
}
