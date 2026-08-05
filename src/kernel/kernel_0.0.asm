[bits 64]
; hey kenrel here?
kernel_header:
    .magic              dd      "QADB"
    .header_version     dd      0
    .header_size        dw      68

    .kernel_version     dw      0
    .kernel_name        dd      0
    .image_size         dd      0
    .check_sum          dd      0

    .load_address       dd      0
    .alignment          dd      0
    .entry32            dd      0           ; off set from image start
    .entry64            dd      0

    .required_cpu       dd      0
    .flags              dd      0x0
    ; flag: 0 vbe_graphic ; 1 paging ; 2 long mode ; 3 frame buffer require ; 4 check sum ; 
    ; flag: 5 higher half ; 6 identity map ; 7 flag strict
    .minimum_memory     dq      0
    .preferred_bpp      dd      32
    .preferred_width    dd      1024
    .preferred_height   dd      768

times 512-($-$$)    db      0
