[bits 16]

E820_signature                      equ     0x534D4150
E820_entry_size                     equ     24

; ------------------ E820 functions ------------------
detect_memory_e820:
    ; i can already tell this is going to be the most confusing function conceptually
    xor     ebx, ebx                    ; token/incrimentor for interupt, this help bios keep track of bs it spit out
    mov     dword [boot_info.entry_count], 0
    mov     di, boot_info.memory_map    ; just moving pointer

.next_entry:
    mov     eax, 0xE820         ; mem map function
    mov     edx, E820_signature ; it like handshake code? i guess? (SMAP)
    mov     ecx, E820_entry_size; some legacy stuff doesnt support 24 byte, so this tell that we do want it

    mov     dword [es:di+20], 1 ; needed by some bios? legacy reason

    int     0x15                ; write to our pointer
    jc      .e820_failed        ; error/no support

    cmp     eax, E820_signature ; see if it give gabbage or nah
    jne     .e820_failed        ; if sig is bs, it garbage we are done

    mov     eax, [es:di+8]      ; point to length attribute (length is 8 byte)
    or      eax, [es:di+12]     ; length + 4. 
    jz      .skip               ; basically cmp rdx, 0 on legnth, but we cant uses rdx so we have these

    inc     dword [boot_info.entry_count]
    add     di, E820_entry_size ; advanacing pointer if all valid

.skip:
    test    ebx, ebx            ; if it return 0 by bios it mean no more entry
    jnz     .next_entry

    cmp     dword [boot_info.entry_count], 0
    jz      .e820_failed        ; if we got nothing in map it fail
    
    mov     si, msg_e820_success
    call    print_loop
    ret

.e820_failed:
    mov     si, msg_e820_failed
    call    print_loop

    ; E801 fall back, 88h fall back is not worth it, it practiacally unbootable
    mov     ax, 0xE801
    int     0x15
    jc      .e801_failed

    test    ax, ax              ; sometime e801 return stuff in cx/dx instead of ax/bx
    jnz     .use_ax
    mov     ax, cx
    mov     bx, dx
.use_ax:
    mov     dword [boot_info.entry_count], 0
    mov     di, boot_info.memory_map

    ; entry 1: 1mb to 16mb range (ax contain kb)
    test    ax, ax
    jz      .check_above_16mb   ; skip if no memory is reported in this range

    ; base address is 1mb (0x00100000)
    mov     dword [es:di + 0], 0x00100000   ; base low
    mov     dword [es:di + 4], 0x00000000   ; base high
    
    movzx   eax, ax
    shl     eax, 10             ; multiply by 1024 (2^10)
    mov     dword [es:di + 8], eax          ; length low
    mov     dword [es:di + 12], 0x00000000  ; length high 

    ; type 1 (usable ram)
    mov     dword [es:di + 16], 1           ; type
    mov     dword [es:di + 20], 1           ; ACPI 3.0 extended attribute

    inc     dword [boot_info.entry_count]   ; we read, so add
    add     di, E820_entry_size             ; advance map pointer

.check_above_16mb:
    ; entry 2: above 16mb range (bx contain 64kb box)
    test    bx, bx
    jz      .e801_done

    mov     dword [es:di + 0], 0x01000000
    mov     dword [es:di + 4], 0x00000000

    ; convert bx to bytes
    movzx   ebx, bx
    shl     ebx, 16             ; multiply by 65536, (2^16 = 65536)
    mov     dword [es:di + 8], ebx
    mov     dword [es:di + 12], 0x00000000

    mov     dword [es:di + 16], 1
    mov     dword [es:di + 20], 1

    inc     dword [boot_info.entry_count]
.e801_done:
    cmp     dword [boot_info.entry_count], 0
    jz      .e801_failed
    mov     si, msg_e801_success
    call    print_loop

    mov     eax, dword [boot_info]     ; tell kernel to be careful!
    or      eax, 16
    mov     dword [boot_info], eax
    ret

.e801_failed:
    mov     si, msg_e801_failed
    call    print_loop
    call    halt

memory_map_sanitation:
    mov     eax, [boot_report]
    and     eax, 16         ; isolate bits 4
    test    eax, eax
    jnz     .e801

.e801:
    mov     si, msg_sanitation_e801
    call    print_loop
    ret
