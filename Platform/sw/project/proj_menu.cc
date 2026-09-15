#include "proj_menu.h"

#include "platform_test.h"
#include "menu.h"

namespace {

const MenuItem kLabItems[] = {
    MENU_ITEM('a', "Basic platform tests", platform_test),
    MENU_END,
};

const Menu kLabMenu = {
    "Lab 0: Basic Platform Tests",
    "lab0",
    kLabItems,
};

}  // namespace

void lab_menu_run(void) { menu_run(&kLabMenu); }
