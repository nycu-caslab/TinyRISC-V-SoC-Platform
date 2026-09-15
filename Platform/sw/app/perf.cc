#include "perf.h"

#include <stdio.h>

#include "menu.h"
#include "platform_config.h"

void perf_print_cycles(uint64_t cycles) {
  if (cycles > 4294967295ULL) {
    printf("%u%09u", (uint32_t)(cycles / 1000000000ULL),
           (uint32_t)(cycles % 1000000000ULL));
  } else {
    printf("%u", (uint32_t)cycles);
  }
}

void perf_print_now(void) {
  printf("mcycle: ");
  perf_print_cycles(perf_get_mcycle64());
  putchar('\n');
}

uint32_t perf_cycles_to_ms(uint64_t cycles) {
  return (uint32_t)((cycles * 1000ULL) / PLATFORM_CLOCK_HZ);
}

void perf_print_time_ms(uint64_t cycles) {
  printf("Time (%u Hz): %u ms\n", (unsigned)PLATFORM_CLOCK_HZ,
         (unsigned)perf_cycles_to_ms(cycles));
}

namespace {

void do_show_mcycle(void) { perf_print_now(); }

void do_measure_nops(void) {
  const uint32_t iterations = 1000000;
  uint64_t start = perf_get_mcycle64();
  for (uint32_t i = 0; i < iterations; ++i) {
    __asm__ volatile("nop");
  }
  uint64_t elapsed = perf_get_mcycle64() - start;

  printf("%u nop loop cycles: ", (unsigned)iterations);
  perf_print_cycles(elapsed);
  putchar('\n');
}

const MenuItem kPerfItems[] = {
    MENU_ITEM('m', "show mcycle", do_show_mcycle),
    MENU_ITEM('n', "measure 1M nop loop", do_measure_nops),
    MENU_END,
};

const Menu kPerfMenu = {
    "Performance Counter Tests",
    "perf",
    kPerfItems,
};

}  // namespace

void perf_test_menu(void) { menu_run(&kPerfMenu); }
