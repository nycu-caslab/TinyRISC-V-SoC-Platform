#ifndef PLATFORM_SW_APP_PERF_H_
#define PLATFORM_SW_APP_PERF_H_

#include <stdint.h>

static inline uint32_t perf_get_mcycle(void) {
#if defined(__riscv)
  uint32_t cycles = 0;
  __asm__ volatile("csrr %0, mcycle" : "=r"(cycles));
  return cycles;
#else
  return 0;
#endif
}

static inline uint64_t perf_get_mcycle64(void) {
#if defined(__riscv)
  uint32_t cycles_lo = 0;
  uint32_t cycles_hi = 0;
  uint32_t cycles_hi_check = 0;

  do {
    __asm__ volatile("csrr %0, mcycleh" : "=r"(cycles_hi));
    __asm__ volatile("csrr %0, mcycle" : "=r"(cycles_lo));
    __asm__ volatile("csrr %0, mcycleh" : "=r"(cycles_hi_check));
  } while (cycles_hi != cycles_hi_check);

  return ((uint64_t)cycles_hi << 32) | cycles_lo;
#else
  return 0;
#endif
}

void perf_print_cycles(uint64_t cycles);
uint32_t perf_cycles_to_ms(uint64_t cycles);
void perf_print_time_ms(uint64_t cycles);
void perf_print_now(void);
void perf_test_menu(void);

#endif  // PLATFORM_SW_APP_PERF_H_
