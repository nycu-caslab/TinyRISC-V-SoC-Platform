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


PerfResult perf_result;

PerfResult::PerfResult(){clear_results();}

void PerfResult::add_start(int idx){
    if (idx < 0 || idx >= PERF_RESULT_MAX) {
        return;
    }

    starts[idx]++;
}

void PerfResult::add_result(int idx, uint64_t cycles){
    if (idx < 0 || idx >= PERF_RESULT_MAX) {
        return;
    }
    results[idx] += cycles;
}

void PerfResult::print_cycles(uint64_t cycles, int width) {
    char buf[32];
    if (cycles > 4294967295ULL) {
        snprintf(buf, sizeof(buf), "%u%09u", 
                 (uint32_t)(cycles / 1000000000ULL),
                 (uint32_t)(cycles % 1000000000ULL));
    } else {
        snprintf(buf, sizeof(buf), "%u", (uint32_t)cycles);
    }
    // Print formatted string right-aligned within target width
    printf("%*s", width, buf);
}

void PerfResult::print_results(void) {
    printf("==============================================\n");
    printf(" Counter |       Total | Starts |   Average   \n");
    printf("---------+-------------+--------+-------------\n");

    for (int i = 0; i < PERF_RESULT_MAX; ++i) {
        if (starts[i] == 0) {
            printf("    %d    |           0 |      0 |         n/a\n", i);
            continue;
        }
        
        uint64_t average = results[i] / starts[i];
        
        printf("    %d    | ", i);
        print_cycles(results[i], 11);         // Total column (width 11)
        printf(" | %6d | ", starts[i]);
        print_cycles(average, 11);            // Average column (width 11)
        putchar('\n');
    }
    
    printf("==============================================\n");
}

void PerfResult::clear_results(void){
    for (int i = 0; i < PERF_RESULT_MAX; ++i) {
        results[i] = 0;
        starts[i] = 0;
    }
}
