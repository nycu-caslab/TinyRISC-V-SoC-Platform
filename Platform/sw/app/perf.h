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

#define PERF_RESULT_MAX 10
class PerfResult {
    uint64_t results[PERF_RESULT_MAX];
    int32_t starts[PERF_RESULT_MAX];
public:
    PerfResult();
    void add_result(int idx, uint64_t cycles);
    void add_start(int idx);
    void print_results(void);
    void clear_results(void);
    void print_cycles(uint64_t cycles, int width);
};

extern PerfResult perf_result;

#endif  // PLATFORM_SW_APP_PERF_H_
