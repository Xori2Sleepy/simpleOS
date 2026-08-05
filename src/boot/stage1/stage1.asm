[bits 16]   
[org 0x7c00]
; basic stage one bootloader, really small and basic
; somehow it smaller than i expected even with the long string
start:
    cli
    mov     [boot_drive], dl
    xor     ax, ax
    ; clear segment data to zero!
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7C00          ; Set stack pointer below the code, safe zone
    sti 

    ; printing message, here for testing
    mov     si, msg
    call    print_loop
    mov     al, 10              ; nl
    call    print_char

sector_load:
    dec     byte [disk_trial_counter]      ; if re attempt too many time, halt the cpu
    jz      halt

    mov     dl, [boot_drive]
    call    disk_check_extensions
    jc      .chs

.lba:
    mov     ah, 0x42
    mov     dl, [boot_drive]
    mov     si, stage2_dap
    int     0x13
    jnc     .success
    call    disk_error
    jmp     sector_load

.chs:
    mov     ah, 02h             ; read sector (CHS)
    mov     al, [stage2_dap.sector2read]
    mov     bx, 0x7E00
    mov     ch, 0               ; cylinder 0
    mov     cl, [stage2_dap.sector_ad]
    mov     dh, 0               ; head 0 
    mov     dl, [boot_drive]
    int     13h                 ; bios disk service
    jnc     .success
    call    disk_error          ; if cf is set it meant int fail
    jmp     sector_load

.success:
    mov     si, msg_disk_sc
    call    print_loop
    mov     dl, [boot_drive]    ; make sure that stage2 got the bootdrive
    jmp     0000:0x7E00         ; jmp to second stage bootloader!

disk_error:
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

    mov     al, 13              ; line feed
    call    print_char
    mov     al, 10              ; NL
    call    print_char

    xor     ax, ax              ; error code gone, ax = 0 for disk reset
    mov     dl, [boot_drive]
    int     0x13                ; call bios to reset controller
    jnc     .cont               ; cf is set if reset fail
    mov     si, msg_rs_fail     ; reset fail!
    call    print_loop

.cont:
    ret

disk_check_extensions:
    ; need dl as input drive
    mov     ah, 41h
    mov     bx, 55AAh
    int     0x13
    jc      .failed
    
    cmp     bx, 55AAh       ; compare signature
    jne     .failed
    
    test    cx, 1           ; bit 0 is the extended disk access
    jz      .failed

    clc
    ret
.failed:
    stc
    ret

halt:
    mov     si, msg_halt
    call    print_loop
.halt_loop:
    cli
    hlt
    jmp     .halt_loop
; ---------- function ----------  
; general purpose function
print_char:
    ; input regs: need ASCII # in al
    ; clobbered regs: NA
    push    ax
    mov     ah, 0x0E
    int     0x10
    pop     ax
    ret

print_loop:
    ; input regs: need pointer in si
    ; clobbered regs: NA
    pushf
    push    ax
    cld                         ; we uses lodsb to print stuff so we need to clear df. Just to make sure!
.loop:
    lodsb                       ; Load next byte from SI into AL
    cmp     al, 0
    je      .done
    call    print_char          ; BIOS teletype function
    jmp     .loop
.done: 
    pop     ax
    popf
    ret

disk_trial_counter     db      4
boot_drive  db      0
msg         db      "Bootloader loaded! Attemp to load the second stage bootloader...", 13, 10, 0
msg_disk_er db      "Disk read error! Error code: ", 0 
msg_disk_sc db      "Disk read success! Jumping to 16 bits real mode", 13, 10, 0
msg_rs_fail db      "Fatal Error: Disk controller reset fail!", 13, 10, 0
msg_halt    db      "CPU halting...", 13, 10, 0
hex_map     db      "0123456789ABCDEF"      ; it used for xlat

stage2_dap:                    
    .dap_size           db      0x10        ; size
    .reserve            db      0x00        ; reserve for int call
    .sector2read        dw      30          ; sector to read
    .destination        dw      0x7E00      ; destination offset
    .segment            dw      0x0000      ; segment offset
    .sector_ad          dq      2

times 510-($-$$) db 0 ; fill the rest with 0
dw 0xaa55
