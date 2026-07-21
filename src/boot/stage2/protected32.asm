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

; ---------- functions ----------  
; 2000 slot of 80 col and 25 rows, each slot is 2 bytes
; 0xB8000 + (row * 80 + col) * 2 <= position logic
VGA_buffer_write:
    
    

VGA_buffer_base     dd      0xb8000
