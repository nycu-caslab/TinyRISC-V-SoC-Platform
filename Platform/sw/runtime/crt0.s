# sw/runtime/crt0.s
.section .text.startup
.global _start

_start:
    la sp, __stack_top
    li s0, 0x40005000

    li t0, 33
    sw t0, 4(s0)
    
    la a0, __bss_start
    la a1, __bss_end
    bgeu a0, a1, end_clear_bss
clear_bss_loop:
    sw zero, 0(a0)
    addi a0, a0, 4
    bltu a0, a1, clear_bss_loop
end_clear_bss:

    li t0, 64
    sw t0, 4(s0)

    call __libc_init_array

    li s0, 0x40005000
    li t0, 35
    sw t0, 4(s0)

    call main

1:  j 1b
