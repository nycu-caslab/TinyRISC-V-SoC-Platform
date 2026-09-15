# hw/boot/start.s
.section .vectors, "ax"  
.global _start

.equ UART_BASE,    0x40005000
.equ UART_RX,      0x00
.equ UART_TX,      0x04
.equ UART_STATUS,  0x08
.equ UART_RX_VLD,  0x01
.equ UART_TX_FULL, 0x08
.equ DDR_BASE,     0x60000000

_start:
    # ------------------------------------------
    #  Init UART Base
    # ------------------------------------------
    li s11, UART_BASE

    # ------------------------------------------
    #  Notify Host we are ready
    # ------------------------------------------
    li a0, 83 # 'S'
    jal ra, uart_putc
    li a0, 89 # 'Y'
    jal ra, uart_putc
    li a0, 78 # 'N'
    jal ra, uart_putc
    li a0, 67 # 'C'
    jal ra, uart_putc

    # ------------------------------------------
    #  Wait for 'D' from Python (Download Done)
    # ------------------------------------------
wait_for_jtag:
    jal ra, uart_getc
    li t0, 68 # ASCII 'D'
    bne a0, t0, wait_for_jtag

    # ------------------------------------------
    #  Jump to DDR_BASE
    # ------------------------------------------
    fence.i
    li t0, DDR_BASE
    jalr zero, t0, 0

uart_putc:
1:  lw t1, UART_STATUS(s11)
    andi t1, t1, UART_TX_FULL
    bnez t1, 1b
    sw a0, UART_TX(s11)
    ret

uart_getc:
1:  lw t1, UART_STATUS(s11)
    andi t1, t1, UART_RX_VLD
    beqz t1, 1b
    lw a0, UART_RX(s11)
    andi a0, a0, 0xFF
    ret