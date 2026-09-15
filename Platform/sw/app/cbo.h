#ifndef PLATFORM_SW_APP_CBO_H_
#define PLATFORM_SW_APP_CBO_H_

#include <stdint.h>

static inline void cbo_clean(const volatile void* addr) {
#if defined(__riscv)
  register uintptr_t a0 asm("a0") = (uintptr_t)addr;
  __asm__ volatile(".balign 4\n\t.word 0x0015200F"
                   : "+r"(a0)
                   :
                   : "memory");
#else
  (void)addr;
#endif
}

static inline void cbo_invalidate(const volatile void* addr) {
#if defined(__riscv)
  register uintptr_t a0 asm("a0") = (uintptr_t)addr;
  __asm__ volatile(".balign 4\n\t.word 0x0005200F"
                   : "+r"(a0)
                   :
                   : "memory");
#else
  (void)addr;
#endif
}

#endif  // PLATFORM_SW_APP_CBO_H_
