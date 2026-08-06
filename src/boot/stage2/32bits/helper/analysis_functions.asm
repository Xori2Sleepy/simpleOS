[bits 32]

kernel_analyze_long_mode_32:
    push    eax
    mov     eax, [kernel_info.header_version] ; version 
    shr     eax, 24     ; checking major version
    test    eax, eax    ; unreleased major 0
    je      .major0
    ret
.major0:
    mov     eax, [kernel_info.flags]
    and     eax, 1 << 1 ; isolate bits 1 : long_mode
    test    eax, eax
    je      .m0_gOFF
.m0_gON:
    pop     eax
    stc
    ret
.m0_gOFF:
    pop     eax
    clc
    ret

; leaf analysis shit

leaf_analysis_long_mode_32:
    push    eax
    mov     eax, [boot_info.cpu_featuresx1_edx]
    and     eax, 1 << 29
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret

leaf_analysis_pae_32:
    push    eax
    mov     eax, [boot_info.cpu_features1_edx]
    and     eax, 1 << 6
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret

leaf_analysis_msr_32:
    push    eax
    mov     eax, [boot_info.cpu_features1_edx]
    and     eax, 1 << 5
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret

leaf_analysis_nx_32:
    push    eax
    mov     eax, [boot_info.cpu_featuresx1_edx]
    and     eax, 1 << 20
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret

leaf_analysis_1g_page_32:
    push    eax
    mov     eax, [boot_info.cpu_featuresx1_edx]
    and     eax, 1 << 26
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret

leaf_analysis_pat_32:
    push    eax
    mov     eax, [boot_info.cpu_features1_edx]
    and     eax, 1 << 16
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret
