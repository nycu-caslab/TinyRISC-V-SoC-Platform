#include <stdint.h>
#include <stdio.h>

#include "cfu.h"
#include "perf.h"

void my_extension_test(void) {
  const uint32_t a = 1;
  const uint32_t b = 2;
  uint64_t start = perf_get_mcycle64();
  uint32_t result = cfu_op0(CFU_FUNCT7_SCALAR_COMPUTE, a, b);
  uint64_t cycles = perf_get_mcycle64() - start;

  printf("my_extension_test result=%u cycles=", (unsigned)result);
  perf_print_cycles(cycles);
  putchar('\n');
}
