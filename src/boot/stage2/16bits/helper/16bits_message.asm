[bits 16]

; -------------------- variable space --------------------
align 16            ; does it even matter?
; general
msg_stage2_entry    db      "Second stage active: Executing Instruction ", 13, 10, 0
msg_cpu_halted      db      "CRITICAL: CPU halted! Please reboot the PC", 13, 10, 0
msg_far_jump        db      "Preparation complete: Enabling CR0 and attempting a far jump to 32 bits protected mode; Brace for impact and good luck 32 bits code! :)", 13, 10, 0
msg_gdt             db      "Global Description Table structure defined, loading it to register...", 13, 10, 0

msg_debug1          db      "db1", 13, 10, 0
msg_debug2          db      "db2", 13, 10, 0
msg_debug3          db      "db3", 13, 10, 0
msg_debug4          db      "DEBUGGING4: ", 0
msg_test_print      dw      0xAB12

; e820 & e801
msg_e820_success    db      "E820 memory mapping success!", 13, 10, 0
msg_e820_failed     db      "E820 memory mapping failed; Attempting fallback method"
msg_e801_success    db      "E801 memory mapping success: Note that RAM will be limit to 16 Mb", 13, 10, 0
msg_e801_failed     db      "E801 memroy mapping failed: Memory cannot be map; Halting CPU...", 13, 10, 0
msg_map_sort_success        db      "   E820 memory map sort complete", 13, 10, 0
msg_map_sort_e801           db      "   Memory map is done by e801, sorting can not be done", 13, 10, 0
msg_map_merge_success       db      "   E820 memory map merged!", 13, 10, 0

; a20
msg_a20_success     db      "A20 successfully initialize!", 13, 10, 0
msg_a20_failed      db      "CRITICAL: Attempted all reliable method. If you see this message, the only way to continue "
                    db      "is to dig up the bootloader code and manually uncomment other method. Good Luck!", 13, 10, 0
                    db      "CRITICAL: A20 can not be enable; system can not be safely load: Halting CPU...", 13, 10, 0
msg_bios_a20_failed db      "BIOS A20 initialization failed. Error code: ", 13, 10, 0
msg_bios_a20_cont   db      "Attempt other known method for A20 initiation...", 13, 10, 0
msg_kb_ctrl_failed  db      "Keyboard controller A20 initiation failed. Attmepting other known method...", 13, 10, 0
msg_ff_failed       db      "System Control Port A A20 initiation failed!", 13, 10

; vbe
; now that I think about why am I even printing vbe messages? no one gonna see these stuff if vbe is turn on...
msg_vbe_info_loaded db      "   Boot info is now populate with nessary information to start graphic", 13, 10, 0
msg_vbe_info_failed db      "   Graphical information can not be obtain! Falling back to VGA", 13, 10, 0
msg_unsupport_vbe   db      "   VBE is avaliable but the version is unsupported", 13, 10, 0
msg_populate_4f00   db      "   successfully populate boot info structure with VBE information", 13, 10, 0
msg_vbe_4f00_failed db      "   CRITICAL: Either function 4F00h interupt 0x10 does not exist, or it return garbage value", 13, 10, 0
msg_vbe_4f00_detected   db  "   VBE information loaded into buffer. Attempting to parse information: ", 0
msg_vbe_4f01_mode_found db  "   Valid resolution mode number found! Extracting information...", 13, 10, 0
msg_vbe_4f01_mode_not_found     db      "   No valid resolution mode was found!", 13, 10, 0

; kernel & disk
msg_rs_success      db      "   Disk reset success!", 13, 10, 0
msg_rs_failed       db      "   CRITICAL: Disk reset failed", 13, 10, 0
msg_disk_success    db      "   Disk read success", 13, 10, 0
msg_disk_failed     db      "   Disk read error! Error code: ", 0
msg_valid_memory    db      "   Valid memory found: loading full kernel...", 13, 10, 0
msg_header_load_success db  "   Kernel header succesfully loaded", 13, 10, 0
msg_header_load_failed  db  "   Kernel header fail to load. Continuing with execution...", 13, 10, 0
msg_kernel_load_success     db      "   Kernel fully loaded!", 13, 10, 0
msg_kernel_load_err_no_mem  db      "   CRITICAL: Can not identify a valid memory zone for kenel image! Halting the CPU!", 13, 10, 0
msg_kernel_load_err_addr_below db   "   CRITICAL: Kernel load address in header is invalid! Halting the CPU!"
msg_kernel_load_err_above_lim  db   "   CRITICAL: Valid load address found but it exist above 32 bits limit, "
                               db   "please check kerenl_reallocatiable flag! Halting the CPU!", 13, 10, 0
msg_kernel_load_err_invalid_addr    db   "   CRITICAL: Given address is invalid!", 13, 10, 0

; kernel read n stuff
msg_unrecognized_magic  db  "   Unrecognized magic: kernel header could not be parsed", 13, 10, 0
msg_recognized_magic    db  "   Recognized magic: kernel header successfully parsed", 13, 10, 0

; attempt
msg_attempt_a20     db      "Attempting to enable A20: ", 0
msg_attempt_e820    db      "Attempting to build memory map: ", 0
msg_attempt_cpuid   db      "Attempting to fetch data from CPUID: ", 13, 10, 0
msg_attempt_vbe     db      "Attempting to acticate VBE graphic: ", 13, 10, 0
msg_attempt_header_load     db      "Attempting to load kernel header: ", 13, 10, 0
msg_attempt_header_read     db      "Attempting to read kernel header: ", 13, 10, 0
msg_attempt_sanitation      db      "Attempting to sanitize memory map: ", 13, 10, 0
msg_attempt_sector_load     db      "Attempting to load full kernel image: ", 13, 10, 0

; cpuid stuff
msg_cpuid_unavailable       db      "   CPUID: CPUID feature is unavailable, can not obtain nessary information: Halting CPU.", 13, 10, 0
msg_cpuid_unknown_vendor    db      "   CPUID: Attempt to detect CPU architecture return unknown vendor!", 13, 10, 0
msg_cpuid_leaf1_failed      db      "   CPUID: Leaf 1 unavailable: Unable to detect CPU Signature and Base Feature Flags!", 13, 10, 0
msg_cpuid_leaf1_success     db      "   CPUID: CPU Signature and Base Feature Flags detection success!", 13, 10, 0
msg_cpuid_leaf7_failed      db      "   CPUID: Leaf 7 unavailable: Unable to detect extended feature flags!", 13, 10, 0
msg_cpuid_leaf7_success     db      "   CPUID: Extended Feature Flags detection success!", 13, 10, 0
msg_cpuid_xleaf2to4_failed  db      "   CPUID: Failed to fetch CPU Brand Label", 13, 10, 0
msg_cpuid_xleaf2to4_success db      "   CPUID: Successfully fetch CPU Brand Label", 13, 10, 0      
msg_cpuid_xleaf1_success    db      "   CPUID: Extended leaf 1 successfully retrieved", 13, 10, 0
msg_cpuid_xleaf1_failed     db      "   CPUID: Extended leaf 1 unavaliable", 13, 10, 0
msg_cpuid_xleaf8_success    db      "   CPUID: Extended leaf 8 successfully retrieved", 13, 10, 0
msg_cpuid_xleaf8_failed     db      "   CPUID: Extended leaf 8 unavaliable", 13, 10, 0
