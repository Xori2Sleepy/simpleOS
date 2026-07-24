[bits 16]
[org 0x7E00]

global  null_descriptor
global  kernelcode_32bits_descriptor
global  kernelcode_64bits_descriptor
global  kerneldata_32bits_descriptor

null_descriptor                     equ      0x00
kernelcode_32bits_descriptor        equ      0x08
kernelcode_64bits_descriptor        equ      0x10
kerneldata_32bits_descriptor        equ      0x18

E820_signature      equ     0x534D4150
E820_entry_size     equ     24


; input: base, limit, access bytes, flags
%macro gdt_entries 4
    dw      %2 & 0xFFFF         ; limit is 20 bits we only need first 16 here
    dw      %1 & 0xFFFF         ; base is 32 bits but we only need first 16 here
    db      (%1 >> 16) & 0xFF   ; we only need 16-23 bits
    db      %3                  ; acess bytes
    db      ((%4 << 4) | ((%2 >> 16) & 0x0F)) ; first 4 bits is the 'other' flags, rest is limit
    db      (%1 >> 24) & 0xFF   ; only need the last 8 bits
%endmacro

; --------------- MAIN FUCNTION (basically) --------------- 
stage2_entry:
    ; environmental setup, already did this in stage 1, but JUST TO MAKE SURE!
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7c00
    sti
    
    mov     [boot_info.boot_drive], dl

    mov     al, 13
    call    print_char          ; function doesnt clobbered anything, al resuable!
    mov     al, 10
    call    print_char

    mov     si, msg
    call    print_loop
    call    enable_a20
    call    detect_memory_e820
    call    get_bios_cursor      ; need before jumping, make sure no write to buffer after this!

    ; coming for 32 mode. finally, I have escape the shackle of 16 bits programing!
    cli
    in      al, 0x70            ; Read current CMOS state
    or      al, 0x80            ; Set bit 7 to mask NMIs
    out     0x70, al            ; Send to port 0x70 (cmos)
    in      al, 0x71            ; just a dummy read to clear bus, dangling 0x70 port is dangerous, or so I was told

    lgdt    [gdt_descriptor]    ; loading gdt to gdtr
    mov     eax, cr0            ; I just discover that I can use 32 bits regs in real mode...
    or      eax, 1              ; turn the first bits of cr0 on (Protection Enable, PE bits)
    mov     cr0, eax            ; protected mode officially on

    jmp     kernelcode_32bits_descriptor:protected32_entry

; ---------- functions ---------- 
; ig you can say this is a function section
; ------------------------------------------------------------ 
;                A20 functions start here!
; ------------------------------------------------------------ 
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
    call    halt                ; if it truly fail there is not point to let the code run wild,
                                ; halting is the best and most responsible option

.a20_done:
    mov     si, msg_a20_success
    call    print_loop
    ret
; ------------------------------------------------------------ 
;                A20 functions end here!
; ------------------------------------------------------------ 
    
; ------------------------------------------------------------ 
;               Check A20 functions start here
; ------------------------------------------------------------ 
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
; ------------------------------------------------------------ 
;               Check A20 functions end here
; ------------------------------------------------------------ 

; ------------------ E820 functions ------------------
detect_memory_e820:
    ; i can already tell this is going to be the most confusing function conceptually
    xor     ebx, ebx            ; token for int, this help bios keep track of bs it spit out
    mov     dword [boot_info.entry_count], 0

    mov     di, boot_info.memory_map    ; just moving pointer

.next_entry:
    mov     eax, 0xE820         ; mem map function
    mov     edx, E820_signature ; it like handshake code? i guess? (SMAP)
    mov     ecx, E820_entry_size; some legacy stuff doesnt support 24 byte, so this tell that we do want it

    mov     dword [es:di+20], 1 ; needed by some bios? legacy reason

    int     0x15                ; write to our pointer
    jc      .failed             ; error/no support

    cmp     eax, E820_signature ; see if it give gabbage or nah
    jne     .failed             ; if sig is bs, it garbage we are done

    mov     eax, [es:di+8]      ; point to length attribute (length is 8 byte)
    or      eax, [es:di+12]     ; length + 4. 
    jz      .skip               ; basically cmp rdx, 0 on legnth, but we cant uses rdx so we have these

    inc     dword [boot_info.entry_count]
    add     di, E820_entry_size ; advanacing pointer if all valid

.skip:
    test    ebx, ebx            ; if it return 0 by bios it mean no more entry
    jnz     .next_entry

    cmp     dword [boot_info.entry_count], 0
    jz      .failed             ; if we got nothing in map it fail

    ret

.failed:
    mov     si, msg_e820_failed
    call    print_loop
    call    halt

; --------------- small halt functions ---------------
halt:
    ; halt the cpu
    mov     si, msg_cpu_halted
    call    print_loop
.halt_loop:
    cli
    hlt
    jmp     .halt_loop

; --------------- bios cursor functions --------------
get_bios_cursor:
    ; need it because I dont want to clear screen in 32 protected mode
    ; it save cursors location as flat index
    xor     ebx, ebx
    mov     ah, 0x03        ; BIOS function 0x03: Read Cursor Position
    mov     bh, 0           ; Page number 0
    int     0x10            ; Call BIOS video interrupt
    
    ; return: 
    ; DH = Row (0-24)
    ; DL = Column (0-79)

    ; Convert Row and Column into a single flat index: (Row * 80) + Column
    movzx   eax, dh         ; EAX = Row
    imul    eax, 80         ; EAX = Row * 80
    movzx   ebx, dl         ; EBX = Column
    add     eax, ebx        ; EAX = (Row * 80) + Column

    mov     [bios_cursor], eax 
    ret

; ---------------- CPUID functions -------------------
get_cpuid:
    pushfd
    pushfd
    xor     dword [esp], 0x00200000
    popfd                   ; flags updated
    pushfd
    pop     eax             ; save flags in eax
    xor     eax, [esp]      ; compare it with original flags
    popfd                   ; restore original flags
    and     eax, 0x00200000 ; now compare eax with 0x00200000. also we do this to isolate that bit
                            ; if zero mean our change did not apply
                            ; so cpuid is not avaliable
    jz      .unavailable

.available:
    ; natually fall here




    
; ---------- functions ----------
; general purpose function | CRITICAL: USE ONLY IN REAL MODE! 
; IT WILL CRASH IF TRY ON PROTECTED MODE!
; same function as in stage 1 -
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
    ; clobbered regs: NA
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

; -------------------- variable space --------------------
align 16            ; does it even matter?
msg                 db      "Second Stage bootloader succesfully loaded! Attempting to enable A20...", 13, 10, 0
msg_e820_success    db      "E820 memory mapping success! Attemp to far jump!", 13, 10, 0
msg_e820_failed     db      "E820 memory mapping failed; System can not be load safely: Halting CPU..."
msg_a20_success     db      "A20 successfully initialize! Attempt to build memory map...", 13, 10, 0
msg_a20_failed      db      "CRITICAL: Attempted all reliable method. If you see this message, the only way to continue "
                    db      "is to dig up the bootloader code and manually uncomment other method. Good Luck!", 13, 10, 0
                    db      "CRITICAL: A20 can not be enable; system can not be safely load: Halting CPU...", 13, 10, 0
msg_cpu_halted      db      "CRITICAL: CPU halted! Please reboot the PC", 13, 10, 0
msg_bios_a20_failed db      "BIOS A20 initialization failed. Error code: ", 13, 10, 0
msg_bios_a20_cont   db      "Attempt other known method for A20 initiation...", 13, 10, 0
msg_kb_ctrl_failed  db      "Keyboard controller A20 initiation failed. Attmepting other known method...", 13, 10, 0
msg_ff_failed       db      "System Control Port A A20 initiation failed!", 13, 10

hex_map             db      "0123456789ABCDEF"

global  bios_cursor
bios_cursor         dd      0x0

; -------------------- gdt space ------------------------
align 8
gdt_start:
    ; lower limit -> 2 byte (16 bits - 0 - 15)
    ; lower base -> 3 byte (24 bits - 0 - 23)

    ; flags:
    ; 7 -> present?
    ; 6-5 -> ring level
    ; 4 -> code/data segment or speicial system structure
    ; 3 -> code seg
    ; 2 -> conforming/direction
    ; 1 -> rw for code 1 allow reading and for data 1 allow writing
    ; 0 -> cpu access, set to zero, legacy feature not important if use paging
    ; bit 3,2,1,0 become type field if it a system structure
    
    ; other flags:
    ; 7 -> granularity = multiply memory by 4 kb and scale 20 bits limit to 32 bits (4gb)
    ; 6 -> D/B size/bigflags. if code then this control if it uses 32 bit protected or not, if data then stack pointer size
    ; 5 -> long/64 bits flag. 64 bits code?
    ; AVL -> avaliable flag, not used by CPU, for kernel
    ; 3-0 -> bit 16-19 of limit (MSB)

    ; base bit -> extra byte for base (24-31) giving total of 32 bits

    ; (32 bits) base, (20 bits) limit, (bytes) access bytes, (4 bits) others flags
    gdt_entries 0, 0, 0, 0                      ; 0x00 - null descriptor
    gdt_entries 0, 0xFFFFF, 10011010b, 1100b    ; 0x08 - 32 bits Kernel code segment descriptor
    gdt_entries 0, 0xFFFFF, 10011010b, 0010b    ; 0x10 - 64 bits Kernel code segment descriptor
    gdt_entries 0, 0xFFFFF, 10010010b, 1100b    ; 0x18 - 32 bits Data segment descriptor
gdt_end:

gdt_descriptor:
    ; for lgdt, 6 byte, first 2 must be size and last 4 must be gdt address
    dw      gdt_end - gdt_start - 1         ; gdt size - 1
    dd      gdt_start
; --------------------------------------------------------

align 8
boot_info:
.boot_drive         db      0
.entry_count        dd      0
.reserved   times 3 db      0   ; for alignment
.cpu_ecx            dd      0   ; cpuid stuff
.cpu_edx            dd      0

align 8
.memory_map:
times 64 * 24       db      0

; ---------- just other stuff ----------
%include "src/boot/stage2/protected32.asm"  ; we seperate the 32bit code, look cleaner. It already a mess here.
times 8192-($-$$)   db      0
