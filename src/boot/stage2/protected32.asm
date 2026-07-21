[bits 32]

extern null_descriptor
extern kernelcode_32bits_descriptor
extern kernelcode_64bits_descriptor
extern kerneldata_32bits_descriptor

protected32_entry:
    mov     ax, [kerneldata_32bits_descriptor]
    mov     ds, ax
    mov     ss, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax

    ; dint uses 7c00 cause old 16bits stack live there 
    ; dint uses 9fbff because apprently EBDA can grow into those area...
    mov     esp, 0x95000

