; ==============================================================================
; ASCII LOOKUP TABLE (0 to 127)
; Each entry is 4 bytes (a 32-bit pointer) pointing directly to the font glyph data.
; ==============================================================================
align 4
ASCII_lookup_table:
    ; --- ASCII 0 to 31 (Control Characters / Unused) ---
    times   32      dd      font_question          ; Fallback to '?' or blank placeholder

    ; --- ASCII 32 (Space) ---
    dd      font_space

    ; --- ASCII 33 to 47 (Punctuation and Symbols) ---
    dd      font_exclamation                ; 33  (!)
    dd      font_question                   ; 34  (")
    dd      font_question                   ; 35  (#)
    dd      font_question                   ; 36  ($)
    dd      font_question                   ; 37  (%)
    dd      font_question                   ; 38  (&)
    dd      font_question                   ; 39  (')
    dd      font_lparen                     ; 40  (()
    dd      font_rparen                     ; 41  ())
    dd      font_asterisk                   ; 42  (*)
    dd      font_plus                       ; 43  (+)
    dd      font_comma                      ; 44  (,)
    dd      font_hyphen                     ; 45  (-)
    dd      font_period                     ; 46  (.)
    dd      font_slash                      ; 47  (/)

    ; --- ASCII 48 to 57 (Numbers 0 to 9) ---
    dd      font_0                          ; 48  (0)
    dd      font_1                          ; 49  (1)
    dd      font_2                          ; 50  (2)
    dd      font_3                          ; 51  (3)
    dd      font_4                          ; 52  (4)
    dd      font_5                          ; 53  (5)
    dd      font_6                          ; 54  (6)
    dd      font_7                          ; 55  (7)
    dd      font_8                          ; 56  (8)
    dd      font_9                          ; 57  (9)

    ; --- ASCII 58 to 64 (More Punctuation) ---
    dd      font_colon                      ; 58  (:)
    dd      font_semicolon                  ; 59  (;)
    dd      font_question                   ; 60  (<)
    dd      font_equals                     ; 61  (=)
    dd      font_question                   ; 62  (>)
    dd      font_question                   ; 63  (?) -> Handled by font_question explicitly
    dd      font_question                   ; 64  (@)

    ; --- ASCII 65 to 90 (Uppercase Letters A to Z) ---
    dd      font_A                          ; 65  (A)
    dd      font_B                          ; 66  (B)
    dd      font_C                          ; 67  (C)
    dd      font_D                          ; 68  (D)
    dd      font_E                          ; 69  (E)
    dd      font_F                          ; 70  (F)
    dd      font_G                          ; 71  (G)
    dd      font_H                          ; 72  (H)
    dd      font_I                          ; 73  (I)
    dd      font_J                          ; 74  (J)
    dd      font_K                          ; 75  (K)
    dd      font_L                          ; 76  (L)
    dd      font_M                          ; 77  (M)
    dd      font_N                          ; 78  (N)
    dd      font_O                          ; 79  (O)
    dd      font_P                          ; 80  (P)
    dd      font_Q                          ; 81  (Q)
    dd      font_R                          ; 82  (R)
    dd      font_S                          ; 83  (S)
    dd      font_T                          ; 84  (T)
    dd      font_U                          ; 85  (U)
    dd      font_V                          ; 86  (V)
    dd      font_W                          ; 87  (W)
    dd      font_X                          ; 88  (X)
    dd      font_Y                          ; 89  (Y)
    dd      font_Z                          ; 90  (Z)

    ; --- ASCII 91 to 96 (Brackets and Symbols) ---
    dd      font_question                   ; 91  ([)
    dd      font_question                   ; 92  (\)
    dd      font_question                   ; 93  (])
    dd      font_question                   ; 94  (^)
    dd      font_underscore                 ; 95  (_)
    dd      font_question                   ; 96  (`)

    ; --- ASCII 97 to 122 (Lowercase Letters a to z) ---
    dd      font_a_lower                    ; 97  (a)
    dd      font_b_lower                    ; 98  (b)
    dd      font_c_lower                    ; 99  (c)
    dd      font_d_lower                    ; 100 (d)
    dd      font_e_lower                    ; 101 (e)
    dd      font_f_lower                    ; 102 (f)
    dd      font_g_lower                    ; 103 (g)
    dd      font_h_lower                    ; 104 (h)
    dd      font_i_lower                    ; 105 (i)
    dd      font_j_lower                    ; 106 (j)
    dd      font_k_lower                    ; 107 (k)
    dd      font_l_lower                    ; 108 (l)
    dd      font_m_lower                    ; 109 (m)
    dd      font_n_lower                    ; 110 (n)
    dd      font_o_lower                    ; 111 (o)
    dd      font_p_lower                    ; 112 (p)
    dd      font_q_lower                    ; 113 (q)
    dd      font_r_lower                    ; 114 (r)
    dd      font_s_lower                    ; 115 (s)
    dd      font_t_lower                    ; 116 (t)
    dd      font_u_lower                    ; 117 (u)
    dd      font_v_lower                    ; 118 (v)
    dd      font_w_lower                    ; 119 (w)
    dd      font_x_lower                    ; 120 (x)
    dd      font_y_lower                    ; 121 (y)
    dd      font_z_lower                    ; 122 (z)

    ; --- ASCII 123 to 127 (Remaining Symbols) ---
    dd      font_question                   ; 123 ({)
    dd      font_question                   ; 124 (|)
    dd      font_question                   ; 125 (})
    dd      font_question                   ; 126 (~)
    dd      font_question                   ; 127 (DEL)

font_A:
    db      00011000b
    db      00100100b
    db      01000010b
    db      01000010b
    db      01111110b
    db      10000001b
    db      10000001b
    db      00000000b

font_B:
    db      11111100b
    db      10000010b
    db      10000010b
    db      11111100b
    db      10000010b
    db      10000010b
    db      11111100b
    db      00000000b

font_C:
    db      00111100b
    db      01000010b
    db      10000000b
    db      10000000b
    db      10000000b
    db      01000010b
    db      00111100b
    db      00000000b

font_D:
    db      11111000b
    db      10000100b
    db      10000010b
    db      10000010b
    db      10000010b
    db      10000100b
    db      11111000b
    db      00000000b

font_E:
    db      11111110b
    db      10000000b
    db      10000000b
    db      11111100b
    db      10000000b
    db      10000000b
    db      11111110b
    db      00000000b

font_F:
    db      11111110b
    db      10000000b
    db      10000000b
    db      11111100b
    db      10000000b
    db      10000000b
    db      10000000b
    db      00000000b

font_G:
    db      00111100b
    db      01000010b
    db      10000000b
    db      10001110b
    db      10000010b
    db      01000010b
    db      00111100b
    db      00000000b

font_H:
    db      10000001b
    db      10000001b
    db      10000001b
    db      11111111b
    db      10000001b
    db      10000001b
    db      10000001b
    db      00000000b

font_I:
    db      00111100b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00111100b
    db      00000000b

font_J:
    db      00011111b
    db      00000100b
    db      00000100b
    db      00000100b
    db      10000100b
    db      10000100b
    db      01111000b
    db      00000000b

font_K:
    db      10000100b
    db      10001000b
    db      10010000b
    db      11100000b
    db      10010000b
    db      10001000b
    db      10000100b
    db      00000000b

font_L:
    db      10000000b
    db      10000000b
    db      10000000b
    db      10000000b
    db      10000000b
    db      10000000b
    db      11111111b
    db      00000000b

font_M:
    db      10000001b
    db      11000011b
    db      10100101b
    db      10011001b
    db      10000001b
    db      10000001b
    db      10000001b
    db      00000000b

font_N:
    db      10000001b
    db      11000001b
    db      10100001b
    db      10010001b
    db      10001001b
    db      10000101b
    db      10000011b
    db      00000000b

font_O:
    db      00111100b
    db      01000010b
    db      10000001b
    db      10000001b
    db      10000001b
    db      01000010b
    db      00111100b
    db      00000000b

font_P:
    db      11111100b
    db      10000010b
    db      10000010b
    db      11111100b
    db      10000000b
    db      10000000b
    db      10000000b
    db      00000000b

font_Q:
    db      00111100b
    db      01000010b
    db      10000001b
    db      10000001b
    db      10000101b
    db      01000010b
    db      00111101b
    db      00000000b

font_R:
    db      11111100b
    db      10000010b
    db      10000010b
    db      11111100b
    db      10010000b
    db      10001000b
    db      10000100b
    db      00000000b

font_S:
    db      00111110b
    db      01000001b
    db      10000000b
    db      01111100b
    db      00000010b
    db      10000001b
    db      01111110b
    db      00000000b

font_T:
    db      11111111b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00000000b

font_U:
    db      10000001b
    db      10000001b
    db      10000001b
    db      10000001b
    db      10000001b
    db      01000010b
    db      00111100b
    db      00000000b

font_V:
    db      10000001b
    db      10000001b
    db      01000010b
    db      01000010b
    db      00100100b
    db      00100100b
    db      00011000b
    db      00000000b

font_W:
    db      10000001b
    db      10000001b
    db      10000001b
    db      10011001b
    db      10100101b
    db      11000011b
    db      10000001b
    db      00000000b

font_X:
    db      10000001b
    db      01000010b
    db      00100100b
    db      00011000b
    db      00100100b
    db      01000010b
    db      10000001b
    db      00000000b

font_Y:
    db      10000001b
    db      01000010b
    db      00100100b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00000000b

font_Z:
    db      11111111b
    db      00000010b
    db      00000100b
    db      00001000b
    db      00010000b
    db      00100000b
    db      11111111b
    db      00000000b

font_a_lower:
    db      00000000b
    db      00000000b
    db      01111100b
    db      00000010b
    db      01111110b
    db      10000010b
    db      01111110b
    db      00000000b

font_b_lower:
    db      10000000b
    db      10000000b
    db      11111100b
    db      10000010b
    db      10000010b
    db      10000010b
    db      11111100b
    db      00000000b

font_c_lower:
    db      00000000b
    db      00000000b
    db      01111100b
    db      10000000b
    db      10000000b
    db      10000000b
    db      01111100b
    db      00000000b

font_d_lower:
    db      00000010b
    db      00000010b
    db      01111110b
    db      10000010b
    db      10000010b
    db      10000010b
    db      01111110b
    db      00000000b

font_e_lower:
    db      00000000b
    db      00000000b
    db      01111100b
    db      10000010b
    db      11111110b
    db      10000000b
    db      01111100b
    db      00000000b

font_f_lower:
    db      00111100b
    db      01000000b
    db      11111100b
    db      01000000b
    db      01000000b
    db      01000000b
    db      01000000b
    db      00000000b

font_g_lower:
    db      00000000b
    db      01111110b
    db      10000010b
    db      10000010b
    db      01111110b
    db      00000010b
    db      11111100b
    db      00000000b

font_h_lower:
    db      10000000b
    db      10000000b
    db      11111100b
    db      10000010b
    db      10000010b
    db      10000010b
    db      10000010b
    db      00000000b

font_i_lower:
    db      00011000b
    db      00000000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00000000b

font_j_lower:
    db      00001100b
    db      00000000b
    db      00001100b
    db      00001100b
    db      00001100b
    db      10001100b
    db      01110000b
    db      00000000b

font_k_lower:
    db      10000000b
    db      10000000b
    db      10010000b
    db      10100000b
    db      11000000b
    db      10100000b
    db      10010000b
    db      00000000b

font_l_lower:
    db      00111000b
    db      00010000b
    db      00010000b
    db      00010000b
    db      00010000b
    db      00010000b
    db      01111110b
    db      00000000b

font_m_lower:
    db      00000000b
    db      00000000b
    db      11010110b
    db      10101001b
    db      10101001b
    db      10101001b
    db      10101001b
    db      00000000b

font_n_lower:
    db      00000000b
    db      00000000b
    db      11111100b
    db      10000010b
    db      10000010b
    db      10000010b
    db      10000010b
    db      00000000b

font_o_lower:
    db      00000000b
    db      00000000b
    db      01111100b
    db      10000010b
    db      10000010b
    db      10000010b
    db      01111100b
    db      00000000b

font_p_lower:
    db      00000000b
    db      11111100b
    db      10000010b
    db      10000010b
    db      11111100b
    db      10000000b
    db      10000000b
    db      00000000b

font_q_lower:
    db      00000000b
    db      01111110b
    db      10000010b
    db      10000010b
    db      01111110b
    db      00000010b
    db      00000010b
    db      00000000b

font_r_lower:
    db      00000000b
    db      00000000b
    db      11011000b
    db      10100100b
    db      10000000b
    db      10000000b
    db      10000000b
    db      00000000b

font_s_lower:
    db      00000000b
    db      00000000b
    db      01111100b
    db      10000000b
    db      01111100b
    db      00000010b
    db      11111100b
    db      00000000b

font_t_lower:
    db      00000000b
    db      01000000b
    db      11111100b
    db      01000000b
    db      01000000b
    db      01000010b
    db      00111100b
    db      00000000b

font_u_lower:
    db      00000000b
    db      00000000b
    db      10000010b
    db      10000010b
    db      10000010b
    db      10000010b
    db      01111110b
    db      00000000b

font_v_lower:
    db      00000000b
    db      00000000b
    db      10000010b
    db      10000010b
    db      01000100b
    db      01000100b
    db      00101000b
    db      00000000b

font_w_lower:
    db      00000000b
    db      00000000b
    db      10000001b
    db      10000001b
    db      10010101b
    db      10101010b
    db      01000100b
    db      00000000b

font_x_lower:
    db      00000000b
    db      00000000b
    db      10000001b
    db      01000010b
    db      00100100b
    db      01000010b
    db      10000001b
    db      00000000b

font_y_lower:
    db      00000000b
    db      10000010b
    db      10000010b
    db      01000100b
    db      00101000b
    db      00010000b
    db      00100000b
    db      00000000b

font_z_lower:
    db      00000000b
    db      00000000b
    db      11111111b
    db      00001000b
    db      00010000b
    db      00100000b
    db      11111111b
    db      00000000b

font_0:
    db      00111100b
    db      01000010b
    db      10010001b
    db      10101001b
    db      11000101b
    db      01000010b
    db      00111100b
    db      00000000b

font_1:
    db      00011000b
    db      00111000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      01111110b
    db      00000000b

font_2:
    db      00111100b
    db      01000010b
    db      00000100b
    db      00001000b
    db      00010000b
    db      00100000b
    db      01111111b
    db      00000000b

font_3:
    db      00111100b
    db      01000010b
    db      00000100b
    db      00011100b
    db      00000010b
    db      01000010b
    db      00111100b
    db      00000000b

font_4:
    db      00001000b
    db      00011000b
    db      00101000b
    db      01001000b
    db      11111111b
    db      00001000b
    db      00001000b
    db      00000000b

font_5:
    db      01111110b
    db      01000000b
    db      01111100b
    db      00000010b
    db      00000010b
    db      01000010b
    db      00111100b
    db      00000000b

font_6:
    db      00111100b
    db      01000000b
    db      01111100b
    db      10000010b
    db      10000010b
    db      01000010b
    db      00111100b
    db      00000000b

font_7:
    db      11111111b
    db      00000010b
    db      00000100b
    db      00001000b
    db      00010000b
    db      00100000b
    db      00100000b
    db      00000000b

font_8:
    db      00111100b
    db      01000010b
    db      01000010b
    db      00111100b
    db      01000010b
    db      01000010b
    db      00111100b
    db      00000000b

font_9:
    db      00111100b
    db      01000010b
    db      10000010b
    db      01111110b
    db      00000010b
    db      01000010b
    db      00111100b
    db      00000000b

font_period:               ; .
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00011000b
    db      00011000b
    db      00000000b

font_comma:                ; ,
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00011000b
    db      00011000b
    db      00001000b
    db      00010000b

font_hyphen:               ; -
    db      00000000b
    db      00000000b
    db      00000000b
    db      01111110b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b

font_plus:                 ; +
    db      00000000b
    db      00011000b
    db      00011000b
    db      11111111b
    db      00011000b
    db      00011000b
    db      00000000b
    db      00000000b

font_equals:               ; =
    db      00000000b
    db      00000000b
    db      01111110b
    db      00000000b
    db      01111110b
    db      00000000b
    db      00000000b
    db      00000000b

font_exclamation:          ; !
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00011000b
    db      00000000b
    db      00011000b
    db      00000000b

font_question:             ; ?
    db      00111100b
    db      01000010b
    db      00000100b
    db      00001000b
    db      00010000b
    db      00000000b
    db      00010000b
    db      00000000b

font_colon:                ; :
    db      00000000b
    db      00011000b
    db      00011000b
    db      00000000b
    db      00011000b
    db      00011000b
    db      00000000b
    db      00000000b

font_semicolon:            ; ;
    db      00000000b
    db      00011000b
    db      00011000b
    db      00000000b
    db      00011000b
    db      00011000b
    db      00001000b
    db      00010000b

font_underscore:           ; _
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      11111111b
    db      00000000b

font_slash:                ; /
    db      00000001b
    db      00000010b
    db      00000100b
    db      00001000b
    db      00010000b
    db      00100000b
    db      01000000b
    db      00000000b

font_asterisk:             ; *
    db      00000000b
    db      10000001b
    db      01011010b
    db      00111100b
    db      01011010b
    db      10000001b
    db      00000000b
    db      00000000b

font_lparen:               ; (
    db      00001100b
    db      00010000b
    db      00100000b
    db      00100000b
    db      00100000b
    db      00010000b
    db      00001100b
    db      00000000b

font_rparen:               ; )
    db      00110000b
    db      00001000b
    db      00000100b
    db      00000100b
    db      00000100b
    db      00001000b
    db      00110000b
    db      00000000b

font_space:                ; ' ' 
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
    db      00000000b
