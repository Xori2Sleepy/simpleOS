[bits 16]
[org 0x7E00]

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

    mov     si, msg_stage2_entry
    call    print_loop

    mov     si, msg_attempt_cpuid
    call    print_loop
    call    get_cpuid

    mov     si, msg_attempt_a20
    call    print_loop
    call    enable_a20

    mov     si, msg_attempt_e820
    call    print_loop
    call    detect_memory_e820

    mov     si, msg_attempt_kernel_load
    call    print_loop
    call    kernel_load

    mov     si, msg_attempt_header_read
    call    print_loop
    call    kernel_header_read

    call    get_bios_cursor     ; need before jumping, make sure no write to buffer after this!
    
    mov     si, msg_gdt
    call    print_loop
    ; coming for 32 mode. finally, I have escape the shackle of 16 bits programing!
    cli
    in      al, 0x70            ; Read current CMOS state
    or      al, 0x80            ; Set bit 7 to mask NMIs
    out     0x70, al            ; Send to port 0x70 (cmos)
    in      al, 0x71            ; just a dummy read to clear bus, dangling 0x70 port is dangerous, or so I was told

    lgdt    [gdt_descriptor]    ; loading gdt to gdtr
    mov     eax, cr0            ; I just discover that I can use 32 bits regs in real mode...
    or      eax, 1              ; turn the first bits of cr0 on (Protection Enable, PE bits)


    mov     si, msg_far_jump    ; print stuff before interupt cant be call!
    call    print_loop

    mov     cr0, eax            ; protected mode officially on


    jmp     kernelcode_32bits_descriptor:protected32_entry

; ---------- functions ---------- 
%include "src/boot/stage2/16bits/a20.asm"
%include "src/boot/stage2/16bits/e820.asm"
%include "src/boot/stage2/16bits/cpuid.asm"
%include "src/boot/stage2/16bits/basic_print.asm"
%include "src/boot/stage2/16bits/kernel_load.asm"

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


; --------------------  kernel info ------------------------
kernel_magic            equ     0x51414442

kernel_info:
    .magic              dd      0
    .version            dw      0
    .header_size        dw      0
    .image_size         dd      0
    .entry32            dd      0           ; off set from image start
    .entry64            dd      0
    .required_cpu       dd      0
    .flags              dd      0

kernel_dap:                    
    .dap_size           db      0x10        ; size
    .reserve            db      0x00        ; reserve for int call
    .sector2read        dw      0x01        ; sector to read
    .destination        dw      0x800       ; destination offset, old stack live in that segment should be safe tho, i think
    .segment            dw      0x0000      ; segment offset
    .sector_ad          dq      18

disk_trial_counter      db      4
; --------------------  boot info ------------------------
align 8
boot_info:
    .boot_drive         db      0
    .kernel_report      db      0           ; 8 bits kernel status flags
    .entry_count        dd      0

    .reserved       times 3     db      0   ; for alignment

    ;cpuid subsection
    .cpu_features1_ecx  dd      0
    .cpu_features1_edx  dd      0
    .cpu_features7_ebx  dd      0
    .cpu_features7_ecx  dd      0
    .cpu_features7_edx  dd      0
    .cpu_max_leaf       dd      0
    .cpu_max_x_leaf     dd      0
    .cpu_signature      dd      0
    .vendor_category    db      0

    .vendor_name    times 3     dd      0
    .brand_string   times 48    db      0

    .e801_status        db      0

    align 8
    .memory_map     times 64 * 24       db      0

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

; -------------------- CPUID TABLE --------------------
CPUID_VENDOR_TABLE:
    ; AMD
    CPUID_VENDOR_AMD        db      "AuthenticAMD"
    CPUID_VENDOR_AMD_OLD    db      "AMDisbetter!"      ; I agree bro
    CPUID_VENDOR_HYGON      db      "HygonGenuine"

    ; Intel
    CPUID_VENDOR_INTEL      db      "GenuineIntel"      ; step up your game, your name suck

    ; Intel Compatable
    CPUID_VENDOR_VIA        db      "VIA VIA VIA "      ; worst one yet
    CPUID_VENDOR_TRANSMETA  db      "GenuineTMx86"
    CPUID_VENDOR_TRANSMETA_OLD      db      "TransmetaCPU"
    CPUID_VENDOR_CYRIX      db      "CyrixInstead"
    CPUID_VENDOR_CENTAUR    db      "CentaurHauls"
    CPUID_VENDOR_NEXGEN     db      "NexGenDriven"
    CPUID_VENDOR_UMC        db      "UMC UMC UMC "
    CPUID_VENDOR_SIS        db      "SIS SIS SIS "
    CPUID_VENDOR_NSC        db      "Geode by NSC"      ; i feel like i heard about Geode from somewhere...
    CPUID_VENDOR_RISE       db      "RiseRiseRise"
    CPUID_VENDOR_ZHAOXIN    db      "  Shanghai  "

    ; Embeded / Other
    CPUID_VENDOR_VORTEX     db      "Vortex86 SoC"
    CPUID_VENDOR_ELBRUS     db      "E2L MACHINE "
    CPUID_VENDOR_A0486      db      "MiSTer A0486"
    CPUID_VENDOR_A0486_OLD  db      "GenuineA0486"

    ; Hypervisors CPUID
    CPUID_VENDOR_QEMU       db      "TCGTCGTCGTCG"
    CPUID_VENDOR_KVM        db      " KVMKVMKVM "
    CPUID_VENDOR_VMWARE     db      "VMwareVMware"
    CPUID_VENDOR_VIRTUALBOX db      "VBoxVBoxVBox"
    CPUID_VENDOR_XEN        db      "XenVMMXenVMM"
    CPUID_VENDOR_HYPERV     db      "Microsoft HV"
    CPUID_VENDOR_PARALLELS  db      " prl hyperv "
    CPUID_VENDOR_PARALLELS_ALT      db      " lrpepyh vr "  ; we need alt because sometime endianess mismatch
    CPUID_VENDOR_BHYVE      db      "bhyve bhyve "
    CPUID_VENDOR_QNX        db      " QNXQVMBSQG "

CPUID_VENDOR_CATEGORY:
    times 3     db      CPUID_AMD_CATEGORY
    times 1     db      CPUID_INTEL_CATEGORY
    times 11    db      CPUID_INTEL_COMPATIBLE
    times 4     db      CPUID_OTHER_CATEGORY
    times 10    db      CPUID_HYPERVISOR

CPUID_VENDOR_BUFFER:
    times 3     dd      0   ; 12 byte buffer

; -------------------- variable space --------------------
align 16            ; does it even matter?
; general
msg_stage2_entry    db      "Second stage active: Executing Instruction ", 13, 10, 0
msg_cpu_halted      db      "CRITICAL: CPU halted! Please reboot the PC", 13, 10, 0
msg_far_jump        db      "Preparation complete: Enabling CR0 and attempting a far jump to 32 bits protected mode; Brace for impact and good luck 32 bits code! :)", 13, 10, 0
msg_gdt             db      "Global Description Table structure defined, loading it to register...", 13, 10, 0

; e820 & e801
msg_e820_success    db      "E820 memory mapping success!", 13, 10, 0
msg_e820_failed     db      "E820 memory mapping failed; Attempting fallback method"
msg_e801_success    db      "E801 memory mapping success: Note that RAM will be limit to 16 Mb", 13, 10, 0
msg_e801_failed     db      "E801 memroy mapping failed: Memory cannot be map; Halting CPU...", 13, 10, 0

; a20
msg_a20_success     db      "A20 successfully initialize!", 13, 10, 0
msg_a20_failed      db      "CRITICAL: Attempted all reliable method. If you see this message, the only way to continue "
                    db      "is to dig up the bootloader code and manually uncomment other method. Good Luck!", 13, 10, 0
                    db      "CRITICAL: A20 can not be enable; system can not be safely load: Halting CPU...", 13, 10, 0
msg_bios_a20_failed db      "BIOS A20 initialization failed. Error code: ", 13, 10, 0
msg_bios_a20_cont   db      "Attempt other known method for A20 initiation...", 13, 10, 0
msg_kb_ctrl_failed  db      "Keyboard controller A20 initiation failed. Attmepting other known method...", 13, 10, 0
msg_ff_failed       db      "System Control Port A A20 initiation failed!", 13, 10

; kernel & disk
msg_rs_success      db      "   Disk reset success!", 13, 10, 0
msg_rs_failed       db      "   CRITICAL: Disk reset failed", 13, 10, 0
msg_disk_success    db      "   Disk read success", 13, 10, 0
msg_disk_failed     db      "   Disk read error! Error code: ", 0
msg_kernel_load_success db  "   Kernel header succesfully loaded", 13, 10, 0
msg_kernel_load_failed  db  "   Kernel header fail to load. Continuing with execution...", 13, 10, 0

; kernel read n stuff
msg_unrecognized_magic  db  "   Unrecognized magic: kernel header could not be parsed", 13, 10, 0
msg_recognized_magic    db  "   Recognized magic: kernel header successfully parsed", 13, 10, 0

; attempt
msg_attempt_a20     db      "Attempting to enable A20: ", 0
msg_attempt_e820    db      "Attempting to build memory map: ", 0
msg_attempt_cpuid   db      "Attempting to fetch data from CPUID: ", 13, 10, 0
msg_attempt_kernel_load     db      "Attempting to load kernel header: ", 13, 10, 0
msg_attempt_header_read     db      "Attempting to read kernel header: ", 13, 10, 0

; cpuid stuff
msg_cpuid_unavailable       db      "   CPUID: CPUID feature is unavailable, can not obtain nessary information: Halting CPU.", 13, 10, 0
msg_cpuid_unknown_vendor    db      "   CPUID: Attempt to detect CPU architecture return unknown vendor!", 13, 10, 0
msg_cpuid_leaf1_failed      db      "   CPUID: Leaf 1 unavailable: Unable to detect CPU Signature and Base Feature Flags!", 13, 10, 0
msg_cpuid_leaf1_success     db      "   CPUID: CPU Signature and Base Feature Flags detection success!", 13, 10, 0
msg_cpuid_leaf7_failed      db      "   CPUID: Leaf 7 unavailable: Unable to detect extended feature flags!", 13, 10, 0
msg_cpuid_leaf7_success     db      "   CPUID: Extended Feature Flags detection success!", 13, 10, 0
msg_cpuid_xleaf2to4_failed  db      "   CPUID: Failed to fetch CPU Brand Label", 13, 10, 0
msg_cpuid_xleaf2to4_success db      "   CPUID: Successfully fetch CPU Brand Label", 13, 10, 0      

; -------------------- random constant and variable space --------------------


global  bios_cursor                 ; linear bios cursor addressing
global  null_descriptor
global  kernelcode_32bits_descriptor
global  kernelcode_64bits_descriptor
global  kerneldata_32bits_descriptor

hex_map                             db      "0123456789ABCDEF"
bios_cursor                         dd      0x0

CPUID_AMD_CATEGORY                  equ     1
CPUID_INTEL_CATEGORY                equ     2
CPUID_INTEL_COMPATIBLE              equ     3
CPUID_OTHER_CATEGORY                equ     4
CPUID_HYPERVISOR                    equ     5
CPUID_VENDOR_COUNT                  equ     29
CPUID_VENDOR_TABLE_SIZE             equ     CPUID_VENDOR_COUNT * 12

E820_signature                      equ     0x534D4150
E820_entry_size                     equ     24

null_descriptor                     equ     0x00
kernelcode_32bits_descriptor        equ     0x08
kernelcode_64bits_descriptor        equ     0x10
kerneldata_32bits_descriptor        equ     0x18

; ---------- just other stuff ----------
%include "src/boot/stage2/32bits/protected32.asm"  ; we seperate the 32bit code, look cleaner. It already a mess here.
times 8192-($-$$)   db      0
