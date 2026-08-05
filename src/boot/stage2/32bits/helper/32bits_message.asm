[bits 16]

; -------------------- variable space --------------------
align 16            ; does it even matter?

; general
msg_welcome32       db      "Successfully enter 32bits protected mode.", 13, 10, 0

; paging

; attempt

; random 
msg_test_wrap       db      "Testing screen wrapping mechanism right now we need to fill in"
                    db      " alot of stuff blah blah balh blah blah skibidi 67 brain rotted"
                    db      " grr hola cowboy es1p 205 512 2301 actung, actung, actung"
                    db      " lingan guu lingan guu blah 91238123098", 13, 10, 0
msg_test_scroll     db      "11111111111111111111111111111111111111111111111111111111111111111111111111111111"
                    db      "22222222222222222222222222222222222222222222222222222222222222222222222222222222"
                    db      "33333333333333333333333333333333333333333333333333333333333333333333333333333333" 
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444", 13, 10, 0
msg_esc_seq_test    db      "\hey\\\a1sponsive?\\holycow\a2a\a4\b6haha", 13, 10, 0
msg_test            db      "hello", 0
msg_testabc         db      "abcdefhijklmnopqrstuvwxyz1234567890()*%?<>|", 13, 10, 0
msg_test_msg        db      "What sup man this is most likely some of the ugliest font you seen ever", 0

