/* hw/boot/linker_bram.ld */
MEMORY
{
    BRAM (rwax) : ORIGIN = 0x00000000, LENGTH = 0x1000
}
ENTRY(_start)
_stack_start = ALIGN(ORIGIN(BRAM) + LENGTH(BRAM), 16); 

SECTIONS
{
    .text 0x00000000 : {
        _text = .;
        KEEP(*(.vectors))   
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
        *(.data*)
        . = ALIGN(4);
        _etext = .;
    } > BRAM
    /DISCARD/ : { *(.riscv.attributes) *(.comment) }
}