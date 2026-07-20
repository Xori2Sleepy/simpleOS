[bits 16]
[org 0x7E00]

start:
    ; environmental setup, already did this in stage 1, but JUST TO MAKE SURE!
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7c00
    sti

    mov     al, 13
    call    print_char          ; function doesnt clobbered anything, al resuable!
    mov     al, 10
    call    print_char

    mov     si, msg
    call    print_loop
    call    enable_a20

enable_a20:
    ; for some reason all the website out there make it look like this is some scary as hell process,
    ; i am kinda scare now ...

    call    check_a20           ; alway check before anything
    jc      .a20_done

    ; 1: try to enable a20 using the bios interrupt method.
    mov     ax, 2401h           ; function 2401h: Enable A20 GATE
    int     15h                 ; call misc system service apparently
    call    check_a20           ; doesnt clobbed ax (error code return from in t 15h)
    jc      .a20_done
    mov     si, msg_bios_a20_failed
    call    print_error         ; args is error code in ah and string pointer in si
    mov     si, msg_bios_a20_cont
    call    print_loop

    ; 2: a fallback method incase bios a20 activation fail
    ; utilize i/o ports on CPU and ask keyboard controler to enable A20
    ; it kinda slow af, also i have never seen in and out instruction before so that cool
    cli
.wait_keyboard_ctrl_resp:
    in      al, 64h             ; read the regs of keyboard controler, 8 bits,
                                ; store info from ports 64h to al
    test    al, 2               ; and 0000 0010 to isolate second bits (bits 1 AKA status bit) for testing status
    jnz     .wait_keyboard_ctrl_resp    ; if we AND and it give zero it meant status bit is off and empty-
                                ; -which mean we can safely use mov to talk to keyboard controler
    mov     al, 0xDF            ; 0xDF the command for enabling A20, DD is disabling!
    out     64h, al             ; send info on al to cpu I/O port 64h 
    sti
    call    check_a20
    jc      .a20_done
    mov     si, msg_kb_ctrl_failed
    call    print_loop

    ; 3: fast port 92h, a modern and fast alternative to port 64h (keyboard controller)
    ; we also need to make sure bits 0 is off incase accidental hard reset
    in      al, 92h             ; also respond to several other system level switch!
    or      al, 2               ; set bits 1 to 1 (this the A20 bit!)
    and     al, 0xFE            ; set bits 0 to 0 to prevent accidental hard reset
    out     92h, al             ; write update to port
    call    check_a20
    jc      .a20_done
    mov     si, msg_ff_failed
    call    print_loop

    ; some other method but too obscue might break thing :( dont want to remove it though so it stay as comment
    ; 4: desperate time require desperate measure, fast and dirty 0EEh! (for 386SL / Geode)
    ;in      al, 0EEh            ; Some chipsets enable A20 just by reading this port apparently???

    ; 5: search the depth of internet for Phoenix/C&T stuff idk
    ;in      al, 61h
    ;or      al, 0x80            ; force latch high
    ;and     al, 0xFE            ; clear bit 0 so speaker doesnt scream cause this thing also control other stuff
    ;out     61h, al
    ;call    check_a20

.a20_failed:
    ; code will fall here naturally if a20 fail
    mov     si, msg_a20_failed
    call    print_loop
    call    halt

.a20_done:
    mov     si, msg_a20_success
    call    print_loop
    call    halt                ; here for now
    

; ---------- functions ---------- 
; more specific function that MIGHT be useful in some other place

check_a20:
    ; input: NA
    ; output: carry flag, set mean a20 is on vise versa
    ; clobbled: carry flag (potentially memory corruption but highly unlikely), 

    ; principle is that higest possible address is 0xFFFF:0xFFFF which is 0xFFFF * 16 + 0xFFFF
    ; = 0x10FFF0, the cpu cant see that 10 in __FFEF so it it wrap to FFEF. We just have to write to some address
    ; (in this case i choose 0x500 cause it stack bottom, unless you got crazy stack aint no data gonna be here -
    ; - so it fine even if it corrupt)
    ; then we write another stuff to 10500, if it unwrap our value should still be there, if it is wrap it will be overwrite
    ; with new value, we just have to compare the 0x500 with our new value, if equal than a20 not on
    pushf
    push    ax
    push    si
    push    di
    push    ds
    push    es
    cli

    xor     ax, ax
    mov     ds, ax              ; data segment = 0x0000
    mov     si, 0x500           ; 0x0000:0x0500, we know 0x500 is safe memory zone

    not     ax                  ; 0xFFFF in ax
    mov     es, ax              ; extra segment = 0xFFFF
    mov     di, 0x0510

    ; we saved stuff, dont want memory corruption after all
    mov     al, [ds:si]         ; this represent the non wrap address
    push    ax
    mov     al, [es:di]         ; this represent the "beyond" address
    push    ax

    mov     byte [ds:si], 0x67  ; random value to non wrap address
    mov     byte [es:di], 0xFF  ; if it wrap this should overwrite 0x67

    cmp     byte [ds:si], 0xFF  ; the non wrap address equal the beyond address, it wrap

    pop     ax
    mov     [es:di], al
    pop     ax
    mov     [ds:si], al

    je      .a20_disabled

.a20_enabled:
    ; naturally fall here
    pop     es
    pop     ds
    pop     di
    pop     si
    pop     ax
    popf
    stc
    ret

.a20_disabled:
    pop     es
    pop     ds
    pop     di
    pop     si 
    pop     ax
    popf
    clc
    ret

    
halt:
    ; halt the cpu
    mov     si, msg_cpu_halted
    call    print_loop
.halt_loop:
    cli
    hlt
    jmp     .halt_loop
; ---------- functions ----------  
; general purpose function | USE ONLY IN REAL MODE!
; we dont want dependencies at bare metal level! redundent is the safest!

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
    pushf
    push    ax
    cld
.loop:
    lodsb
    cmp     al, 0
    je      .done
    call    print_char
    jmp     .loop
.done: 
    pop     ax
    popf
    ret

print_error:
    ; input regs: pointer to error string in si
    ;           : byte size error (hex) in ah
    ; clobbered regs: NA
    push    ax
    push    bx
    call    print_loop
    
    ; print first
    mov     al, ah
    shr     al, 4
    mov     bx, hex_map
    xlat
    call    print_char
    ; print second 
    mov     al, ah
    and     al, 0Fh
    mov     bx, hex_map
    xlat
    call    print_char
    ; print line feed and NL
    mov     al, 13
    call    print_char
    mov     al, 10
    call    print_char
    
    pop     bx
    pop     ax
    ret

msg                 db      "Second Stage bootloader succesfully loaded! Attempting to enable A20...", 13, 10, 0
msg_a20_success     db      "A20 successfully initialize! Attempting to build Global Descriptor Table...", 13, 10, 0
msg_a20_failed      db      "CRITICAL: Attempted all reliable method. If you see this message, the only way to continue "
                    db      "is to dig up the bootloader code and manually uncomment other method. Good Luck!", 13, 10, 0
                    db      "CRITICAL: A20 can not be enable; system can not be safely load: Halting CPU!", 13, 10, 0
msg_cpu_halted      db      "CRITICAL ERROR: CPU halted!", 13, 10, 0
msg_bios_a20_failed db      "BIOS A20 initialization failed. Error code: ", 13, 10, 0
msg_bios_a20_cont   db      "Attempt other known method for A20 initiation...", 13, 10, 0
msg_kb_ctrl_failed  db      "Keyboard controller A20 initiation failed. Attmepting other known method...", 13, 10, 0
msg_ff_failed       db      "System Control Port A A20 initiation failed!", 13, 10

hex_map             db      "0123456789ABCDEF"
times 4096-($-$$)   db      0
