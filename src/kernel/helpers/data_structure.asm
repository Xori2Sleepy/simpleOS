[bits 64]

boot_info:
    .boot_info_size     dq      0
    .boot_drive         db      0
    .read_mode          db      0           ; 0 for chs and 1 for lba
    .entry_count        dd      0           ; for memory map

    .reserved       times 3     db      0   ; for alignment

    ;vbe 4f00 subsection
    .vbe_version        dw      0
    .vbe_OEM_string     dd      0           ; useless, i just want it
    .vbe_capabilities   dd      0
    .vbe_video_mode_ptr dd      0           ; pointer to mode, used for looping and finding mode
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

    .vbe_framebuffer    dd      0           ; actual framebuffer address

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
    .vendor_category    db      0       ; category base on bootloader own sorting definition, kinda useless idk why I put it here

    .vendor_name    times 3     dd      0
    .brand_string   times 48    db      0

    .memory_map     equ     0x4000
    .effective_load_address     dq      0
    .effective_loaded_bytes     dq      0

    .actual_stack_addr  dd      0
    .actual_stack_size  dd      0

kernel_memory_map:
 ;   times       db      [boot_info.entry_count] * 24    ; kernel need to copy the memory map over
