[bits 64]
; hey kenrel here?
kernel_header:
    .magic              dd      "QADB"
    .version            dw      0
    .header_size        dw      0
    .image_size         dd      0
    .entry32            dd      0           ; off set from image start
    .entry64            dd      0
    .required_cpu       dd      0
    .flags              dd      0
    .preferred_width    dd      0
    .preferred_height   dd      0
    .preferred_bpp      dd      0

times 512-($-$$)    db      0
