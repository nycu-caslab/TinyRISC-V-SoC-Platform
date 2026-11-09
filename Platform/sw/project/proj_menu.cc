#include "proj_menu.h"

#include "accelerator_test.h"
#include "conv_test.h"
#include "menu.h"
#include "platform_test.h"
#include "simd_mac_test.h"

extern void run_logistic_test();
extern void run_transpose_test();

namespace {

const MenuItem kLabItems[] = {
    MENU_ITEM('a', "Accelerator AXI Aligned Test", accelerator_test),
    MENU_ITEM('b', "Accelerator AXI Misaligned Test", accelerator_misaligned_test),
    MENU_ITEM('c', "Basic Convolution Test", conv_address_aligned_test),
    MENU_ITEM('d', "Basic platform tests", platform_test),
    MENU_ITEM('e', "Standalone SIMD INT8 MAC Test", simd_mac_test),
    MENU_ITEM('l', "run logistic test", run_logistic_test),
    MENU_ITEM('t', "run transpose test", run_transpose_test),
    MENU_END,
};

const Menu kLabMenu = {
    "Lab : Self Test",
    "lab",
    kLabItems,
};

}  // namespace

void lab_menu_run(void) { menu_run(&kLabMenu); }
