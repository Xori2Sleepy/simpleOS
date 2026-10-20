[bits 16]

; -------------------- header analysis -------------------- 
kernel_analyze_graphic:
    ; input: NA
    ; output: carry (on = request graphic, off = no request for graphic)
    ; clobbered: eflags ; eax
    mov     eax, [kernel_info.header_version] ; version 
    shr     eax, 24     ; checking major version
    test    eax, eax    ; unreleased major 0
    je      .major0
    ret 
.major0:
    mov     eax, [kernel_info.flags]
    and     eax, 1      ; isolate bits 0 : graphic
    test    eax, eax
    je      .m0_gOFF
.m0_gON:
    stc
    ret
.m0_gOFF:
    clc
    ret

kernel_analyze_long_mode:
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
    stc
    ret
.m0_gOFF:
    clc
    ret

kernel_analyze_frame_buffer:
    mov     eax, [kernel_info.header_version] ; version 
    shr     eax, 24     ; checking major version
    test    eax, eax    ; unreleased major 0
    je      .major0
    ret
.major0:
    mov     eax, [kernel_info.flags]
    and     eax, 1 << 2 ; isolate bits 2 
    test    eax, eax
    je      .m0_gOFF
.m0_gON:
    stc
    ret
.m0_gOFF:
    clc
    ret

kernel_analyze_check_sum:
    mov     eax, [kernel_info.header_version] ; version 
    shr     eax, 24     ; checking major version
    test    eax, eax    ; unreleased major 0
    je      .major0
    ret
.major0:
    mov     eax, [kernel_info.flags]
    and     eax, 1 << 3 ; isolate bits 3
    test    eax, eax
    je      .m0_gOFF
.m0_gON:
    stc
    ret
.m0_gOFF:
    clc
    ret

kernel_analyze_higher_half:
    mov     eax, [kernel_info.header_version] ; version 
    shr     eax, 24     ; checking major version
    test    eax, eax    ; unreleased major 0
    je      .major0
    ret
.major0:
    mov     eax, [kernel_info.flags]
    and     eax, 1 << 4 ; isolate bits 4
    test    eax, eax
    je      .m0_gOFF
.m0_gON:
    stc
    ret
.m0_gOFF:
    clc
    ret

kernel_analyze_kernel_reallocatable:
    mov     eax, [kernel_info.header_version] ; version 
    shr     eax, 24     ; checking major version
    test    eax, eax    ; unreleased major 0
    je      .major0
    ret
.major0:
    mov     eax, [kernel_info.flags]
    and     eax, 1 << 5 ; isolate bits 5
    test    eax, eax
    je      .m0_gOFF
.m0_gON:
    stc
    ret
.m0_gOFF:
    clc
    ret

; ----------------- CPUID ANALYSIS -----------------
leaf_analysis_long_mode:
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

leaf_analysis_pae:
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

leaf_analysis_msr:
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

leaf_analysis_nx:
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

leaf_analysis_1g_page:
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

leaf_analysis_pat:
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

; COMPLETELY INRELEVANT HELPER FUNCTION (for now) THAT JUST HERE, maybe for the futrue but I doubt it
leaf_analysis_apic:
    push    eax
    mov     eax, [boot_info.cpu_features1_edx]
    and     eax, 1 << 9
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret

leaf_analysis_x2apic:
    push    eax
    mov     eax, [boot_info.cpu_features1_edx]
    and     eax, 1 << 21
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret

leaf_analysis_tsc:
    push    eax
    mov     eax, [boot_info.cpu_features1_edx]
    and     eax, 1 << 4
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret

leaf_analysis_invariant_tsc:
    push    eax
    mov     eax, [boot_info.cpu_featuresx1_edx]
    and     eax, 1 << 8
    test    eax, eax
    jz      .not_active
    pop     eax
    clc
    ret
.not_active:
    pop     eax
    stc
    ret
