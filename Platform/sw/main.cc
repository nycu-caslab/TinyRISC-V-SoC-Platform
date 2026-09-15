#include <stdio.h>

#include "menu.h"
#include "perf.h"
#include "platform_config.h"
#include "proj_menu.h"

#ifdef TFLM_MODEL_ENABLED
#include "tflm_runner.h"

#ifndef MODEL_NAME
#define MODEL_NAME "unknown"
#endif
#endif

namespace {

void do_system_info(void) {
  printf("[INFO] TinyRISC-V SoC Platform\n");
  printf("[INFO] DDR3 Range: 0x60000000 - 0x6FFFFFFF\n");
  printf("[INFO] Custom accelerator interface: CUSTOM-0\n");
  printf("[INFO] Clock: %u Hz\n", (unsigned)PLATFORM_CLOCK_HZ);
#ifdef TFLM_MODEL_ENABLED
  printf("[INFO] Active model: %s\n", MODEL_NAME);
#else
  printf("[INFO] TFLM model: disabled\n");
#endif
  perf_print_now();
}

const MenuItem kMainItems[] = {
    MENU_ITEM('l', "Lab menu", lab_menu_run),
#ifdef TFLM_MODEL_ENABLED
    MENU_ITEM('t', "TFLM inference, verification, and cycles",
              tflm_run_inference),
#endif
    MENU_ITEM('p', "Performance counter tests", perf_test_menu),
    MENU_ITEM('i', "System info", do_system_info),
    MENU_SENTINEL,
};

const Menu kMainMenu = {
    "TinyRISC-V SoC Platform",
    "main",
    kMainItems,
};

}  // namespace

int main(void) {
  menu_run(&kMainMenu);
  return 0;
}
