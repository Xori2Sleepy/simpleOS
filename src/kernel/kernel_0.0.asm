[bits 64]

kernel_start:
kernel_header:
    .magic              dd      "QADB"
    .header_version     dd      0
    .header_size        dw      kernel_header_end - kernel_header

    .kernel_version     dw      0
    .kernel_name        dd      0
    .load_address       dq      0x100000
    .image_size         dq      kernel_end - kernel_start

    .check_sum          dd      0xce6e8eef

    .alignment          dd      0
    .entry32            dd      0           ; off set from image start
    .entry64            dd      kernel_enter_64
    .stack_size         dd      0
    .preferred_stack_top    dd      0

    .required_cpu       dd      0
    .flags              dd      001011b     ; backward btw
    ; flag: 0 vbe_graphic ; 1 long mode ; 2 frame buffer require ; 3 check sum ; 
    ; flag: 4 higher half ; 5 kernel reallocatable
    .minimum_memory     dq      0
    .preferred_bpp      dd      32
    .preferred_width    dd      1024
    .preferred_height   dd      768
kernel_header_end:
kernel_enter_64:

times   (512 - (($ - kernel_start) % 512)) % 512    db   0x67
kernel_end:
