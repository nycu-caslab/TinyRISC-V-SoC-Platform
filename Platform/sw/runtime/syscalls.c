// sw/runtime/syscalls.c
#include <errno.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <sys/stat.h>

#include "platform_config.h"

#define UART_RX_FIFO   (*(volatile uint32_t *)(PLATFORM_UART_BASE + PLATFORM_UART_RX_OFFSET))
#define UART_TX_FIFO   (*(volatile uint32_t *)(PLATFORM_UART_BASE + PLATFORM_UART_TX_OFFSET))
#define UART_STATUS    (*(volatile uint32_t *)(PLATFORM_UART_BASE + PLATFORM_UART_STATUS_OFFSET))

void uart_putc(char c) {
    while (UART_STATUS & PLATFORM_UART_TX_FULL_MASK);
    UART_TX_FIFO = c;
}

char uart_getc(void) {
    while (!(UART_STATUS & PLATFORM_UART_RX_READY_MASK));
    return (char)UART_RX_FIFO;
}

int32_t _write(int32_t file, char *ptr, int32_t len) {
    for (int32_t i = 0; i < len; i++) {
        if (ptr[i] == '\n') uart_putc('\r');
        uart_putc(ptr[i]);
    }
    return len;
}

extern char _heap_start;
extern char _heap_end;

void *_sbrk(ptrdiff_t incr) {
    static char *heap_ptr = &_heap_start;
    const uintptr_t current = (uintptr_t)heap_ptr;
    const uintptr_t heap_start = (uintptr_t)&_heap_start;
    const uintptr_t heap_end = (uintptr_t)&_heap_end;
    uintptr_t next;

    if (incr >= 0) {
        if ((uintptr_t)incr > heap_end - current) {
            errno = ENOMEM;
            return (void *)-1;
        }
        next = current + (uintptr_t)incr;
    } else {
        const uintptr_t decrease = (uintptr_t)(-(incr + 1)) + 1u;
        if (decrease > current - heap_start) {
            errno = ENOMEM;
            return (void *)-1;
        }
        next = current - decrease;
    }

    heap_ptr = (char *)next;
    return (void *)current;
}


int32_t _close(int32_t file) {
    return -1;
}

int32_t _fstat(int32_t file, struct stat *st) {
    st->st_mode = S_IFCHR; 
    return 0;
}

int32_t _isatty(int32_t file) {
    return 1;
}

int32_t _lseek(int32_t file, int32_t ptr, int32_t dir) {
    return 0;
}

int32_t _read(int32_t file, char *ptr, int32_t len) {
    return 0;
}

void _exit(int32_t status) {
    while (1) {
    }
}

int32_t _kill(int32_t pid, int32_t sig) {
    return -1;
}

int32_t _getpid(void) {
    return 1;
}

uint64_t get_system_cycles() {
    uint32_t cycles_lo, cycles_hi, cycles_hi_check;
    do {
        __asm__ volatile ("csrr %0, mcycleh" : "=r"(cycles_hi));
        __asm__ volatile ("csrr %0, mcycle"  : "=r"(cycles_lo));
        __asm__ volatile ("csrr %0, mcycleh" : "=r"(cycles_hi_check));
    } while (cycles_hi != cycles_hi_check);
    return ((uint64_t)cycles_hi << 32) | cycles_lo;
}

uint64_t get_cycles() {
    return get_system_cycles();
}

void DebugLog(const char* s) {
	printf("%s", s);
}
