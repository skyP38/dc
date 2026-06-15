.code32
.global _start
_start:
    .long 0x1BADB002   # magic
    .long 0x00000000   # flags
    .long 0xE4524FFE   # checksum

    movl $0x7C00, %esp
    call kernel_main
    hlt
    jmp .
