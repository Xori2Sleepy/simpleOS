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

    mov     dword [es:di + 20], 1 ; needed by some bios? legacy reason

    int     0x15                ; write to our pointer | DO NOT DESTROY EBX WE NEED IT
    jc      .e820_failed        ; error/no support

    cmp     eax, E820_signature ; see if it give gabbage or nah
    jne     .e820_failed        ; if sig is bs, it garbage we are done

    ; sanitation process, removing bad entires (0)
    mov     eax, [es:di + 8]    ; point to length attribute (length is 8 byte)
    or      eax, [es:di + 12]   ; length + 4. 
    jz      .skip               ; basically cmp rdx, 0 on legnth, but we cant uses rdx so we have these

    ; another sanitation process, removing address wrap around ( > 2^64 - 1)
    ; edx:eax = base
    mov     eax, [es:di + 0]
    mov     edx, [es:di + 4]
    ; edx:eax + length
    add     eax, [es:di + 8]
    adc     edx, [es:di + 12]   ; this instruction save my life bro I dint even know this exist
    jc      .skip               ; this is why we love CISC

    inc     dword [boot_info.entry_count]
    add     di, E820_entry_size ; advanacing pointer if all valid

.skip:
    test    ebx, ebx            ; if it return 0 by bios it mean no more entry
    jnz     .next_entry         ; ACHTUNG ACHTUNG ACHTUNG | BE CAREFUL WITH EBX! I wish i could highlight comment

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

; ------------------ E820 sanitation ------------------
memory_map_sanitation:
    call    memory_map_sort
    jc      .not_sort
    call    memory_map_merge
.not_sort:
    ret

; ------------------ E820 merge ------------------
memory_map_merge:
    xor     ecx, ecx        ; counter for looping
    mov     edx, [boot_info.entry_count]
    dec     edx

.merge_loop:
    cmp     ecx, edx
    jge     .done

    push    edx
    push    ecx

    mov     ax, cx
    shl     cx, 1
    add     cx, ax
    shl     cx, 3       ; cx to offset
    mov     eax, [boot_info.memory_map + ecx]       ; lower half base
    add     eax, dword [boot_info.memory_map + ecx + 8]     ; add lower length
    mov     edx, [boot_info.memory_map + ecx + 4]   ; higher half base
    adc     edx, dword [boot_info.memory_map + ecx + 12]    ; higher half length
    cmp     eax, dword [boot_info.memory_map + ecx + 24]    ; compare to lower base address of next
    jne     .not_equal
    cmp     edx, dword [boot_info.memory_map + ecx + 28]    ; compare to upper base address of next
    jne     .not_equal
.equal:
    ; after basic address check, compare type and extended attribute
    mov     eax, [boot_info.memory_map + ecx + 16]  ; it 4 byte long
    cmp     eax, [boot_info.memory_map + ecx + 40]  ; compare type
    jne     .not_equal
    mov     eax, [boot_info.memory_map + ecx + 20]
    cmp     eax, [boot_info.memory_map + ecx + 44]  ; compare extended attribute
    jne     .not_equal
    pop     ecx     ; now it index instead of offset
    mov     edi, ecx
    call    merge_adjacent_map_entry     ; if equal merge adjacent and shift entire buffer
    pop     edx     ; we dont incriment here because incase 3 adjacent can be merge
    dec     edx     ; every time it merge length decrease
    jmp     .merge_loop

.not_equal:
    pop     ecx
    pop     edx
    inc     ecx
    jmp     .merge_loop

.done:
    mov     si, msg_map_merge_success
    call    print_loop
    ret

; ------------------ E820 sort ------------------
memory_map_sort:
    ; Sorting algorithm in assembly? DEAR GOD
    ; Optimization is not a thing here, prirority is the perserve my sanity
    ; input: NA
    ; output: NA
    ; clobbered: just assume it perserve none of the general regs and eflag
    mov     eax, [boot_report]
    and     eax, 16         ; isolate bits 4
    test    eax, eax
    jnz     .e801

    ; INSERTION SORT BEGIN HERE!
    ; this is to sort memory map return by func e820 of int 0x15
    xor     edi, edi
    xor     esi, esi
    xor     ecx, ecx

    mov     cx, 1          ; pointer to index (start @ second element)

.loop:
    mov     ax, [boot_info.entry_count]
    cmp     cx, ax
    je      .done_sort

    mov     di, cx
    call    copy_map_to_temp
    
    mov     ax, cx

.shift_compare_loop:
    ; compare current with left
    test    ax, ax
    jz      .done_shift

    mov     di, ax
    push    eax
    call    compare_map_left_index_less_than   ; function perserve all register
    pop     eax                 ; just defensive programing
    jc      .shift              ; carry = current is less than

.done_shift:
    mov     di, ax              ; copy to what ever ax is
    call    copy_map_from_temp
    inc     cx                  ; move on to next index
    jmp     .loop               ; current index 0, we shift everything already

.shift:
    mov     di, ax
    dec     ax                  ; i heard sub is more efficient but it virtually no different in modern system
    mov     si, ax
    push    ax
    call    copy_map_entry     ; copying left to current index
    pop     ax                 ; index here still have dec from before call
    jmp     .shift_compare_loop

.done_sort:
    mov     si, msg_sanitation_success
    call    print_loop
    clc
    ret

.e801:
    mov     si, msg_sanitation_e801
    call    print_loop
    stc
    ret


; ---------- HELPER FUNCTION ----------
compare_map_left_index_less_than:
    ; fuck 16 bits mode, we can only uses eax so we cant compare qword normally
    push    edi
    push    eax
    ; input: current index in edi
    mov     ax, di
    shl     di, 1
    add     di, ax      ; * 3
    shl     di, 3       ; 3 * 8 = 24

    xor     eax, eax
    mov     eax, edi
    ; compare current with left
    mov     edi, dword [boot_info.memory_map + eax + 4]  ; top bits of base address
    sub     eax, 24      ; element to the left
    cmp     ebx, dword [boot_info.memory_map + eax + 4]
    jne     .compare
    add     eax, 24
    mov     edi, dword [boot_info.memory_map + eax]
    sub     eax, 24
    cmp     edi, dword [boot_info.memory_map + eax]      ; pointer to left of current index position now
.compare:
    jl      .less_than
    pop     eax
    pop     edi
    clc
    ret
.less_than:
    pop     eax
    pop     edi
    stc
    ret

copy_map_entry:
    ; input: si, di
    ; ouput: memory mov
    ; note: this move a 24 byte chuck from si to di and add abstraction
    ; convert indexes to effective address
    push    esi
    push    edi
    push    ecx
    push    eax

    mov     ax, si
    shl     si, 1
    add     si, ax      ; *3
    shl     si, 3       ; 3 * 8 = 24
    mov     ax, di
    shl     di, 1
    add     di, ax      ; *3
    shl     di, 3       ; 3 * 8 = 24

    add     si, boot_info.memory_map
    add     di, boot_info.memory_map
    mov     ecx, 6      ; double word * 6 = 24 byte
    rep     movsd

    pop     eax
    pop     ecx
    pop     edi
    pop     esi
    ret

copy_map_to_temp:
    ; input: di
    ; ouput: memory mov 2 scratch pad
    push    esi
    push    edi
    push    ecx
    push    eax
        
    mov     si, di

    mov     ax, si
    shl     si, 1
    add     si, ax
    shl     si, 3       ; 3 * 8 = 24
    add     si, boot_info.memory_map
    add     di, scratchpad
    mov     ecx, 6      ; double word * 6 = 24 byte
    rep     movsd

    pop     eax
    pop     ecx
    pop     edi
    pop     esi
    ret

copy_map_from_temp:
    ; input: di
    ; ouput: memory mov 2 scratch pad
    push    esi
    push    edi
    push    ecx
    push    eax
    
    mov     ax, di
    shl     di, 1
    add     di, ax
    shl     di, 3       ; 3 * 8 = 24
    add     si, scratchpad
    add     di, boot_info.memory_map
    mov     ecx, 6      ; double word * 6 = 24 byte
    rep     movsd

    pop     eax
    pop     ecx
    pop     edi
    pop     esi
    ret

merge_adjacent_map_entry:
    ; input: edi
    ; merge entry to the right of index
    push    edi
    push    esi
    push    eax
    push    edx

    push    edi
    mov     ax, di
    shl     di, 1
    add     di, ax
    shl     di, 3
    mov     eax, [boot_info.memory_map + edi + 8]
    add     eax, [boot_info.memory_map + edi + 32]
    mov     edx, [boot_info.memory_map + edi + 12]
    adc     edx, [boot_info.memory_map + edi + 36]
    mov     [boot_info.memory_map + edi + 8], eax
    mov     [boot_info.memory_map + edi + 12], edx
    pop     edi

    mov     eax, edi
    inc     eax     ; index to the right
    xor     esi, esi
    xor     edi, edi
.shift_loop:
    dec     [boot_info.entry_count]
    mov     edx, [boot_info.entry_count]    ; if it not equal to last 
    sub     edx, 1
    cmp     eax, edx
    je      .done

    push    eax
    mov     edi, eax
    inc     eax
    mov     esi, eax    ; shift stuff from right to current index counter
    call    copy_map_entry
    pop     eax
    inc     eax         ; inc counter
    jmp     .shift_loop
.done:  
    pop     edx
    pop     eax
    pop     esi
    pop     edi
    ret
