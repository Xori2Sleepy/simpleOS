[bits 16]

; input: base, limit, access bytes, flags
%macro gdt_entries 4
    dw      %2 & 0xFFFF         ; limit is 20 bits we only need first 16 here
    dw      %1 & 0xFFFF         ; base is 32 bits but we only need first 16 here
    db      (%1 >> 16) & 0xFF   ; we only need 16-23 bits
    db      %3                  ; acess bytes
    db      ((%4 << 4) | ((%2 >> 16) & 0x0F)) ; first 4 bits is the 'other' flags, rest is limit
    db      (%1 >> 24) & 0xFF   ; only need the last 8 bits
%endmacro

; input: bpp, width, height
%macro resolution_entries 3
    db      %1
    dw      %2
    dw      %3
%endmacro

; -------------------- gdt space ------------------------

null_descriptor                     equ     0x00
kernelcode_32bits_descriptor        equ     0x08
kernelcode_64bits_descriptor        equ     0x10
kerneldata_32bits_descriptor        equ     0x18

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
    ; 0 -> cpu access, set to zero
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
    gdt_entries 0, 0xFFFFF, 10011010b, 1010b    ; 0x10 - 64 bits Kernel code segment descriptor
    gdt_entries 0, 0xFFFFF, 10010010b, 1100b    ; 0x18 - 32 bits Data segment descriptor
gdt_end:

gdt_descriptor:
    ; for lgdt, 6 byte, first 2 must be size and last 4 must be gdt address
    dw      gdt_end - gdt_start - 1         ; gdt size - 1
    dd      gdt_start

; --------------------  kernel info ------------------------
kernel_magic            equ     "QADB"

kernel_info:
    .magic              dd      0
    .header_version     dd      0           ; first 8 - other flag, next 8 - patch , next 8 minor ; last 8 major
    .header_size        dw      0

    .kernel_version     dw      0           ; kernel version
    .kernel_name        dd      0
    .load_address       dd      0
    .image_size         dd      0

    .check_sum          dd      0

    .alignment          dd      0
    .entry32            dd      0           ; off set from image start
    .entry64            dd      0
    .stack_size         dd      0
    .preferred_stack_top    dd      0

    .required_cpu       dd      0           ; cpuid id shit
    .flags              dd      0           ; boot service flags
    ; flag: 0 vbe_graphic ; 1 long mode ; 2 frame buffer require ; 3 check sum ; 
    ; flag: 4 higher half ; 5 kernel reallocatable

    .minimum_memory     dq      0
    .preferred_bpp      dd      0           ; order is important,
    .preferred_width    dd      0           ; the vbe logic read bpp width and height as a single chunck
    .preferred_height   dd      0

kernel_dap:                    
    .dap_size           db      0x10        ; size
    .reserve            db      0x00        ; reserve for int call
    .sector2read        dw      0x01        ; sector to read
    .destination        dw      scratchpad  ; we loading header to scratch space
    .segment            dw      0x0000      ; segment offset
    .sector_ad          dq      73

disk_trial_counter      db      4

; --------------------  boot info ------------------------
align 8
; if bit is on that mean something wrong, questionable design eh?
; edit: I CHANGED IT, NOW IF BIT OFF = we dint/couldnt activate or obtain it
boot_report             dq      0           ; flag and stuff
    ; 0 <- leaf1
    ; 1 <- leaf7
    ; 2 <- xleaf2to4
    ; 3 <- graphic                          ; used by terminal_interface to determind printing mode
    ; 4 <- e801
    ; 5 <- xleaf1

boot_info:
    .boot_info_size     dq      0           ; fill later
    .boot_drive         db      0
    .entry_count        dd      0           ; for memory map

    .reserved       times 3     db      0   ; for alignment

    ;vbe 4f00 subsection
    .vbe_version        dw      0
    .vbe_OEM_string     dd      0           ; useless, i just want it
    .vbe_capabilities   dd      0
    .vbe_video_mode_ptr dd      0
    .vbe_total_memory   dw      0

    ;vbe 4f01 subsection
    .vbe_selected_mode  dw      0

    .vbe_pitch          dw      0
    .vbe_width          dw      0
    .vbe_height         dw      0

    .vbe_bpp            db      0
    .vbe_memory_model   db      0

    .vbe_red_mask       db      0
    .vbe_red_shift      db      0
    .vbe_green_mask     db      0
    .vbe_green_shift    db      0
    .vbe_blue_mask      db      0
    .vbe_blue_shift     db      0

    .vbe_framebuffer    dd      0

    ;cpuid subsection
    .cpu_features1_ecx  dd      0
    .cpu_features1_edx  dd      0
    .cpu_features7_ebx  dd      0
    .cpu_features7_ecx  dd      0
    .cpu_features7_edx  dd      0
    .cpu_featuresx1_ecx dd      0
    .cpu_featuresx1_edx dd      0
    .cpu_featuresx8_eax dd      0
    .cpu_max_leaf       dd      0
    .cpu_max_x_leaf     dd      0
    .cpu_signature      dd      0
    .vendor_category    db      0       ; category base on bootloader own sorting definition,
                                        ; used for vendor specific call

    .vendor_name    times 3     dd      0
    .brand_string   times 48    db      0

    ;align 8
    ;.memory_map     times 64 * 24       db      0   ; 1536 byte
    .memory_map     equ     0x4000
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

; -------------------- VBE Priority table --------------------
vbe_resolution_priority_table:
    .entries_count      db          6
    resolution_entries  0, 0, 0            ; place holder that will be populate by kernel header code
    resolution_entries  32, 1920, 1080
    resolution_entries  32, 1600, 900
    resolution_entries  32, 1280, 720
    resolution_entries  32, 1024, 768
    resolution_entries  32, 800, 600

selected_priority_rank  dw      0
selected_mode           dw      0 

; -------------------- Color information table --------------------
unify_color:
    dd      0x00000000    ; 0  Black
    dd      0x000000AA    ; 1  Blue
    dd      0x0000AA00    ; 2  Green
    dd      0x0000AAAA    ; 3  Cyan
    dd      0x00AA0000    ; 4  Red
    dd      0x00AA00AA    ; 5  Magenta
    dd      0x00AA5500    ; 6  Brown
    dd      0x00AAAAAA    ; 7  Light Gray
    dd      0x00555555    ; 8  Dark Gray
    dd      0x005555FF    ; 9  Light Blue
    dd      0x0055FF55    ; A  Light Green
    dd      0x0055FFFF    ; B  Light Cyan
    dd      0x00FF5555    ; C  Light Red
    dd      0x00FF55FF    ; D  Light Magenta
    dd      0x00FFFF55    ; E  Yellow
    dd      0x00FFFFFF    ; F  White
