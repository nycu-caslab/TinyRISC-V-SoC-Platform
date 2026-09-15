




















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

#include "tensorflow/lite/kernels/internal/spectrogram.h"

#include <assert.h>
#include <math.h>
#include <cstdio>
//#include <string.h> // memset
#include "third_party/fft2d/fft.h"
#include "tensorflow/lite/micro/kernels/kernel_util.h"
#include "tensorflow/lite/micro/memory_helpers.h"
#include "tensorflow/lite/kernels/op_macros.h"
#include "tensorflow/lite/kernels/kernel_util.h"


namespace tflite {
namespace internal {

using std::complex;

/*
namespace {
  
// Returns the default Hann window function for the spectrogram.
void GetPeriodicHann(int window_length, double* window_) {
  // Some platforms don't have M_PI, so define a local constant here.
  const double pi = std::atan(1.0) * 4.0;
 
  //window->resize(window_length);  
  for (int i = 0; i < window_length; ++i) {
    window_[i] = 0.5 - 0.5 * cos((2.0 * pi * i) / window_length);
  }
}

}  // namespace



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

bool Spectrogram::Initialize(int window_length, int step_length, int input_length, int fft_length, int output_frequency_channels) {
  window_length_ = window_length;
  //GetPeriodicHann(window_length_, window_);
  // Some platforms don't have M_PI, so define a local constant here.
  const double pi = std::atan(1.0) * 4.0;
 
  //window->resize(window_length);  
  for (int i = 0; i < window_length_; ++i) {
    window_[i] = 0.5 - 0.5 * cos((2.0 * pi * i) / window_length_);
  }

  if (window_length_ < 2) {
    // LOG(ERROR) << "Window length too short.";
    initialized_ = false;
    return false;
  }

  step_length_ = step_length;
  if (step_length_ < 1) {
    // LOG(ERROR) << "Step length must be positive.";
    initialized_ = false;
    return false;
  }


  //fft_length_ = NextPowerOfTwo(window_length_); // 1024
  // CHECK(fft_length_ >= window_length_);

  // output_frequency_channels_ = 1 + fft_length_ / 2; // 513
  // int half_fft_length = fft_length_ / 2; // 512
  fft_length_ = fft_length;
  output_frequency_channels_ = output_frequency_channels;
  
  // Allocate 2 more than what rdft needs, so we can rationalize the layout.
  //fft_input_output_.assign(fft_length_ + 2, 0.0); // 1026
  //fft_double_working_area_.assign(half_fft_length, 0.0);
  //fft_integer_working_area_.assign(2 + static_cast<int>(sqrt(half_fft_length)),0);
  
  //printf("fft_length = %d\n", fft_length_); // 1024
  //printf("half_fft_length = %d\n", half_fft_length); // 512
  //printf("fft_integer_working_area_ = %d\n", 2 + static_cast<int>(sqrt(half_fft_length))); // 24

  
  // Set flag element to ensure that the working areas are initialized
  // on the first call to cdft.  It's redundant given the assign above,
  // but keep it as a reminder.
  
  // test w & w/o initializing above array with 0, the output is still the same
  //fft_integer_working_area_[0] = 0;
  samples_to_next_step_ = step_length_;
  input_length_ = input_length;
  initialized_ = true;
  return true;
}
/*
template <class InputSample, class OutputSample>
bool Spectrogram::ComputeComplexSpectrogram(
    const InputSample* input,
    std::complex<OutputSample> *output) {
  if (!initialized_) { return false; }

  //output->clear();
  cur_output = 0;
  int input_start = 0;
  fft_integer_working_area_[0] = 0;
  
  while (GetNextWindowOfSamples(input, &input_start)) {
    // DCHECK_EQ(input_queue_.size(), window_length_);
    ProcessCoreFFT();  // Processes input_queue_ to fft_input_output_.
    
    cur_output += 1;
    // Get a reference to the newly added slice to fill in.
    auto* spectrogram_slice = output + cur_output*output_frequency_channels_;

    for (int i = 0; i < output_frequency_channels_; ++i) {
      // This will convert double to float if it needs to.
      spectrogram_slice[i] = complex<OutputSample>(
          fft_input_output_[2 * i], fft_input_output_[2 * i + 1]);
    }
  }
  return true;
}

// Instantiate it four ways:
template bool Spectrogram::ComputeComplexSpectrogram(
    const float* input, 
    std::complex<float>*);
template bool Spectrogram::ComputeComplexSpectrogram(
    const double* input,
    std::complex<float>*);
template bool Spectrogram::ComputeComplexSpectrogram(
    const float* input,
    std::complex<double>*);
template bool Spectrogram::ComputeComplexSpectrogram(
    const double* input,
    std::complex<double>*);
*/
template <class InputSample, class OutputSample>
bool Spectrogram::ComputeSquaredMagnitudeSpectrogram(
    const InputSample* input,
    OutputSample *output){
  if (!initialized_) { return false; }

  //output->clear();
  cur_output = -1;
  int input_start = 0;
  
  while (GetNextWindowOfSamples(input, &input_start)) {
    // DCHECK_EQ(input_queue_.size(), window_length_);
    ProcessCoreFFT();  // Processes input_queue_ to fft_input_output_.
    // Add a new slice vector onto the output, to save new result to.
    //output->resize(output->size() + 1);
    cur_output += 1;
    
    // Get a reference to the newly added slice to fill in.
    //auto& spectrogram_slice = output->back();
    auto* spectrogram_slice = output + cur_output * output_frequency_channels_;

    //spectrogram_slice.resize(output_frequency_channels_);
    
    for (int i = 0; i < output_frequency_channels_; ++i) {
      // Similar to the Complex case, except storing the norm.
      // But the norm function is known to be a performance killer,
      // so do it this way with explicit real and imaginary temps.
      const double re = fft_input_output_[2 * i];
      const double im = fft_input_output_[2 * i + 1];
      // Which finally converts double to float if it needs to.
      spectrogram_slice[i] = re * re + im * im;

    }
  }
  return true;
}

// Instantiate it four ways:
template bool Spectrogram::ComputeSquaredMagnitudeSpectrogram(
    const float* input, float*);
template bool Spectrogram::ComputeSquaredMagnitudeSpectrogram(
    const double* input, float*);
template bool Spectrogram::ComputeSquaredMagnitudeSpectrogram(
    const float* input, double*);
template bool Spectrogram::ComputeSquaredMagnitudeSpectrogram(
    const double* input, double*);

// Return true if a full window of samples is prepared; manage the queue.
template <class InputSample>
bool Spectrogram::GetNextWindowOfSamples(
    const InputSample* input,
    int* input_start) {

  auto* input_it = input + *input_start;
  int input_remaining = input + input_length_ - input_it; //stream_non_stream_change : non stream 16000, stream : 640

  if(input_remaining >= window_length_)
  {
    memcpy(input_queue_, input_it, window_length_ * sizeof(float));
    *input_start += samples_to_next_step_;
    // DCHECK_EQ(window_length_, input_queue_.size());
    samples_to_next_step_ = step_length_;  // Be ready for next time.
    return true;  // Yes, input_queue_ now contains exactly a window-full.
  }
  return false;
  /*
  if(input_remaining < window_length_){
    // Copy in as many samples are left and return false, no full window.
    for(int i = 0; i < input_remaining; i++)
    {
        input_queue_[i] = *(input_it + i);
    }

    *input_start += input_remaining;  // Increases it to input.size().
    samples_to_next_step_ -= input_remaining;
    return false;  // Not enough for a full window.
  } 
  else 
  {
    // Copy just enough into queue to make a new window, then trim the
    // front off the queue to make it window-sized.
    for(int i = 0; i < window_length_; i++)
    {
        input_queue_[i] = input_it[i];
    }
    *input_start += samples_to_next_step_;
    // DCHECK_EQ(window_length_, input_queue_.size());
    samples_to_next_step_ = step_length_;  // Be ready for next time.
    return true;  // Yes, input_queue_ now contains exactly a window-full.
  }
  */
}

void Spectrogram::ProcessCoreFFT() {

  for (int j = 0; j < window_length_; ++j) {
    fft_input_output_[j] = (double)input_queue_[j] * (double)window_[j];
  }
  
  // Zero-pad the rest of the input buffer.
  for (int j = window_length_; j < fft_length_; ++j) {
    fft_input_output_[j] = 0.0;
  }
  
  const int kForwardFFT = 1;  // 1 means forward; -1 reverse.
  // This real FFT is a fair amount faster than using cdft here.
  rdft(fft_length_, kForwardFFT, fft_input_output_, fft_integer_working_area_, fft_double_working_area_);
  
  // Make rdft result look like cdft result;
  // unpack the last real value from the first position's imag slot.
  fft_input_output_[fft_length_] = fft_input_output_[1];
  fft_input_output_[fft_length_ + 1] = 0;
  fft_input_output_[1] = 0;
}

}  // namespace internal
}  // namespace tflite
