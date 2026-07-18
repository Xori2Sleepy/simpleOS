[bits 16]   
[org 0x7c00]
; basic stage one bootloader, really small and basic
start:
    cli
    cld                         ; we uses lodsb to print stuff so we need to clear df. Just to make sure!
    mov     [boot_drive], dl
    xor     ax, ax

    ; clear segment data to zero!
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7c00          ; Set stack pointer below the code, safe zone
    sti 

    ; printing message, here for testing
    mov     si, msg
    call    print_loop

    mov     cx, 5               ; uses as counter we attempt to load second stage bootloader
sector_load:
    dec     cx                  ; if re attempt too many time, halt the cpu
    test    cx, cx
    jz      halt

    mov     ah, 02h             ; read sector (CHS)
    mov     al, [sector2read]   ; # of sectors to read
    mov     ch, 0               ; cylinder 0
    mov     cl, 2               ; read start from sector 2
    mov     dh, 0               ; head 0 
    mov     bx, 0x7E            ; should be save memory zone for second stage
                                ; dl should be unchanged at this point
    push    cx                  ; IBM said general purpose can be destroy by int!
    int     13h                 ; bios disk service
    pop     cx
    jc      disk_error          ; if cf is set it meant int fail
    jc      sector_load
    
    mov     si, msg_disk_sc
    call    print_loop
    jmp     0x7E00              ; jmp to second stage bootloader!

disk_error:
    push    cx
    mov     si, [msg_disk_er]
    call    print_loop          ; print error message

    mov     al, ah              ; ah contain error code
    shr     al, 4               ; shift by 4 so we get upper hex digit
    mov     bx, hex_map
    xlat                        ; xlat take al and add to pointer at bx and load memory at
    call    print_char          ; bx then load stuff at that address into al

    mov     al, ah
    and     al, 0Fh             ; clear upper bits
    xlat
    call    print_char

    xor     ax, ax
    int     13h                 ; call bios to reset controller
    
    pop     cx
    stc                         ; set carry, we doing this weird thing to avoid recursion idk
    ret

halt:
    cli
    hlt
    jmp     halt
; ---------- function ----------  
; general purpose function
print_char:
    mov     ah, 0x0E
    int     0x10
    ret

print_loop:
    ; a universal function, this print message in si!
    lodsb                       ; Load next byte from SI into AL
    cmp     al, 0
    je      .done
    call    print_char          ; BIOS teletype function
    jmp     print_loop
.done:
    ret

hang: jmp     $

boot_drive  db      0
msg         db      "Bootloader loaded! Attemp to load the second stage bootloader...", 0
msg_disk_er db      "Disk read error! Error code: ", 0 
msg_disk_sc db      "Disk read success! Starting second stage bootloader...", 0
hex_map     db      "0123456789ABCDEF"      ; it used for xlat
sector2read db      3                       ; a magic number, number of sector to read!

times 510-($-$$) db 0 ; fill the rest with 0
dw 0xaa55
