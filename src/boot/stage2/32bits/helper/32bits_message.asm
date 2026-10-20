[bits 16]

; -------------------- variable space --------------------
align 16            ; does it even matter?
; When I was reading CSAPP I think I encounter something about alignment, like how we pad data in C's struct. Does it matter HERE tho?

; general
msg_welcome32       db      "Successfully enter 32bits protected mode.", 13, 10, 0

; boot time paging / long mode
msg_page_link       db      "   Page structure successfully linked", 13, 10, 0
msg_page_load       db      "   Page pointer loaded into memory!", 13, 10, 0
msg_page_buffer_clear       db      "   Page table buffer have been zerored!", 13, 10, 0
msg_long_mode_unavaliable   db      "   Unable to activate long mode due to incompatable CPU features for "
                            db      "   either paging or long mode support", 13, 10, 0
msg_requirement_not_met     db      "   Requirement not met. Can not jump to kernel. Halting processes...", 13, 10, 0
msg_framebuffer_addr_too_high   db  "   Framebuffer address it too high, cannot be mapped: Switching to default...", 13, 10, 0

msg_higher_half_success         db  "   High virtual address for kernel succesfull configure!", 13, 10, 0
msg_higher_half_failed          db  "   Failed to build page for higher virtual address, halting the CPU...", 13, 10, 0

; check message
msg_vbe_check_failed            db      "   VBE requirement check failed!", 13, 10, 0
msg_long_check_failed           db      "   Long mode requirement check failed!", 13, 10, 0
msg_framebuffer_check_failed    db      "   Framebuffer requirement check failed!", 13, 10, 0
msg_checksum_check_failed       db      "   Checksum requirement check failed! I do not know how is this even possible, but here you go I guess", 13, 10, 0
msg_higher_half_check_failed    db      "   Higher half requirement check failed! I do not know how is this even possible, but here you go I guess", 13, 10, 0
msg_reallocatable_check_failed  db      "   Reallocatable requirement check failed! I do not know how is this even possible, but here you go I guess", 13, 10, 0
msg_unknown_error_check_failed  db      "   Unknown Error requirement check failed!", 13, 10, 0

; stack computation
msg_valid_stack                 db      "   Valid stack address have been given: Stack address is approved :)", 13, 10, 0
msg_invalid_stack               db      "   Invalid stack address have been given: Address is in invalid range", 13, 10, 0
msg_stack_addr_below_1mb        db      "   Invalid stack address have been given: Address is below allow value", 13, 10, 0
msg_stack_no_valid              db      "   No valid stack address is found: Halting the CPU", 13, 10, 0
msg_stack_search                db      "   Attempting to search for valid stack address...", 13, 10, 0
msg_stack_addr_found            db      "   Found a valid stack top! Stack address is approved :)", 13, 10, 0


; attempt
msg_attempt_long_mode   db  "Attempting to load page table and activate long mode... ", 13, 10, 0

; debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging 
; debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging 
; debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging 

msg_test_wrap       db      "Testing screen wrapping mechanism right now we need to fill in"
                    db      " alot of stuff blah meow woof ahhh why? WHY NOT skibidi 67 BRAIN ROT GOT ME! HELP ;-;"
                    db      " hola cowboy es1p 205 512 2301 Achtung, Achtung, Achtung"
                    db      " lingan guu 67 verity No matter where you are, everyone is always connected", 13, 10, 0
msg_test_scroll     db      "11111111111111111111111111111111111111111111111111111111111111111111111111111111"
                    db      "22222222222222222222222222222222222222222222222222222222222222222222222222222222"
                    db      "33333333333333333333333333333333333333333333333333333333333333333333333333333333" 
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444", 13, 10, 0
msg_esc_seq_test    db      "\hey\\\a1sponsive?\\holycow\a2a\a4\b6haha", 13, 10, 0  ; escape sequence control bit must be turn on for this to work
msg_test            db      "hello", 0
msg_testabc         db      "abcdefhijklmnopqrstuvwxyz1234567890()*%?<>|", 13, 10, 0
msg_test_msg        db      "What sup man this is most likely some of the ugliest font you will seen ever!", 0

; debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging 
; debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging 
; debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging debugging 
