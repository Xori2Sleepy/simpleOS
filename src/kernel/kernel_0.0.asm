[bits 64]
; hey kenrel here?
kernel_header:
    .magic              dd      "QADB"
    .header_version     dd      0
    .header_size        dw      84

    .kernel_version     dw      0
    .kernel_name        dd      0
    .load_address       dq      0x100000
    .image_size         dq      512

    .check_sum          dd      0

    .alignment          dd      0
    .entry32            dd      0           ; off set from image start
    .entry64            dd      0
    .stack_size         dd      0
    .preferred_stack_top    dd      0

    .required_cpu       dd      0
    .flags              dd      10b
    ; flag: 0 vbe_graphic ; 1 long mode ; 2 frame buffer require ; 3 check sum ; 
    ; flag: 4 higher half ; 5 kernel reallocatable
    .minimum_memory     dq      0
    .preferred_bpp      dd      32
    .preferred_width    dd      1024
    .preferred_height   dd      768

times 512-($-$$)    db      0
