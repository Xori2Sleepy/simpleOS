[bits 64]
; hey kenrel here?
kernel_header:
    .magic              dd      "QADB"
    .version            dw      0
    .header_size        dw      48
    .image_size         dd      0
    .entry32            dd      0           ; off set from image start
    .entry64            dd      0
    .required_cpu       dd      0
    .flags              dd      0
    .minimum_memory     dq      0
    .preferred_bpp      dd      32
    .preferred_width    dd      1024
    .preferred_height   dd      768

times 512-($-$$)    db      0
