; =============================================================================
; SEGA MASTER SYSTEM INPUT MODULE
; =============================================================================

; =============================================================================
; Read Joypad
; Joypad bits are active LOW
; Bit 0: Up
; Bit 1: Down
; Bit 2: Left
; Bit 3: Right
; Bit 4: Button 1 (TL)
; Bit 5: Button 2 (TR)
; =============================================================================
read_joypad:
        ; Save old state
        ld      a, (joypad)
        ld      (joypad_old), a

        ; Read controller 1
        in      a, (IO_CTRL1)

        ; Invert (buttons are active low)
        cpl
        and     $3F             ; Mask to 6 bits
        ld      (joypad), a

        ; Calculate newly pressed buttons
        ld      b, a
        ld      a, (joypad_old)
        cpl
        and     b
        ld      (joypad_new), a
        ret
