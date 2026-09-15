/* Copyright 2018 The TensorFlow Authors. All Rights Reserved.

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
#include "tensorflow/lite/kernels/internal/mfcc.h"

#include <stddef.h>
#include <stdint.h>


#include "flatbuffers/flexbuffers.h"  // from @flatbuffers
#include "tensorflow/lite/c/common.h"
#include "tensorflow/lite/kernels/internal/compatibility.h"
#include "tensorflow/lite/kernels/internal/mfcc_dct.h"
#include "tensorflow/lite/kernels/internal/mfcc_mel_filterbank.h"
//#include "tensorflow/lite/kernels/internal/optimized/optimized_ops.h"
//#include "tensorflow/lite/kernels/internal/reference/reference_ops.h"
//#include "tensorflow/lite/kernels/internal/tensor.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/kernels/kernel_util.h"
#include "tensorflow/lite/micro/kernels/kernel_util.h"
#include "tensorflow/lite/micro/memory_helpers.h"

//#include <embARC_debug.h>
#define DBG_APP_PRINT_LEVEL 0


#include "stdio.h"
#include <cstring>

float mfcc_input[513]; //save stack memory
float mfcc_output[30];

namespace tflite {
namespace ops {
namespace micro {
namespace mfcc {

enum KernelType {
  kReference,
};

typedef struct {
  internal::Mfcc mfcc;
} TfLiteMfccParams;

constexpr int kInputTensorWav = 0;
constexpr int kInputTensorRate = 1;
constexpr int kOutputTensor = 0;

/*
char* uint32_to_dec_cstring(char buf[11], uint32_t n) {
  for (int i{9}; i >= 0; --i) {
    // printf("iterating\n");
    buf[i] = '0' + n % 10;
    n /= 10;
  }
  buf[10] = '\0';
  return buf;
}
*/

/*
char* int32_to_dec_cstring(char buf[11], int32_t n) {
  bool is_n = n < 0;
  if(is_n) n = n * -1;
  for (int i{9}; i >= 0; --i) {
    // printf("iterating\n");
    buf[i] = '0' + n % 10;
    n /= 10;
  }
  buf[10] = '\0';
  if(is_n) buf[0] = '-';
  return buf;
}
*/

/*
  fflush(stdout);
  char num[11];
  int32_to_dec_cstring(num, (int)(mfcc_input[i]*100000));
  strcat(num," ");
  fwrite(num, sizeof(char), sizeof(num), stderr);

  fflush(stdout);
*/
//dbg_printf(DBG_APP_PRINT_LEVEL, "[%s] %s:%d\n", __FILE__, __func__, __LINE__);


void* Init(TfLiteContext* context, const char* buffer, size_t length) {
  
  // map flexbuffer and get custom_data_type
  const uint8_t* buffer_t = reinterpret_cast<const uint8_t*>(buffer);
  const flexbuffers::Map& m = flexbuffers::GetRoot(buffer_t, length).AsMap();

  // allocate
  TFLITE_DCHECK(context->AllocatePersistentBuffer != nullptr);
  void *ptr = context->AllocatePersistentBuffer(context, sizeof(TfLiteMfccParams));

  // assign values
  auto *params = reinterpret_cast<TfLiteMfccParams*>(ptr);
  params->mfcc.set_upper_frequency_limit(m["upper_frequency_limit"].AsInt64());
  params->mfcc.set_lower_frequency_limit(m["lower_frequency_limit"].AsInt64());
  params->mfcc.set_filterbank_channel_count(m["filterbank_channel_count"].AsInt64());
  params->mfcc.set_dct_coefficient_count(m["dct_coefficient_count"].AsInt64());

  return ptr;
}



TfLiteStatus Prepare(TfLiteContext* context, TfLiteNode* node) {

  MicroContext* micro_context = GetMicroContext(context);
  auto* params = reinterpret_cast<TfLiteMfccParams*>(node->user_data);

  TF_LITE_ENSURE_EQ(context, NumInputs(node), 2);
  TF_LITE_ENSURE_EQ(context, NumOutputs(node), 1);

  //const TfLiteTensor* input_wav = GetInput(context, node, kInputTensorWav);
  //const TfLiteTensor* input_rate = GetInput(context, node, kInputTensorRate);
  //TfLiteTensor* output = GetOutput(context, node, kOutputTensor);

  TfLiteTensor* input_wav =
      micro_context->AllocateTempInputTensor(node, kInputTensorWav);
  TF_LITE_ENSURE(context, input_wav != nullptr);
  TfLiteTensor* input_rate =
      micro_context->AllocateTempInputTensor(node, kInputTensorRate);
  TF_LITE_ENSURE(context, input_rate != nullptr);
  TfLiteTensor* output =
      micro_context->AllocateTempOutputTensor(node, kOutputTensor);
  TF_LITE_ENSURE(context, output != nullptr);


  TF_LITE_ENSURE_EQ(context, NumDimensions(input_wav), 3);
  TF_LITE_ENSURE_EQ(context, NumElements(input_rate), 1);

  TF_LITE_ENSURE_TYPES_EQ(context, output->type, kTfLiteFloat32);
  TF_LITE_ENSURE_TYPES_EQ(context, input_wav->type, output->type);
  TF_LITE_ENSURE_TYPES_EQ(context, input_rate->type, kTfLiteInt32);
  
  //const int spectrogram_channels = input_wav->dims->data[2];

  params->mfcc.Initialize(input_wav->dims->data[2], 16000);

  /*
  printf("output->dims->data[0] = %d\n", output->dims->data[0]);
  printf("output->dims->data[1] = %d\n", output->dims->data[1]);
  printf("output->dims->data[2] = %d\n", output->dims->data[2]);
  */
  micro_context->DeallocateTempTfLiteTensor(input_wav);
  micro_context->DeallocateTempTfLiteTensor(input_rate);
  micro_context->DeallocateTempTfLiteTensor(output);
  return kTfLiteOk;
}


// Input is a single squared-magnitude spectrogram frame. The input spectrum
// is converted to linear magnitude and weighted into bands using a
// triangular mel filterbank, and a discrete cosine transform (DCT) of the
// values is taken. Output is populated with the lowest dct_coefficient_count
// of these values.
template <KernelType kernel_type>
TfLiteStatus Eval(TfLiteContext* context, TfLiteNode* node) {

  auto* params = reinterpret_cast<TfLiteMfccParams*>(node->user_data);

  const TfLiteEvalTensor* input_wav = tflite::micro::GetEvalInput(context, node, kInputTensorWav);
  //const TfLiteEvalTensor* input_rate = tflite::micro::GetEvalInput(context, node, kInputTensorRate);
  TfLiteEvalTensor* output = tflite::micro::GetEvalOutput(context, node, kOutputTensor);
  //const int32_t sample_rate = *tflite::micro::GetTensorData<int>(input_rate);

  const int spectrogram_channels = input_wav->dims->data[2];
  const int spectrogram_samples = input_wav->dims->data[1];
  const int audio_channels = input_wav->dims->data[0];
  //internal::Mfcc mfcc;

  //mfcc.set_upper_frequency_limit(params->upper_frequency_limit);
  //mfcc.set_lower_frequency_limit(params->lower_frequency_limit);
  //mfcc.set_filterbank_channel_count(params->filterbank_channel_count);
  //mfcc.set_dct_coefficient_count(params->dct_coefficient_count);
  
  // printf("spectrogram_channels = %d\n", spectrogram_channels); // 513
  // printf("params->dct_coefficient_count = %d\n", params->dct_coefficient_count); // 30
  // printf("audio_channels = %d\n", audio_channels); // 1
  // printf("spectrogram_samples = %d\n", spectrogram_samples); // 49

  //mfcc.Initialize(spectrogram_channels, sample_rate);

  const float* spectrogram_flat = tflite::micro::GetTensorData<float>(input_wav);
  float* output_flat = tflite::micro::GetTensorData<float>(output);
 
  
  for (int audio_channel = 0; audio_channel < audio_channels; ++audio_channel) {
    for (int spectrogram_sample = 0; spectrogram_sample < spectrogram_samples;
         ++spectrogram_sample) { // [0, 48]
      const float* sample_data =
          spectrogram_flat +
          (audio_channel * spectrogram_samples * spectrogram_channels) +
          (spectrogram_sample * spectrogram_channels); 
      
      // std::vector<double> mfcc_input(sample_data, sample_data + spectrogram_channels);
      // std::vector<double> mfcc_output;
      memcpy(mfcc_input, sample_data, spectrogram_channels * sizeof(float));
      /*
      for (int i{0}; i < spectrogram_channels; ++i) 
      {
        mfcc_input[i] = sample_data[i];   
      }
      */
      
      
      params->mfcc.Compute(mfcc_input, spectrogram_channels, mfcc_output);

      //TF_LITE_ENSURE_EQ(context, params->dct_coefficient_count, 30); 
      int dct_coefficient_count = params->mfcc.get_dct_coefficient_count();
      float* output_data = output_flat +
                           (audio_channel * spectrogram_samples *
                            dct_coefficient_count) +
                           (spectrogram_sample * dct_coefficient_count);

      memcpy(output_data, mfcc_output, dct_coefficient_count * sizeof(float));
      /*
      for (int i = 0; i < params->dct_coefficient_count; ++i) {
        output_data[i] = mfcc_output[i];
      }
      */
    }
  }

  return kTfLiteOk;
}

}  // namespace mfcc

TfLiteRegistration* Register_MFCC() {
  static TfLiteRegistration r = {mfcc::Init, 
                                  nullptr,
                                 //mfcc::Free, 
                                 mfcc::Prepare,
                                 mfcc::Eval<mfcc::kReference>};
  return &r;
}

}  // namespace custom
}  // namespace ops
}  // namespace tflite
