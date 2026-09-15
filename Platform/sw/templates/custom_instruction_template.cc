#include <stdint.h>
#include <stdio.h>

#include "cfu.h"
#include "perf.h"

#define MY_ACCEL_FUNCT7_EXAMPLE 6

static uint32_t my_accel_example(uint32_t a, uint32_t b) {
  return cfu_op0(MY_ACCEL_FUNCT7_EXAMPLE, a, b);
}

void my_custom_instruction_perf_test(void) {
  const uint32_t iterations = 1000;
  volatile uint32_t checksum = 0;

  const uint64_t start = perf_get_mcycle64();
  for (uint32_t i = 0; i < iterations; ++i) {
    checksum += my_accel_example(i, i + 1);
  }
  const uint64_t cycles = perf_get_mcycle64() - start;

  printf("my_custom_instruction iterations=%u checksum=%u cycles=",
         (unsigned)iterations, (unsigned)checksum);
  perf_print_cycles(cycles);
  putchar('\n');
}
