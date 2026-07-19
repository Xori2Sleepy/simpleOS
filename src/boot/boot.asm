[bits 16]   
[org 0x7c00]
; basic stage one bootloader, really small and basic
start:
    cli
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

sector_load:
    dec     byte [counter]      ; if re attempt too many time, halt the cpu
    jz      halt

    mov     ah, 02h             ; read sector (CHS)
    mov     al, [sector2read]   ; # of sectors to read
    mov     ch, 0               ; cylinder 0
    mov     cl, 2               ; read start from sector 2
    mov     dh, 0               ; head 0 
    mov     bx, 0x7E00          ; should be a save memory zone for second stage
    mov     dl, [boot_drive]

    int     13h                 ; bios disk service

    jnc     .success
    call    disk_error          ; if cf is set it meant int fail
    jmp     sector_load

.success:
    mov     si, msg_disk_sc
    call    print_loop
    jmp     0x7E00              ; jmp to second stage bootloader!

disk_error:
    push    ax
    mov     al, [counter]
    add     al, '0'
    call    print_char
    pop     ax

    mov     si, msg_disk_er
    call    print_loop          ; print error message
    
    ; print first
    mov     al, ah              ; ah contain error code
    shr     al, 4               ; shift by 4 so we get upper hex digit
    mov     bx, hex_map
    xlat                        ; xlat take al and add to pointer at bx and load memory at
    call    print_char          ; bx then load stuff at that address into al
    ; print second 
    mov     al, ah
    and     al, 0Fh             ; clear upper bits
    mov     bx, hex_map
    xlat
    call    print_char

    xor     ax, ax              ; error code gone, ax = 0 for disk reset
    mov     dl, [boot_drive]
    int     0x13                ; call bios to reset controller
    jnc     .cont               ; cf is set if reset fail
    mov     si, msg_rs_fail     ; reset fail!
    call    print_loop

.cont:
    ret

halt:
    mov     si, msg_halt
    cli
    hlt
    jmp     halt
; ---------- function ----------  
; general purpose function
print_char:
    ; need al
    pusha
    mov     ah, 0x0E
    int     0x10
    popa
    ret

print_loop:
    ; need pointer in si
    pusha
    cld                         ; we uses lodsb to print stuff so we need to clear df. Just to make sure!
.loop:
    ; a universal function, this print message in si!
    lodsb                       ; Load next byte from SI into AL
    cmp     al, 0
    je      .done
    call    print_char          ; BIOS teletype function
    jmp     .loop
.done: 
    mov     al, 10              ; nl
    call    print_char
    popa
    ret

counter     db      4
boot_drive  db      0
msg         db      "Bootloader loaded! Attemp to load the second stage bootloader...", 0
msg_disk_er db      "Disk read error! Error code: ", 0 
msg_disk_sc db      "Disk read success! Starting second stage bootloader...", 0
msg_rs_fail db      "Fatal Error: Disk controller reset fail!", 0
msg_halt    db      "CPU halting...", 0
hex_map     db      "0123456789ABCDEF"      ; it used for xlat
sector2read db      1                       ; a magic number, number of sector to read!

times 510-($-$$) db 0 ; fill the rest with 0
dw 0xaa55
