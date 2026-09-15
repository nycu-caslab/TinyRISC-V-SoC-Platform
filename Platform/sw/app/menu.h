#ifndef PLATFORM_SW_APP_MENU_H_
#define PLATFORM_SW_APP_MENU_H_

#include <stdbool.h>

struct MenuItem {
  char selection;
  const char* description;
  void (*fn)(void);
  bool exit;
};

struct Menu {
  const char* title;
  const char* prompt;
  const MenuItem* items;
};

#define MENU_ITEM(selection, description, fn) \
  { selection, description, fn, false }

#define MENU_SENTINEL \
  { '\0', 0, 0, false }

#define MENU_END \
  { 'x', "eXit to previous menu", 0, true }, MENU_SENTINEL

void menu_run(const Menu* menu);

#endif  // PLATFORM_SW_APP_MENU_H_
