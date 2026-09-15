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

#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <cstdio>


#include "flatbuffers/flexbuffers.h"  // from @flatbuffers
#include "tensorflow/lite/c/common.h"
//#include "tensorflow/lite/kernels/internal/optimized/optimized_ops.h"
//#include "tensorflow/lite/kernels/internal/reference/reference_ops.h"
#include "tensorflow/lite/kernels/internal/spectrogram.h"
//#include "tensorflow/lite/kernels/internal/tensor.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/kernels/kernel_util.h"
#include "tensorflow/lite/micro/kernels/kernel_util.h"
#include "tensorflow/lite/micro/memory_helpers.h"
#include "tensorflow/lite/kernels/op_macros.h"



namespace tflite {
namespace ops {
namespace micro {
//namespace custom{
namespace audio_spectrogram {

constexpr int kInputTensor = 0;
constexpr int kOutputTensor = 0;

/*

inline int Log2Floor(uint32_t n) {
  if (n == 0) return -1;
  int log = 0;
  uint32_t value = n;
  for (int i = 4; i >= 0; --i) {
    int shift = (1 << i);
    uint32_t x = value >> shift;
    if (x != 0) {
      value = x;
      log += shift;
    }
  }
  return log;
}

inline int Log2Ceiling(uint32_t n) {
  int floor = Log2Floor(n);
  if (n == (n & ~(n - 1)))  // zero or a power of two
    return floor;
  else
    return floor + 1;
}

inline uint32_t NextPowerOfTwo(uint32_t value) {
  int exponent = Log2Ceiling(value);
  // DCHECK_LT(exponent, std::numeric_limits<uint32>::digits);
  return 1 << exponent;
}
*/

enum KernelType {
  kReference,
};

typedef struct {
  int window_size;
  int stride;
  bool magnitude_squared;
  int output_height;
  int idx_for_spec_output;
  int idx_for_input_channel;
  internal::Spectrogram spectrogram;
} TfLiteAudioSpectrogramParams;



void* Init(TfLiteContext* context, const char* buffer, size_t length) {

  const uint8_t* buffer_t = reinterpret_cast<const uint8_t*>(buffer);
  const flexbuffers::Map& m = flexbuffers::GetRoot(buffer_t, length).AsMap();
  
  // allocate buffer
  TFLITE_DCHECK(context->AllocatePersistentBuffer != nullptr);
  void *ptr = context->AllocatePersistentBuffer(context, sizeof(TfLiteAudioSpectrogramParams));

  // assign custom_op_value
  auto *params = reinterpret_cast<TfLiteAudioSpectrogramParams*>(ptr);
  params->window_size = m["window_size"].AsInt64();
  params->stride = m["stride"].AsInt64();
  params->magnitude_squared = m["magnitude_squared"].AsBool();

  return ptr;
}


TfLiteStatus Prepare(TfLiteContext* context, TfLiteNode* node) {

  MicroContext* micro_context = GetMicroContext(context);
  auto* params = reinterpret_cast<TfLiteAudioSpectrogramParams*>(node->user_data);
  TF_LITE_ENSURE_EQ(context, NumInputs(node), 1);
  TF_LITE_ENSURE_EQ(context, NumOutputs(node), 1);
  //const TfLiteTensor* input = GetInput(context, node, kInputTensor);
  //TfLiteTensor* output = GetOutput(context, node, kOutputTensor);
  TfLiteTensor* input =
      micro_context->AllocateTempInputTensor(node, kInputTensor);
  TF_LITE_ENSURE(context, input != nullptr);
  TfLiteTensor* output =
      micro_context->AllocateTempOutputTensor(node, kOutputTensor);
  TF_LITE_ENSURE(context, output != nullptr);
  TF_LITE_ENSURE_EQ(context, NumDimensions(input), 2);
  TF_LITE_ENSURE_TYPES_EQ(context, output->type, kTfLiteFloat32);
  TF_LITE_ENSURE_TYPES_EQ(context, input->type, output->type);
  

  const int64_t sample_count = input->dims->data[0];
  const int64_t length_minus_window = (sample_count - params->window_size);
  if (length_minus_window < 0) {
    params->output_height = 0;
  } else {
    params->output_height = 1 + (length_minus_window / params->stride);
  }


  // allocate buffer
  TFLITE_DCHECK(context->RequestScratchBufferInArena != nullptr);
  const TfLiteStatus scratch_input_for_channel = context->RequestScratchBufferInArena(
        context, sample_count * sizeof(float), &(params->idx_for_input_channel));
  TF_LITE_ENSURE_OK(context, scratch_input_for_channel);

  //int fft_length = NextPowerOfTwo(params->window_size); // 1024
  //int output_freqency_channels = 1 + fft_length >> 1;
  int fft_length = 1024;
  int output_freqency_channels = 513;
  params->window_size = 640;
  params->stride = 320;
  const TfLiteStatus scratch_spectrogram_output = context->RequestScratchBufferInArena(
        context, output_freqency_channels * params->output_height * sizeof(float), &(params->idx_for_spec_output));
  TF_LITE_ENSURE_OK(context, scratch_spectrogram_output);
  TF_LITE_ENSURE(context, params->spectrogram.Initialize(params->window_size, params->stride, input->dims->data[0], fft_length, output_freqency_channels));
  /*
  printf("output->[0] = %d\n", output->dims->data[0]);
  printf("output->[1] = %d\n", output->dims->data[1]);
  printf("output->[2] = %d\n", output->dims->data[2]);
  */

  micro_context->DeallocateTempTfLiteTensor(input);
  micro_context->DeallocateTempTfLiteTensor(output);
  return kTfLiteOk;
}

template <KernelType kernel_type>
TfLiteStatus Eval(TfLiteContext* context, TfLiteNode* node) {

  auto* params =
      reinterpret_cast<TfLiteAudioSpectrogramParams*>(node->user_data);

  const TfLiteEvalTensor* input =  tflite::micro::GetEvalInput(context, node, kInputTensor);
  TfLiteEvalTensor* output = tflite::micro::GetEvalOutput(context, node, kOutputTensor);

  // get allocate buffer
  TFLITE_DCHECK(context->GetScratchBuffer != nullptr);
  float* spectrogram_output = static_cast<float*>(context->GetScratchBuffer(context, params->idx_for_spec_output));
  float* input_for_channel = static_cast<float*>(context->GetScratchBuffer(context, params->idx_for_input_channel));

  //TF_LITE_ENSURE(context, params->spectrogram.Initialize(params->window_size, params->stride, input->dims->data[0]));

  const int64_t sample_count = input->dims->data[0]; // non stream : 16000 , stream : 640
  const int64_t channel_count = input->dims->data[1]; // 1
  const int64_t output_width = params->spectrogram.output_frequency_channels();

  const float* input_data = tflite::micro::GetTensorData<float>(input);
  float* output_flat = tflite::micro::GetTensorData<float>(output);
  
  //printf("sample_count = %d\n", sample_count);
  //printf("channel count = %d\n", input->dims->data[1]);
  //printf("params->output_height = %d\n", params->output_height); // non stream :Ã£â‚¬â‚¬49 , stream : 1
  //printf("output_width = %d\n", output_width); // 513
  //printf("params->output_height = %d\n", params->output_height); // 49


  //std::vector<float> input_for_channel(sample_count);
  //float* input_for_channel = params->spectrogram.get_input_for_channel_();
  //float* spectrogram_output = params->spectrogram.get_spectrogram_output_();

  for (int64_t channel = 0; channel < channel_count; ++channel) {
    float* output_slice =
        output_flat + (channel * params->output_height * output_width);

    memcpy(input_for_channel, input_data, sample_count * sizeof(float));
    /*
    for (int i = 0; i < sample_count; ++i) {
      input_for_channel[i] = input_data[i * channel_count + channel]; // channel_count = 1, channel = 0
    }
    */
    
    //std::vector<std::vector<float>> spectrogram_output;

    TF_LITE_ENSURE(context,
                   params->spectrogram.ComputeSquaredMagnitudeSpectrogram(
                       input_for_channel, spectrogram_output));
                 
                    
    //TF_LITE_ENSURE_EQ(context, spectrogram_output.size(), params->output_height);
    //TF_LITE_ENSURE(context, spectrogram_output.empty() || (spectrogram_output[0].size() == output_width));
    
    for (int row_index = 0; row_index < params->output_height; ++row_index) {

      const float* spectrogram_row = spectrogram_output + (row_index * output_width);
      float* output_row = output_slice + (row_index * output_width);
      
      memcpy(output_row, spectrogram_row, output_width * sizeof(float));
      /* 
      if (params->magnitude_squared) {
        for (int i = 0; i < output_width; ++i) {
          output_row[i] = spectrogram_row[i];
        }
      } else {
        for (int i = 0; i < output_width; ++i) {
          output_row[i] = sqrtf(spectrogram_row[i]);
        }
      }
      */
    }
  }
  return kTfLiteOk;
}

}  // namespace audio_spectrogram

TfLiteRegistration* Register_AUDIO_SPECTROGRAM() {
  static TfLiteRegistration r = {
      audio_spectrogram::Init, 
      /*free=*/nullptr,
      //audio_spectrogram::Free,
      audio_spectrogram::Prepare,
      audio_spectrogram::Eval<audio_spectrogram::kReference>,
      /*profiling_string=*/nullptr,
      /*builtin_code=*/0,
      /*custom_name=*/nullptr,
      /*version=*/0};
  return &r;
}

//}  // namespace custom
}  // namespace micro
}  // namespace ops
}  // namespace tflite
